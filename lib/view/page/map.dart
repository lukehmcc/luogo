import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../bloc/map/map_bloc.dart';
import '../bloc/map/map_state.dart';
import '../bloc/map/map_event.dart';

class MapView extends StatelessWidget {
  const MapView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MapBloc(),
      child: Scaffold(
        floatingActionButtonLocation:
            FloatingActionButtonLocation.miniCenterFloat,
        body: BlocBuilder<MapBloc, MapState>(
          builder: (context, state) {
            return Stack(
              children: [
                MapLibreMap(
                  onMapCreated: (controller) =>
                      context.read<MapBloc>().add(MapCreated(controller)),
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(42.361145, -71.057083),
                    zoom: 10.0,
                  ),
                  styleString: "assets/pmtiles_style.json",
                ),
                if (state is! MapReady)
                  Center(
                    child: CircularProgressIndicator(),
                  ),
                if (state is MapReady)
                  Positioned(
                    bottom: 20,
                    child: Center(
                      child: FloatingActionButton(
                        onPressed: () =>
                            context.read<MapBloc>().add(const MoveToUser()),
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
