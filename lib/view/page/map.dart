import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

const _boston =
    CameraPosition(target: LatLng(42.361145, -71.057083), zoom: 10.0);

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final Completer<MapLibreMapController> mapController = Completer();
  bool canInteractWithMap = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation:
          FloatingActionButtonLocation.miniCenterFloat,
      floatingActionButton: canInteractWithMap
          ? FloatingActionButton(
              onPressed: _moveCameraToNullIsland,
              mini: true,
              child: const Icon(Icons.restore),
            )
          : null,
      body: MapLibreMap(
        onMapCreated: (controller) => mapController.complete(controller),
        initialCameraPosition: _boston,
        onStyleLoadedCallback: () => setState(() => canInteractWithMap = true),
        styleString: "assets/pmtiles_style.json",
      ),
    );
  }

  void _moveCameraToNullIsland() => mapController.future
      .then((c) => c.animateCamera(CameraUpdate.newCameraPosition(_boston)));

  // late MapLibreMapController mapController;
  //
  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     body: MapLibreMap(
  //       styleString: "https://demotiles.maplibre.org/style.json",
  //       initialCameraPosition: const CameraPosition(
  //         target: LatLng(51.509364, -0.128928), // London coordinates
  //         zoom: 9.2,
  //       ),
  //       onMapCreated: _onMapCreated,
  //     ),
  //   );
  // }
  //
  // void _onMapCreated(MapLibreMapController controller) {
  //   mapController = controller;
  //   // You can perform further map setup here if needed
  // }
}
