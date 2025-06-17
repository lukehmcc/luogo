import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:luogo/cubit/map/map_state.dart';
import 'package:luogo/main.dart';

class MapCubit extends Cubit<MapState> {
  MapCubit() : super(MapInitial());

  Completer<MapLibreMapController> mapController = Completer();

  void mapCreated(MapLibreMapController controller) {
    mapController.complete(controller);
    emit(MapReady());
  }

  Future<void> moveToUser() async {
    Position? userPosition = locationService.locationBox.get('local_position');
    final controller = await mapController.future;

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target:
              LatLng(userPosition?.latitude ?? 0, userPosition?.longitude ?? 0),
          zoom: 10.0,
        ),
      ),
    );
  }

  Future<void> updateLocation(Position position) async {
    final controller = await mapController.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.longitude, position.latitude),
          zoom: 15.0,
        ),
      ),
    );
  }
}
