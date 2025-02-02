#import <React/RCTComponent.h>
#import <React/UIView+React.h>
#import <React/RCTConvert.h>

#import <MapKit/MapKit.h>
#import <YandexMapKit/YMKMapKitFactory.h>
#import <YandexMapKit/YMKMapView.h>
#import <YandexMapKit/YMKBoundingBox.h>
#import <YandexMapKit/YMKCameraPosition.h>
#import <YandexMapKit/YMKVisibleRegion.h>
#import <YandexMapKit/YMKMap.h>
#import <YandexMapKit/YMKMapObjectCollection.h>
#import <YandexMapKit/YMKGeoObjectCollection.h>


#ifndef MAX
#import <NSObjCRuntime.h>
#endif

#import "YamapMarkerView.h"
#import "RNYMView.h"


#define ANDROID_COLOR(c) [UIColor colorWithRed:((c>>16)&0xFF)/255.0 green:((c>>8)&0xFF)/255.0 blue:((c)&0xFF)/255.0  alpha:((c>>24)&0xFF)/255.0]

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

@implementation RNYMView {
    NSMutableArray<UIView*>* _reactSubviews;
    NSMutableArray<YMKRequestPoint *>* lastKnownRoutePoints;
    YMKUserLocationView* userLocationView;
    UIImage* userLocationImage;
    NSArray *acceptVehicleTypes;
    YMKUserLocationLayer *userLayer;
    UIColor* userLocationAccuracyFillColor;
    UIColor* userLocationAccuracyStrokeColor;
    float userLocationAccuracyStrokeWidth;
}

- (instancetype)init {
    self = [super init];
    _reactSubviews = [[NSMutableArray alloc] init];
    userLocationAccuracyFillColor = nil;
    userLocationAccuracyStrokeColor = nil;
    userLocationAccuracyStrokeWidth = 0.f;
    [self.mapWindow.map addCameraListenerWithCameraListener:self];
    [self.mapWindow.map addInputListenerWithInputListener:(id<YMKMapInputListener>) self];
    return self;
}

-(UIImage*) resolveUIImage:(NSString*) uri {
    UIImage *icon;
    if ([uri rangeOfString:@"http://"].location == NSNotFound && [uri rangeOfString:@"https://"].location == NSNotFound) {
        if ([uri rangeOfString:@"file://"].location != NSNotFound){
            icon = icon = [RCTConvert UIImage:uri];
        } else {
            icon = [UIImage imageNamed:uri];
        }
    } else {
        icon = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:uri]]];
    }
    return icon;
}

-(void)onReceiveNativeEvent:(NSDictionary *)response {
    if (self.onRouteFound) self.onRouteFound(response);
}

-(void) removeAllSections {
    [self.mapWindow.map.mapObjects clear];
}

// ref
-(void) setCenter:(YMKCameraPosition*) position withDuration:(float) duration withAnimation:(int) animation {
    if (duration > 0) {
        YMKAnimationType anim = animation == 0 ? YMKAnimationTypeSmooth : YMKAnimationTypeLinear;
        [self.mapWindow.map moveWithCameraPosition:position animationType:[YMKAnimation animationWithType:anim duration: duration] cameraCallback: ^(BOOL completed) {
         }];
    } else {
        [self.mapWindow.map moveWithCameraPosition:position];
    }
}

-(void) setZoom:(float) zoom withDuration:(float) duration withAnimation:(int) animation {
    YMKCameraPosition* prevPosition = self.mapWindow.map.cameraPosition;
    YMKCameraPosition* position = [YMKCameraPosition cameraPositionWithTarget:prevPosition.target zoom:zoom azimuth:prevPosition.azimuth tilt:prevPosition.tilt];
    [self setCenter:position withDuration:duration withAnimation:animation];
}

-(NSDictionary*) cameraPositionToJSON:(YMKCameraPosition*) position finished:(BOOL) finished {
    return @{
        @"azimuth": [NSNumber numberWithFloat:position.azimuth],
        @"tilt": [NSNumber numberWithFloat:position.tilt],
        @"zoom": [NSNumber numberWithFloat:position.zoom],
        @"isFinished": [NSNumber numberWithBool:finished],
        @"point": @{
                @"lat": [NSNumber numberWithDouble:position.target.latitude],
                @"lon": [NSNumber numberWithDouble:position.target.longitude],
        }
    };
}

-(NSDictionary*) regionToJSON:(YMKVisibleRegion*) region {
    return @{
        @"topLeft": @{
                @"lat": [NSNumber numberWithDouble:region.topLeft.latitude],
                @"lon": [NSNumber numberWithDouble:region.topLeft.longitude],
        },
        @"topRight": @{
                @"lat": [NSNumber numberWithDouble:region.topRight.latitude],
                @"lon": [NSNumber numberWithDouble:region.topRight.longitude],
        },
        @"bottomLeft": @{
                @"lat": [NSNumber numberWithDouble:region.bottomLeft.latitude],
                @"lon": [NSNumber numberWithDouble:region.bottomLeft.longitude],
        },
        @"bottomRight": @{
                @"lat": [NSNumber numberWithDouble:region.bottomRight.latitude],
                @"lon": [NSNumber numberWithDouble:region.bottomRight.longitude],
        }
    };
}

