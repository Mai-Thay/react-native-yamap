package ru.vvdev.yamap.view;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.view.View;
import android.util.AttributeSet;

import androidx.annotation.NonNull;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeArray;
import com.facebook.react.uimanager.events.RCTEventEmitter;
import com.yandex.mapkit.Animation;
import com.yandex.mapkit.MapKitFactory;
import com.yandex.mapkit.RequestPoint;
import com.yandex.mapkit.RequestPointType;
import com.yandex.mapkit.geometry.BoundingBox;
import com.yandex.mapkit.geometry.Point;
import com.yandex.mapkit.layers.ObjectEvent;
import com.yandex.mapkit.map.CameraListener;
import com.yandex.mapkit.map.CameraPosition;
import com.yandex.mapkit.map.CameraUpdateReason;
import com.yandex.mapkit.map.CircleMapObject;
import com.yandex.mapkit.map.InputListener;
import com.yandex.mapkit.map.PlacemarkMapObject;
import com.yandex.mapkit.map.PolygonMapObject;
import com.yandex.mapkit.map.PolylineMapObject;
import com.yandex.mapkit.mapview.MapView;
import com.yandex.mapkit.user_location.UserLocationLayer;
import com.yandex.mapkit.user_location.UserLocationObjectListener;
import com.yandex.mapkit.user_location.UserLocationView;
import com.yandex.runtime.Error;
import com.yandex.runtime.image.ImageProvider;
import com.yandex.mapkit.map.VisibleRegion;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.annotation.Nonnull;
import javax.annotation.Nullable;

import ru.vvdev.yamap.models.ReactMapObject;
import ru.vvdev.yamap.utils.Callback;
import ru.vvdev.yamap.utils.ImageLoader;


public class YamapView extends MapView implements UserLocationObjectListener, CameraListener, InputListener {
    // default colors for known vehicles
    // "underground" actually get color considering with his own branch"s color
    private final static Map<String, String> DEFAULT_VEHICLE_COLORS = new HashMap<String, String>() {{
        put("bus", "#59ACFF");
        put("railway", "#F8634F");
        put("tramway", "#C86DD7");
        put("suburban", "#3023AE");
        put("underground", "#BDCCDC");
        put("trolleybus", "#55CfDC");
        put("walk", "#333333");
    }};
    private String userLocationIcon = "";
    private Bitmap userLocationBitmap = null;
    private UserLocationLayer userLocationLayer = null;
    private int userLocationAccuracyFillColor = 0;
    private int userLocationAccuracyStrokeColor = 0;
    private float userLocationAccuracyStrokeWidth = 0.f;
    private List<ReactMapObject> childs = new ArrayList<>();

    // location
    private UserLocationView userLocationView = null;

    public YamapView(Context context) {
        super(context);
        init(context);
    }

