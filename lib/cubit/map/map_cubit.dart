import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_ce/hive.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:luogo/cubit/map/map_state.dart';
import 'package:luogo/main.dart';

class MapCubit extends Cubit<MapState> {
  MapCubit() : super(MapInitial()) {
    // Initialize the position watcher
    final _positionWatcher = locationService.locationBox
        .watch(key: 'local_position')
        .listen((event) {
      logger.d("callback activated");
      // First parse the info
      if (event.value == null) {
        return;
      }
      logger.d("value not null");
      final newLocaiton = event.value.toLatLng();
      // First check if the user is centered
      bool isCentered = (_userPosition?.latitude ?? 0 - newLocaiton.latitude)
                  .abs() <
              0.0001 &&
          (userPosition?.longitude ?? 0 - newLocaiton.longitude).abs() < 0.0001;
      // Also check if it is the first time a location is being written (always want to center then)
      bool firstGo = _userPosition == null;
      // Then update the user position
      if (event.value != null) {
        _userPosition = event.value.toLatLng();
      }
      // And if the position should be updated, update it
      if (isCentered || firstGo) {
        updateCamera(event.value.toLatLng());
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
  LatLng? _currentMapPosition; // Stores the current map position
  late StreamSubscription<BoxEvent> _positionWatcher;

  // Getters
  LatLng? get userPosition => _userPosition;

  // Funcitons
  void mapCreated(MapLibreMapController controller) async {
    mapController.complete(controller);
    // Set up camera location listener
    // controller.addListener(() {
    //   if (controller.isCameraMoving) {
    //     logger.d("Camera moving!");
    //   }
    // });
    emit(MapReady());
    if (_userPosition != null) {
      await moveToUser(); // Auto-center on user location
    }
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
