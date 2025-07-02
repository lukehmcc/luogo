import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/map_overlay/map_overlay_state.dart';

class MapOverlayCubit extends Cubit<MapOverlayState> {
  MapOverlayCubit() : super(MapOverlayInitial());
}
