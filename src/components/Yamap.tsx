import React from 'react';
import {
  Platform,
  requireNativeComponent,
  NativeModules,
  UIManager,
  findNodeHandle,
  ViewProps,
  ImageSourcePropType, NativeSyntheticEvent,
} from 'react-native';
// @ts-ignore
import resolveAssetSource from 'react-native/Libraries/Image/resolveAssetSource';
import CallbacksManager from '../utils/CallbacksManager';
import { Animation, Point, CameraPosition, VisibleRegion } from '../interfaces';
import { processColorProps } from '../utils';

const { yamap: NativeYamapModule } = NativeModules;

export interface YaMapProps extends ViewProps {
  userLocationIcon?: ImageSourcePropType;
  showUserPosition?: boolean;
  mapStyle?: string;
  onCameraPositionChange?: (event: NativeSyntheticEvent<CameraPosition>) => void;
  onMapPress?: (event: NativeSyntheticEvent<Point>) => void;
  onMapLongPress?: (event: NativeSyntheticEvent<Point>) => void;
  userLocationAccuracyFillColor?: string;
  userLocationAccuracyStrokeColor?: string;
  userLocationAccuracyStrokeWidth?: number;
}

const YaMapNativeComponent = requireNativeComponent<YaMapProps>('YamapView');

export class YaMap extends React.Component<YaMapProps> {
  static defaultProps = {
    showUserPosition: true,
  };

  // @ts-ignore
  map = React.createRef<YaMapNativeComponent>();

  public static init(apiKey: string) {
    NativeYamapModule.init(apiKey);
  }

  public fitAllMarkers() {
    UIManager.dispatchViewManagerCommand(
      findNodeHandle(this),
      this.getCommand('fitAllMarkers'),
      [],
    );
  }

  public setCenter(center: { lon: number, lat: number, zoom?: number }, zoom: number = center.zoom || 10, azimuth: number = 0, tilt: number = 0, duration: number = 0, animation: Animation = Animation.SMOOTH) {
    UIManager.dispatchViewManagerCommand(
      findNodeHandle(this),
      this.getCommand('setCenter'),
      [center, zoom, azimuth, tilt, duration, animation],
    );
  }

  public setZoom(zoom: number, duration: number = 0, animation: Animation = Animation.SMOOTH) {
    UIManager.dispatchViewManagerCommand(
      findNodeHandle(this),
      this.getCommand('setZoom'),
      [zoom, duration, animation],
    );
  }

  public getCameraPosition(callback: (position: CameraPosition) => void) {
    const cbId = CallbacksManager.addCallback(callback);
    UIManager.dispatchViewManagerCommand(
      findNodeHandle(this),
      this.getCommand('getCameraPosition'),
      [cbId],
    );
  }

  public getVisibleRegion(callback: (region: VisibleRegion) => void) {
    const cbId = CallbacksManager.addCallback(callback);
    UIManager.dispatchViewManagerCommand(
      findNodeHandle(this),
      this.getCommand('getVisibleRegion'),
      [cbId],
    );
  }

  private getCommand(cmd: string): any {
    if (Platform.OS === 'ios') {
      return UIManager.getViewManagerConfig('YamapView').Commands[cmd];
    } else {
      return cmd;
    }
  }

  private processCameraPosition(event: any) {
    const { id, ...position } = event.nativeEvent;
    CallbacksManager.call(id, position);
  }

  private processVisibleRegion(event: NativeSyntheticEvent<{id: string} & VisibleRegion>) {
    const {id, ...visibleRegion} = event.nativeEvent;
    CallbacksManager.call(id, visibleRegion);
  }

  private resolveImageUri(img: ImageSourcePropType) {
    return img ? resolveAssetSource(img).uri : '';
  }

  private getProps() {
    const props = {
      ...this.props,
      onCameraPositionReceived: this.processCameraPosition,
      onVisibleRegionReceived: this.processVisibleRegion,
      userLocationIcon: this.props.userLocationIcon ? this.resolveImageUri(this.props.userLocationIcon) : undefined,
    };
    processColorProps(props, 'userLocationAccuracyFillColor' as keyof YaMapProps);
    processColorProps(props, 'userLocationAccuracyStrokeColor' as keyof YaMapProps);
    return props;
  }

  render() {
    return (
      <YaMapNativeComponent
        {...this.getProps()}
        ref={this.map}
      />
    );
  }
}
