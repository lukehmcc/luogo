abstract class MapOverlayState {}

class MapOverlayInitial extends MapOverlayState {}

class MapOverlayReady extends MapOverlayState {}

class MapOverlayQRPopupPressed extends MapOverlayState {
  String keypair;
  MapOverlayQRPopupPressed({required this.keypair});
}
