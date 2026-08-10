import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/map/map_overlay/map_overlay_state.dart';
import 'package:luogo/main.dart';
import 'package:luogo/model/group_info.dart';
import 'package:luogo/model/user_state.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/services/relay_client.dart';
import 'package:luogo/utils/mapping.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// A Cubit class for managing the map overlay state.
///
/// Handles group selection to update and display user pins on the map, and
/// real-time listening to location updates for dynamic symbol management.
class MapOverlayCubit extends Cubit<MapOverlayState> {
  GroupInfo? selectedGroup;
  RelayClient relayClient;
  LocationService locationService;
  Completer<MapLibreMapController> mapController;
  Map<String, String> symbolIDMap;
  MapOverlayCubit({
    required this.selectedGroup,
    required this.relayClient,
    required this.locationService,
    required this.mapController,
    required this.symbolIDMap,
  }) : super(MapOverlayInitial()) {
    logger.d("initalized group ${selectedGroup?.name}");
  }

  final Map<String, StreamSubscription<dynamic>> _activeListeners = {};
  final Map<String, Symbol> _activeSymbols = {};

  // Opens the QR invite scanner so the user can join a group
  void qrButtonPressed() {
    emit(MapOverlayScannerPopupPressed());
  }

  // Function that repeatedly tries to populate pins until the length is correct
  // used when creating new rooms
  Future<void> ensureSufficientPinsPopulated(GroupInfo groupInfo) async {
    // Give up after ~30s so an offline first run can't spin forever.
    for (int attempt = 0; attempt < 30; attempt++) {
      List<RelayMember> members;
      try {
        members = await relayClient.fetchMembers(groupInfo.id);
      } catch (e) {
        members = [];
      }
      final int groupMembersCount = members.length;
      final int symbolCount =
          _activeSymbols.length + 1; // + 1 because local user isn't counted
      if (groupMembersCount == symbolCount) {
        return; // exit loop once good
      }
      // If they mismatch, check to make sure all users have an entry,
      // it's not worth doing if they don't
      // Make sure the groupMembersCount isn't empty
      if (groupMembersCount == 0) {
        logger.d("Group is empty, waiting for members...");
        await Future.delayed(Duration(seconds: 1));
        continue;
      }
      bool allMembersPopulated = true;

      for (final RelayMember member in members) {
        final String memberID = member.id;
        if (memberID == locationService.myID) {
          continue; // skip if self, no need to waste a loop
        }

        // First gotta add the initial symbols
        final UserState? userState =
            locationService.userStateBox.get(memberID);
        if (userState == null) {
          allMembersPopulated = false;
          break; // if one is null, no need to check the rest this iteration
        }
      }
      if (allMembersPopulated) {
        groupSelectedEngagePins(groupInfo);
        return; // exit loop once engaged
      }
      await Future.delayed(Duration(seconds: 1));
    }
    logger.d("Gave up waiting for group members to populate");
  }

  // When a group is selected, put their pins on the map
  void groupSelectedEngagePins(GroupInfo groupInfo) async {
    logger.d("engaging pins");
    final controller = await mapController.future;
    // Fetch members BEFORE touching the map: if the relay is unreachable
    // keep the last-known pins on screen instead of wiping them all.
    final List<RelayMember> members;
    try {
      members = await relayClient.fetchMembers(groupInfo.id);
    } catch (e) {
      logger.e("Failed to fetch members: $e");
      return;
    }
    // Nuke all the old listeners & symbols
    for (final Symbol symbol in _activeSymbols.values) {
      logger.d("Removing symbol ${symbol.id}");
      await controller.removeSymbol(symbol);
    }
    _activeSymbols.clear();
    for (final StreamSubscription<dynamic> sub in _activeListeners.values) {
      await sub.cancel();
    }
    _activeListeners.clear();

    // Now add all the new guys back
    for (final RelayMember member in members) {
      final String memberID = member.id;

      // First gotta add the initial symbols
      final UserState? userState = locationService.userStateBox.get(memberID);
      if (userState != null) {
        await addImageFromAsset(
            controller,
            "pin-drop-$memberID",
            "assets/pin.png",
            Color(userState.color),
            (userState.name.isNotEmpty) ? userState.name[0] : "");
        await Future.delayed(Duration(seconds: 1));
        //Now go through and put it on the map
        Symbol userSymbol = await controller.addSymbol(
          SymbolOptions(
            geometry: userState.coords.toLatLng(),
            iconImage: "pin-drop-$memberID",
            iconSize: 1.0,
            iconAnchor: 'bottom',
          ),
        );
        _activeSymbols[memberID] = userSymbol;
        logger.d("Adding symbol ${userSymbol.id}");
        symbolIDMap[userSymbol.id] = memberID;
      }
      // Then add listeners to keep them updated on location updates
      final listener = locationService.userStateBox
          .watch(key: memberID)
          .listen((event) async {
        if (event.value == null) {
          return;
        } else {
          final UserState userState = event.value;
          // If it hasn't been added, add it
          if (_activeSymbols[memberID] == null) {
            await addImageFromAsset(
                controller,
                "pin-drop-$memberID",
                "assets/pin.png",
                Color(userState.color),
                (userState.name.isNotEmpty) ? userState.name[0] : "");
            await Future.delayed(Duration(seconds: 1));
            //Now go through and put it on the map
            Symbol userSymbol = await controller.addSymbol(SymbolOptions(
                geometry: userState.coords.toLatLng(),
                iconImage: "pin-drop-$memberID",
                iconSize: 1.0,
                iconAnchor: 'bottom'));
            _activeSymbols[memberID] = userSymbol;
            symbolIDMap[userSymbol.id] = memberID;
            // If it's not null, update it's location
          } else {
            controller.updateSymbol(_activeSymbols[memberID]!,
                SymbolOptions(geometry: userState.coords.toLatLng()));
          }
        }
      });
      _activeListeners[memberID] = listener;
    }
  }

  void groupButtonPressed() {
    emit(MapOverlayGroupPopupPressed());
  }
}
