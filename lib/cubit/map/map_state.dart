abstract class MapState {}

class MapInitial extends MapState {}

class MapReady extends MapState {}

class MapSymbolClicked extends MapState {
  final String symbolID;
  MapSymbolClicked({required this.symbolID});
}
