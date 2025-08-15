import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/view/page/map/bottom_sheet_info_modal.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:luogo/cubit/map/map_cubit.dart';
import 'package:luogo/cubit/map/map_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The primary map interface widget using MapLibre GL for map rendering.
///
/// This widget provides:
/// - Interactive map display with style configuration
/// - User location tracking functionality
/// - Bottom sheet modals for symbol/point interactions
/// - Floating action buttons for map navigation
///
/// Dependencies:
/// - [locationService]: Handles location updates and peer communication
/// - [prefs]: Shared preferences for persistent settings
///
/// Behavior:
/// - Listens to [MapCubit] state changes for UI updates
/// - Shows [BottomSheetInfoModal] when map symbols are clicked
/// - Provides "recenter" and "send location" FAB controls
/// - Initializes with default camera position (LatLng(1,1) at zoom 10)
///
/// UI Structure:
/// 1. Base MapLibre map (full screen)
/// 2. Floating action buttons:
///    - Right: Recenter map to user location
/// 3. Dynamic bottom sheet modal for point information
///
/// Note: Uses 'assets/pmtiles_style.json' for map styling configuration
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
                builder: (BuildContext context) => BottomSheetInfoModal(
                      userState: state.userState,
                      isYou: state.isYou,
                    ));
          }
        },

        // This section reacts to state to draw the main page
        child: BlocBuilder<MapCubit, MapState>(
          builder: (context, state) {
            return SafeArea(
              top: false,
              child: Stack(
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
                          heroTag: "map-hero-floater",
                          onPressed: () =>
                              context.read<MapCubit>().moveToUser(),
                          mini: true,
                          child: const Icon(Icons.navigation),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