    public YamapView(Context context, AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public YamapView(Context context, AttributeSet attrs, int defStyle) {
        super(context, attrs, defStyle);
        init(context);
    }

    private void init(Context context) {
        getMap().addCameraListener(this);
        getMap().addInputListener(this);
    }

    // ref methods
    public void setCenter(CameraPosition position, float duration, int animation) {
        if (duration > 0) {
            Animation.Type anim = animation == 0 ? Animation.Type.SMOOTH : Animation.Type.LINEAR;
            getMap().move(position, new Animation(anim, duration), null);
        } else {
            getMap().move(position);
        }
    }

    private WritableMap positionToJSON(CameraPosition position, boolean isFinished) {
        WritableMap cameraPosition = Arguments.createMap();
        Point point = position.getTarget();
        cameraPosition.putDouble("azimuth", position.getAzimuth());
        cameraPosition.putDouble("tilt", position.getTilt());
        cameraPosition.putDouble("zoom", position.getZoom());
        WritableMap target = Arguments.createMap();
        target.putDouble("lat", point.getLatitude());
        target.putDouble("lon", point.getLongitude());
        cameraPosition.putMap("point", target);
        cameraPosition.putBoolean("isFinished", isFinished);
        return cameraPosition;
    }

    private WritableMap regionToJSON(VisibleRegion region) {
        Point pointTopLeft = region.getTopLeft();
        Point pointTopRight = region.getTopRight();
        Point pointBottomLeft = region.getBottomLeft();
        Point pointBottomRight = region.getBottomRight();
        WritableMap visibleRegion = Arguments.createMap();
        WritableMap topLeft = Arguments.createMap();
        WritableMap topRight = Arguments.createMap();
        WritableMap bottomLeft = Arguments.createMap();
        WritableMap bottomRight = Arguments.createMap();
        topLeft.putDouble("lat", pointTopLeft.getLatitude());
        topLeft.putDouble("lon", pointTopLeft.getLongitude());
        topRight.putDouble("lat", pointTopRight.getLatitude());
        topRight.putDouble("lon", pointTopRight.getLongitude());
        bottomLeft.putDouble("lat", pointBottomLeft.getLatitude());
        bottomLeft.putDouble("lon", pointBottomLeft.getLongitude());
        bottomRight.putDouble("lat", pointBottomRight.getLatitude());
        bottomRight.putDouble("lon", pointBottomRight.getLongitude());
        visibleRegion.putMap("topLeft", topLeft);
        visibleRegion.putMap("topRight", topRight);
        visibleRegion.putMap("bottomLeft", bottomLeft);
        visibleRegion.putMap("bottomRight", bottomRight);
        return visibleRegion;
    }

    public void emitCameraPositionToJS(String id) {
        CameraPosition position = getMap().getCameraPosition();
        WritableMap cameraPosition = positionToJSON(position, true);
        cameraPosition.putString("id", id);
        ReactContext reactContext = (ReactContext) getContext();
        reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(getId(), "cameraPosition", cameraPosition);
    }

    public void emitVisibleRegionToJS(String id) {
        VisibleRegion region = getMap().getVisibleRegion();
        WritableMap visibleRegion = regionToJSON(region);
        visibleRegion.putString("id", id);
        ReactContext reactContext = (ReactContext) getContext();
        reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(getId(), "visibleRegion", visibleRegion);
    }

    public void setZoom(Float zoom, float duration, int animation) {
        CameraPosition prevPosition = getMap().getCameraPosition();
        CameraPosition position = new CameraPosition(prevPosition.getTarget(), zoom, prevPosition.getAzimuth(), prevPosition.getTilt());
        setCenter(position, duration, animation);
    }

    public void fitAllMarkers() {
        int count = 20;

        if (childs.size() < count) {
            count = childs.size();
        }

        ArrayList<Point> lastKnownMarkers = new ArrayList<>();
        for (int i = 0; i < count; ++i) {
            ReactMapObject obj = childs.get(i);
            if (obj instanceof YamapMarker) {
                YamapMarker marker = (YamapMarker) obj;
                lastKnownMarkers.add(marker.point);
            }
        }
        // todo[0]: добавить параметры анимации и дефолтного зума (для одного маркера)
        if (lastKnownMarkers.size() == 0) {
            return;
        }
        if (lastKnownMarkers.size() == 1) {
            Point center = new Point(lastKnownMarkers.get(0).getLatitude(), lastKnownMarkers.get(0).getLongitude());
            getMap().move(new CameraPosition(center, 15, 0, 0));
            return;
        }
        double minLon = lastKnownMarkers.get(0).getLongitude();
        double maxLon = lastKnownMarkers.get(0).getLongitude();
        double minLat = lastKnownMarkers.get(0).getLatitude();
        double maxLat = lastKnownMarkers.get(0).getLatitude();
        for (int i = 0; i < lastKnownMarkers.size(); i++) {
            if (lastKnownMarkers.get(i).getLongitude() > maxLon) {
                maxLon = lastKnownMarkers.get(i).getLongitude();
            }
            if (lastKnownMarkers.get(i).getLongitude() < minLon) {
                minLon = lastKnownMarkers.get(i).getLongitude();
            }
            if (lastKnownMarkers.get(i).getLatitude() > maxLat) {
                maxLat = lastKnownMarkers.get(i).getLatitude();
            }
            if (lastKnownMarkers.get(i).getLatitude() < minLat) {
                minLat = lastKnownMarkers.get(i).getLatitude();
            }
        }
        Point southWest = new Point(minLat, minLon);
        Point northEast = new Point(maxLat, maxLon);

        BoundingBox boundingBox = new BoundingBox(southWest, northEast);
        CameraPosition cameraPosition = getMap().cameraPosition(boundingBox);
        cameraPosition = new CameraPosition(cameraPosition.getTarget(), cameraPosition.getZoom() - 0.2f, cameraPosition.getAzimuth(), cameraPosition.getTilt());
        getMap().move(cameraPosition, new Animation(Animation.Type.SMOOTH, 0.7f), null);
    }

    // props
    public void setUserLocationIcon(final String iconSource) {
        // todo[0]: можно устанавливать разные иконки на покой и движение. Дополнительно можно устанавливать стиль иконки, например scale
        userLocationIcon = iconSource;
        ImageLoader.DownloadImageBitmap(getContext(), iconSource, new Callback<Bitmap>() {
            @Override
            public void invoke(Bitmap bitmap) {
                if (iconSource.equals(userLocationIcon)) {
                    userLocationBitmap = bitmap;
                    updateUserLocationIcon();
                }
            }
        });
    }

    public void setUserLocationAccuracyFillColor(int color) {
        userLocationAccuracyFillColor = color;
        updateUserLocationIcon();
    }

    public void setUserLocationAccuracyStrokeColor(int color) {
        userLocationAccuracyStrokeColor = color;
        updateUserLocationIcon();
    }

    public void setUserLocationAccuracyStrokeWidth(float width) {
        userLocationAccuracyStrokeWidth = width;
        updateUserLocationIcon();
    }

    public void setMapStyle(@Nullable String style) {
        if (style != null) {
            getMap().setMapStyle(style);
        }
    }

    public void setNightMode(Boolean nightMode) {
        getMap().setNightModeEnabled(nightMode);
    }

    public void setShowUserPosition(Boolean show) {
        if (userLocationLayer == null) {
            userLocationLayer = MapKitFactory.getInstance().createUserLocationLayer(getMapWindow());
        }
        if (show) {
            userLocationLayer.setObjectListener(this);
            userLocationLayer.setVisible(true);
            userLocationLayer.setHeadingEnabled(true);
        } else {
            userLocationLayer.setVisible(false);
            userLocationLayer.setHeadingEnabled(false);
            userLocationLayer.setObjectListener(null);
        }
    }

    private String formatColor(int color) {
        return String.format("#%06X", (0xFFFFFF & color));
    }

    // children
    public void addFeature(View child, int index) {
        if (child instanceof YamapMarker) {
            YamapMarker _child = (YamapMarker) child;
            PlacemarkMapObject obj = getMap().getMapObjects().addPlacemark(_child.point);
            _child.setMapObject(obj);
            childs.add(_child);
        }
    }

    public void removeChild(int index) {
        if (index < childs.size()) {
            ReactMapObject child = childs.remove(index);
            getMap().getMapObjects().remove(child.getMapObject());
        }
    }

    // location listener implementation
    @Override
    public void onObjectAdded(@Nonnull UserLocationView _userLocationView) {
        userLocationView = _userLocationView;
        updateUserLocationIcon();
    }

    @Override
    public void onObjectRemoved(@Nonnull UserLocationView userLocationView) {
    }

    @Override
    public void onObjectUpdated(@Nonnull UserLocationView _userLocationView, @Nonnull ObjectEvent objectEvent) {
        userLocationView = _userLocationView;
        updateUserLocationIcon();
    }

    private void updateUserLocationIcon() {
        if (userLocationView != null) {
            PlacemarkMapObject pin = userLocationView.getPin();
            PlacemarkMapObject arrow = userLocationView.getArrow();
            if (userLocationBitmap != null) {
                pin.setIcon(ImageProvider.fromBitmap(userLocationBitmap));
                arrow.setIcon(ImageProvider.fromBitmap(userLocationBitmap));
            }
            CircleMapObject circle = userLocationView.getAccuracyCircle();
            if (userLocationAccuracyFillColor != 0) {
                circle.setFillColor(userLocationAccuracyFillColor);
            }
            if (userLocationAccuracyStrokeColor != 0) {
                circle.setStrokeColor(userLocationAccuracyStrokeColor);
            }
            circle.setStrokeWidth(userLocationAccuracyStrokeWidth);
        }
    }

    @Override
    public void onCameraPositionChanged(@NonNull com.yandex.mapkit.map.Map map, @NonNull CameraPosition cameraPosition, @NonNull CameraUpdateReason cameraUpdateReason, boolean isFinished) {
        WritableMap position = positionToJSON(cameraPosition, isFinished);
        ReactContext reactContext = (ReactContext) getContext();
        reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(getId(), "cameraPositionChanged", position);
    }

    @Override
    public void onMapTap(@NonNull com.yandex.mapkit.map.Map map, @NonNull Point point) {
        WritableMap data = Arguments.createMap();
        data.putDouble("lat", point.getLatitude());
        data.putDouble("lon", point.getLongitude());
        ReactContext reactContext = (ReactContext) getContext();
        reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(getId(), "onMapPress", data);
    }

    @Override
    public void onMapLongTap(@NonNull com.yandex.mapkit.map.Map map, @NonNull Point point) {
        WritableMap data = Arguments.createMap();
        data.putDouble("lat", point.getLatitude());
        data.putDouble("lon", point.getLongitude());
        ReactContext reactContext = (ReactContext) getContext();
        reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(getId(), "onMapLongPress", data);
    }
}
