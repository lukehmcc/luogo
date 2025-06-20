import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:luogo/cubit/map/map_cubit.dart';
import 'package:luogo/cubit/map/map_state.dart';

/// MapView is the main maplibre/protomaps map that this app uses
class MapView extends StatelessWidget {
  const MapView({super.key});

  @override
  Widget build(BuildContext context) {
    // Use BlocProvider to handle cubit state
    return BlocProvider(
        create: (context) => MapCubit(),
        child: Scaffold(
          floatingActionButtonLocation:
              FloatingActionButtonLocation.miniCenterFloat,

          // This section reacts to state to draw modals and such
          body: BlocListener<MapCubit, MapState>(
            listener: (context, state) {
              if (state is MapSymbolClicked) {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => SizedBox(
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
                            onPressed: () =>
                                context.read<MapCubit>().moveToUser(),
                            mini: true,
                            child: const Icon(Icons.restore),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ));
  }
}
