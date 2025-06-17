import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:luogo/cubit/map/map_cubit.dart';
import 'package:luogo/cubit/map/map_state.dart';

class MapView extends StatelessWidget {
  const MapView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MapCubit(),
      child: Scaffold(
        floatingActionButtonLocation:
            FloatingActionButtonLocation.miniCenterFloat,
        body: BlocBuilder<MapCubit, MapState>(
          builder: (context, state) {
            return Stack(
              children: [
                MapLibreMap(
                  onMapCreated: (controller) =>
                      context.read<MapCubit>().mapCreated(controller),
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(42.361145, -71.057083),
                    zoom: 10.0,
                  ),
                  styleString: "assets/pmtiles_style.json",
                ),
                if (state is! MapReady)
                  const Center(child: CircularProgressIndicator()),
                if (state is MapReady)
                  Positioned(
                    bottom: 20,
                    child: Center(
                      child: FloatingActionButton(
                        onPressed: () => context.read<MapCubit>().moveToUser(),
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
    );
  }
}
