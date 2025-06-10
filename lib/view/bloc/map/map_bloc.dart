import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import './map_event.dart';
import './map_state.dart';

class MapBloc extends Bloc<MapEvent, MapState> {
  MapBloc() : super(MapInitial()) {
    on<MapCreated>(_onMapCreated);
    on<MoveToBoston>(_onMoveToBoston);
  }

  Completer<MapLibreMapController> mapController = Completer();

  Future<void> _onMapCreated(MapCreated event, Emitter<MapState> emit) async {
    mapController.complete(event.controller);
    emit(MapReady());
  }

  Future<void> _onMoveToBoston(
      MoveToBoston event, Emitter<MapState> emit) async {
    final controller = await mapController.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(
          target: LatLng(42.361145, -71.057083),
          zoom: 10.0,
        ),
      ),
    );
  }
}
