import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/main.dart';
import 'package:luogo/model/hive_latlng.dart';
import 'package:luogo/model/user_state.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/utils/mapping.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:luogo/cubit/map/map_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Cubit class for managing the map state.
///
/// This cubit handles user location tracking, symbol management, and map
/// interactions such as updating camera positions and responding to symbol
/// taps for real-time updates.
///
/// Example usage:
/// ```dart
/// BlocProvider(
///   create: (context) => MapCubit(
///     locationService: yourLocationServiceInstance,
///     prefs: yourSharedPreferencesInstance,
///   ),
///   child: YourMapWidget(),
/// )
/// ```
class MapCubit extends Cubit<MapState> {
  final LocationService locationService;
  final SharedPreferencesWithCache prefs;

  MapCubit({
    required this.locationService,
    required this.prefs,
  }) : super(MapInitial()) {
    // Initialize the position watcher
    locationService.locationBox
        .watch(key: 'local_position')
        .listen((event) async {
      logger.d("istending....");
      // First parse the info
      if (event.value == null) {
        return;
      }
      // First check if the user is centered
      final CameraPosition? cameraPosition =
          (await mapController.future).cameraPosition;
      final double camLat = cameraPosition?.target.latitude ?? 0;
      final double camLong = cameraPosition?.target.longitude ?? 0;
      final double userLat = _userPosition?.latitude ?? 0;
      final double userLong = _userPosition?.longitude ?? 0;
      bool isCentered = (userLat - camLat).abs() < 0.0001 &&
          (userLong - camLong).abs() < 0.0001;

      // Also check if it is the first time a location is being written (always want to center then)
      bool firstGo = _userPosition == null;

      // Then update the user position
      if (event.value != null) {
        _userPosition = event.value.toLatLng();
      }

      // If it's the first go, add the user symbol (it should always be there)
      if (firstGo) {
        _addUserIcon();
      }

      // And if the position hasn't been editied of the camera, move it
      if (isCentered || firstGo) {
        // update the camera position
        updateCamera(event.value.toLatLng());
      }

      // But always move the pin if there's a valid location
      if (_userSymbol != null) {
        // And update the pin location
        final controller = await mapController.future;
        controller.updateSymbol(
            _userSymbol!, SymbolOptions(geometry: _userPosition));
      }
    });
  }

  // Vars
  Completer<MapLibreMapController> mapController = Completer();
  LatLng? _userPosition; // Store position for later use
  Symbol? _userSymbol; // Store local user symbol to be moved
  UserState? _localUserState;
  Map<String, String> symbolIDMap =
      {}; // Defines realtion between symbol & user IDs

  // Getters
  LatLng? get userPosition => _userPosition;

  // Funcitons
  void mapCreated(MapLibreMapController controller) async {
    mapController.complete(controller);
    controller.onSymbolTapped.add(_onSymbolTapped);
    emit(MapReady());
    if (_userPosition != null) {
      await moveToUser(); // Auto-center on user location
    }
  }

  // Callback for the user's location symbol on the map
  // Should ping UI to update UI with a bottom sheet
  void _onSymbolTapped(Symbol symbol) {
    if (_localUserState != null && symbol == _userSymbol) {
      emit(MapSymbolClicked(userState: _localUserState!, isYou: true));
    } else {
      final String userID = symbolIDMap[symbol.id] ?? "";
      final UserState? userState = locationService.userStateBox.get(userID);
      if (userState != null) {
        emit(MapSymbolClicked(userState: userState, isYou: false));
      } else {
        logger.e("user: userID is null");
      }
    }
  }

  // Callback to add the local user's icon to the map
  // Hadnling the local user & other users is seperate because we want
  // this one to load fast before s5messenger can load (which can take a couple seconds)
  void _addUserIcon() async {
    if (_userPosition != null) {
      // Now add personal users
      // First load in the image (and get user prefs)
      String? name = prefs.getString('name');
      int colorValue = prefs.getInt('color') ?? 0;
      _localUserState = UserState(
          coords: HiveLatLng.fromLatLng(userPosition!),
          ts: DateTime.now().millisecondsSinceEpoch,
          name: name ?? "",
          color: colorValue);
      Color selectedColor = Color(colorValue);
      final controller = await mapController.future;
      await addImageFromAsset(controller, "pin-drop", "assets/pin.png",
          selectedColor, name?[0] ?? "");
      await Future.delayed(Duration(seconds: 1));
      //Now go through and put it on the map
      _userSymbol = await controller.addSymbol(SymbolOptions(
          geometry: _userPosition,
          iconImage: "pin-drop",
          iconSize: 1.0,
          iconAnchor: 'bottom'));
      // We don't have to add this user to the map because we store the symbol locally
      // we also can't because s5messenger hasn't necesarily been loaded yet
      logger.d("added image asset");
    }
  }

  Future<void> moveToUser() async {
    logger.d("User location $_userPosition");
    final controller = await mapController.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
              _userPosition?.latitude ?? 0, _userPosition?.longitude ?? 0),
          zoom: 10.0,
        ),
      ),
    );
  }

  Future<void> updateCamera(LatLng position) async {
    final controller = await mapController.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: 10.0,
        ),
      ),
    );
  }
}