-(void) emitCameraPositionToJS:(NSString*) _id {
    YMKCameraPosition* position = self.mapWindow.map.cameraPosition;
    NSDictionary* cameraPosition = [self cameraPositionToJSON:position finished:YES];
    NSMutableDictionary *response = [NSMutableDictionary dictionaryWithDictionary:cameraPosition];
    [response setValue:_id forKey:@"id"];
    if (self.onCameraPositionReceived) {
        self.onCameraPositionReceived(response);
    }
}

-(void) emitVisibleRegionToJS:(NSString*) _id {
    YMKVisibleRegion* region = self.mapWindow.map.visibleRegion;
    NSDictionary* visibleRegion = [self regionToJSON:region];
    NSMutableDictionary *response = [NSMutableDictionary dictionaryWithDictionary:visibleRegion];
    [response setValue:_id forKey:@"id"];
    if (self.onVisibleRegionReceived) {
        self.onVisibleRegionReceived(response);
    }
}


- (void)onCameraPositionChangedWithMap:(nonnull YMKMap *)map
    cameraPosition:(nonnull YMKCameraPosition *)cameraPosition
cameraUpdateSource:(YMKCameraUpdateSource)cameraUpdateSource
                              finished:(BOOL)finished {
    NSDictionary* position = [self cameraPositionToJSON:cameraPosition finished:finished];
    NSMutableDictionary *response = [NSMutableDictionary dictionaryWithDictionary:position];
    if (self.onCameraPositionChange) {
        self.onCameraPositionChange(response);
    }
}

-(void) setNightMode:(BOOL)nightMode {
    [self.mapWindow.map setNightModeEnabled:nightMode];
}

-(void) setListenUserLocation:(BOOL)listen {
    YMKMapKit* inst = [YMKMapKit sharedInstance];
    if (userLayer == nil) {
        userLayer = [inst createUserLocationLayerWithMapWindow: self.mapWindow];
    }
    if (listen) {
        [userLayer setVisibleWithOn:YES];
        [userLayer setObjectListenerWithObjectListener: self];
    } else {
        [userLayer setVisibleWithOn:NO];
        [userLayer setObjectListenerWithObjectListener: nil];
    }
}

-(void) fitAllMarkers {
    NSMutableArray<YMKPoint*>* lastKnownMarkers = [[NSMutableArray alloc] init];
    int count = 20;

    if ([_reactSubviews count] < count) {
        count = [_reactSubviews count];
    }

    for (int i = 0; i < count; ++i) {
        UIView* view = [_reactSubviews objectAtIndex:i];
        if ([view isKindOfClass:[YamapMarkerView class]]) {
            YamapMarkerView* marker = (YamapMarkerView*) view;
            [lastKnownMarkers addObject:[marker getPoint]];
        }
    }
    if ([lastKnownMarkers count] == 0) {
        return;
    }
    if ([lastKnownMarkers count] == 1) {
        YMKPoint *center = [lastKnownMarkers objectAtIndex:0];
        [self.mapWindow.map moveWithCameraPosition:[YMKCameraPosition cameraPositionWithTarget:center zoom:15 azimuth:0 tilt:0]];
        return;
    }
    double minLon = [lastKnownMarkers[0] longitude], maxLon = [lastKnownMarkers[0] longitude];
    double minLat = [lastKnownMarkers[0] latitude], maxLat = [lastKnownMarkers[0] latitude];
    for (int i = 0; i < [lastKnownMarkers count]; i++) {
        if ([lastKnownMarkers[i] longitude] > maxLon) maxLon = [lastKnownMarkers[i] longitude];
        if ([lastKnownMarkers[i] longitude] < minLon) minLon = [lastKnownMarkers[i] longitude];
        if ([lastKnownMarkers[i] latitude] > maxLat) maxLat = [lastKnownMarkers[i] latitude];
        if ([lastKnownMarkers[i] latitude] < minLat) minLat = [lastKnownMarkers[i] latitude];
    }
    YMKPoint *southWest = [YMKPoint pointWithLatitude:minLat longitude:minLon];
    YMKPoint *northEast = [YMKPoint pointWithLatitude:maxLat longitude:maxLon];
    YMKPoint *rectCenter = [YMKPoint pointWithLatitude:(minLat + maxLat) / 2 longitude:(minLon + maxLon) / 2];
    CLLocation *centerP = [[CLLocation alloc] initWithLatitude:northEast.latitude longitude:northEast.longitude];
    CLLocation *edgeP = [[CLLocation alloc] initWithLatitude:rectCenter.latitude longitude:rectCenter.longitude];
    CLLocationDistance distance = [centerP distanceFromLocation:edgeP];
    double scale = (distance/2)/140;
    int zoom = (int) (16 - log(scale) / log(2));
    YMKBoundingBox *boundingBox = [YMKBoundingBox boundingBoxWithSouthWest:southWest northEast:northEast];
    YMKCameraPosition *cameraPosition = [self.mapWindow.map cameraPositionWithBoundingBox:boundingBox];
    cameraPosition = [YMKCameraPosition cameraPositionWithTarget:cameraPosition.target zoom:zoom azimuth:cameraPosition.azimuth tilt:cameraPosition.tilt];
    [self.mapWindow.map moveWithCameraPosition:cameraPosition animationType:[YMKAnimation animationWithType:YMKAnimationTypeSmooth duration:1.0] cameraCallback:^(BOOL completed){}];
}

