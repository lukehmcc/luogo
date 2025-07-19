import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/services/location_service.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:luogo/cubit/map/map_cubit.dart';
import 'package:luogo/cubit/map/map_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MapView is the main maplibre/protomaps map that this app uses
class MapView extends StatelessWidget {
  final LocationService locationService;
  final SharedPreferencesWithCache prefs;
  const MapView({
    super.key,
    required this.locationService,
    required this.prefs,
  });

  @override
  Widget build(BuildContext context) {
    // Use BlocProvider to handle cubit state
    return Scaffold(
      floatingActionButtonLocation:
          FloatingActionButtonLocation.miniCenterFloat,

      // This section reacts to state to draw modals and such
      body: BlocListener<MapCubit, MapState>(
        listener: (BuildContext context, MapState state) {
          if (state is MapSymbolClicked) {
            showModalBottomSheet<dynamic>(
              context: context,
              builder: (BuildContext context) => SizedBox(
                height: 200,
                child: Center(
                  child: Text(state.symbolID),
                ),
              ),
            );
          }
        },

        // This section reacts to state to draw the main page
        child: BlocBuilder<MapCubit, MapState>(
          builder: (context, state) {
            return Stack(
              children: [
                MapLibreMap(
                  onMapCreated: (controller) =>
                      context.read<MapCubit>().mapCreated(controller),
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(1, 1),
                    zoom: 10.0,
                  ),
                  trackCameraPosition: true,
                  styleString: "assets/pmtiles_style.json",
                ),
                if (state is! MapInitial)
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: Center(
                      child: FloatingActionButton(
                        onPressed: () => context.read<MapCubit>().moveToUser(),
                        mini: true,
                        child: const Icon(Icons.restore),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Center(
                    child: FloatingActionButton(
                      onPressed: () => locationService.pingPeers(),
                      mini: true,
                      child: const Icon(Icons.send),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
