import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:luogo/main.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import './map_event.dart';
import './map_state.dart';

// This defines the buisness logic of the map screen
class MapBloc extends Bloc<MapEvent, MapState> {
  MapBloc() : super(MapInitial()) {
    on<MapCreated>(_onMapCreated);
    on<MoveToUser>(_onMoveToUser);
    on<LocationUpdated>(_onLocationUpdated);
  }

  Completer<MapLibreMapController> mapController = Completer();

  Future<void> _onMapCreated(MapCreated event, Emitter<MapState> emit) async {
    mapController.complete(event.controller);
    emit(MapReady());
  }

  Future<void> _onMoveToUser(MoveToUser event, Emitter<MapState> emit) async {
    Position? userPosition = locationService.locationBox.get('local_position');

    final controller = await mapController.future;
    // TODO make the default location _not_ null island
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

  Future<void> _onLocationUpdated(
      LocationUpdated event, Emitter<MapState> emit) async {
    final controller = await mapController.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(event.position.longitude, event.position.latitude),
          zoom: 15.0, // Adjust zoom as needed
        ),
      ),
    );
  }
}
