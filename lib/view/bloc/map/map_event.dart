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

class MoveToBoston extends MapEvent {
  const MoveToBoston();
}
