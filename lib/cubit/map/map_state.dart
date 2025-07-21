import 'package:luogo/model/user_state.dart';

abstract class MapState {}

class MapInitial extends MapState {}

class MapReady extends MapState {}

class MapSymbolClicked extends MapState {
  final UserState userState;
  final bool isYou;
  MapSymbolClicked({required this.userState, required this.isYou});
}