// props
-(void) setUserLocationIcon:(NSString*) iconSource {
    userLocationImage = [self resolveUIImage: iconSource];
    [self updateUserIcon];
}

-(void) setUserLocationAccuracyFillColor: (UIColor*) color {
    userLocationAccuracyFillColor = color;
    [self updateUserIcon];
}

-(void) setUserLocationAccuracyStrokeColor: (UIColor*) color {
    userLocationAccuracyStrokeColor = color;
    [self updateUserIcon];
}

-(void) setUserLocationAccuracyStrokeWidth: (float) width {
    userLocationAccuracyStrokeWidth = width;
    [self updateUserIcon];
}

-(void) updateUserIcon {
    if (userLocationView != nil) {
        if (userLocationImage) {
            [userLocationView.pin setIconWithImage: userLocationImage];
            [userLocationView.arrow setIconWithImage: userLocationImage];
        }
        YMKCircleMapObject* circle = userLocationView.accuracyCircle;
        if (userLocationAccuracyFillColor) {
            [circle setFillColor:userLocationAccuracyFillColor];
        }
        if (userLocationAccuracyStrokeColor) {
            [circle setStrokeColor:userLocationAccuracyStrokeColor];
        }
        [circle setStrokeWidth:userLocationAccuracyStrokeWidth];
    }
}

// user location listener implementation
- (void)onObjectAddedWithView:(nonnull YMKUserLocationView *)view {
    userLocationView = view;
    [self updateUserIcon];
}

- (void)onObjectRemovedWithView:(nonnull YMKUserLocationView *)view {
}

- (void)onObjectUpdatedWithView:(nonnull YMKUserLocationView *)view event:(nonnull YMKObjectEvent *)event {
    userLocationView = view;
    [self updateUserIcon];
}

- (void)onMapTapWithMap:(nonnull YMKMap *)map
                  point:(nonnull YMKPoint *)point {
    if (self.onMapPress) {
        NSDictionary* data = @{
            @"lat": [NSNumber numberWithDouble:point.latitude],
            @"lon": [NSNumber numberWithDouble:point.longitude],
        };
        self.onMapPress(data);
    }
}

- (void)onMapLongTapWithMap:(nonnull YMKMap *)map
                      point:(nonnull YMKPoint *)point {
    if (self.onMapLongPress) {
        NSDictionary* data = @{
            @"lat": [NSNumber numberWithDouble:point.latitude],
            @"lon": [NSNumber numberWithDouble:point.longitude],
        };
        self.onMapLongPress(data);
    }
}

// utils
+(UIColor *) colorFromHexString:(NSString*) hexString {
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1];
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

+(NSString*) hexStringFromColor:(UIColor *) color {
    const CGFloat *components = CGColorGetComponents(color.CGColor);
    CGFloat r = components[0];
    CGFloat g = components[1];
    CGFloat b = components[2];
    return [NSString stringWithFormat:@"#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255)];
}

// children
-(void)addSubview:(UIView *)view {
    [super addSubview:view];
}

- (void)insertReactSubview:(UIView<RCTComponent>*)subview atIndex:(NSInteger)atIndex {
    if ([subview isKindOfClass:[YamapMarkerView class]]) {
        YMKMapObjectCollection *objects = self.mapWindow.map.mapObjects;
        YamapMarkerView* marker = (YamapMarkerView*) subview;
        YMKPlacemarkMapObject* obj = [objects addPlacemarkWithPoint:[marker getPoint]];
        [marker setMapObject:obj];
    } else {
        NSArray<id<RCTComponent>> *childSubviews = [subview reactSubviews];
        for (int i = 0; i < childSubviews.count; i++) {
            [self insertReactSubview:(UIView *)childSubviews[i] atIndex:atIndex];
        }
    }
    [_reactSubviews insertObject:subview atIndex:atIndex];
    [super insertReactSubview:subview atIndex:atIndex];
}

- (void)removeReactSubview:(UIView<RCTComponent>*)subview {
    if ([subview isKindOfClass:[YamapMarkerView class]]) {
        YMKMapObjectCollection *objects = self.mapWindow.map.mapObjects;
        YamapMarkerView* marker = (YamapMarkerView*) subview;
        [objects removeWithMapObject:[marker getMapObject]];
    } else {
        NSArray<id<RCTComponent>> *childSubviews = [subview reactSubviews];
        for (int i = 0; i < childSubviews.count; i++) {
            [self removeReactSubview:(UIView *)childSubviews[i]];
        }
    }
    [_reactSubviews removeObject:subview];
    [super removeReactSubview: subview];
}

@synthesize reactTag;

@end
