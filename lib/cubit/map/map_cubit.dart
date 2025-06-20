import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_ce/hive.dart';
import 'package:luogo/utils/mapping.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:luogo/cubit/map/map_state.dart';
import 'package:luogo/main.dart';

class MapCubit extends Cubit<MapState> {
  MapCubit() : super(MapInitial()) {
    // Initialize the position watcher
    locationService.locationBox
        .watch(key: 'local_position')
        .listen((event) async {
      // First parse the info
      if (event.value == null) {
        return;
      }
      // First check if the user is centered
      final CameraPosition? cameraPosition =
          (await mapController.future).cameraPosition;
      final double camLat = cameraPosition?.target.latitude ?? 0;
      final double camLong = cameraPosition?.target.longitude ?? 0;
      final double userLat = _userPosition?.latitude ?? 0;
      final double userLong = _userPosition?.longitude ?? 0;
      bool isCentered = (userLat - camLat).abs() < 0.0001 &&
          (userLong - camLong).abs() < 0.0001;

      // Also check if it is the first time a location is being written (always want to center then)
      bool firstGo = _userPosition == null;

      // Then update the user position
      if (event.value != null) {
        _userPosition = event.value.toLatLng();
      }

      // And if the position hasn't been editied of the camera, move it
      if (isCentered || firstGo) {
        // update the camera position
        updateCamera(event.value.toLatLng());
      }

      // But always move the pin if there's a valid location
      if (_userSymbol != null) {
        // And update the pin location
        final controller = await mapController.future;
        controller.updateSymbol(
            _userSymbol!, SymbolOptions(geometry: _userPosition));
      }
    });
  }

  @override
  Future<void> close() {
    _positionWatcher.cancel();
    return super.close();
  }

  // Vars
  Completer<MapLibreMapController> mapController = Completer();
  LatLng? _userPosition; // Store position for later use
  late StreamSubscription<BoxEvent> _positionWatcher;
  Symbol? _userSymbol; // Store local user symbol to be moved

  // Getters
  LatLng? get userPosition => _userPosition;

  // Funcitons
  void mapCreated(MapLibreMapController controller) async {
    mapController.complete(controller);
    controller.onSymbolTapped.add(_onSymbolTapped);
    emit(MapReady());
    if (_userPosition != null) {
      await moveToUser(); // Auto-center on user location
    }

    // Now add personal users
    // TODO Make a better way to handle this and others
    // TODO Handle filling in the circle
    // First load in the image
    await addImageFromAsset(controller, "pin-drop", "assets/pin.png");
    //Now go through and put it on the map
    _userSymbol = await controller.addSymbol(SymbolOptions(
        geometry: _userPosition,
        iconImage: "pin-drop",
        iconSize: 1.0,
        iconAnchor: 'bottom'));
    logger.d("added image asset");
  }

  void _onSymbolTapped(Symbol symbol) {
    emit(MapSymbolClicked(symbolID: symbol.id));
    logger.d("Tapped Symbol: $symbol");
  }

  Future<void> moveToUser() async {
    final controller = await mapController.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
              _userPosition?.latitude ?? 0, _userPosition?.longitude ?? 0),
          zoom: 10.0,
        ),
      ),
    );
  }

  Future<void> updateCamera(LatLng position) async {
    final controller = await mapController.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: 10.0,
        ),
      ),
    );
  }
}
