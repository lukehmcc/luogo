import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:equatable/equatable.dart';

abstract class MapEvent extends Equatable {
  const MapEvent();

  @override
  List<Object> get props => [];
}

class MapCreated extends MapEvent {
  final MapLibreMapController controller;
  const MapCreated(this.controller);

  @override
  List<Object> get props => [controller];
}

class MoveToUser extends MapEvent {
  const MoveToUser();
}

class LocationUpdated extends MapEvent {
  final Position position;
  const LocationUpdated(this.position);
}
