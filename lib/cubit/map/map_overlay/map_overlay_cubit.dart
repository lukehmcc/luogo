import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lib5/util.dart';
import 'package:luogo/cubit/map/map_overlay/map_overlay_state.dart';
import 'package:luogo/main.dart';
import 'package:luogo/model/group_info.dart';
import 'package:luogo/model/user_state.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/utils/mapping.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s5_messenger/s5_messenger.dart';

class MapOverlayCubit extends Cubit<MapOverlayState> {
  GroupInfo? selectedGroup;
  S5Messenger s5messenger;
  LocationService locationService;
  Completer<MapLibreMapController> mapController;
  MapOverlayCubit({
    required this.selectedGroup,
    required this.s5messenger,
    required this.locationService,
    required this.mapController,
  }) : super(MapOverlayInitial()) {
    logger.d("initalized group ${selectedGroup?.name}");
  }

  final Map<String, StreamSubscription<dynamic>> _activeListeners = {};
  final Map<String, Symbol> _activeSymbols = {};

  // Create keypackage, marshal it, then send it to the UI to make a QR code
  void qrButtonPressed() async {
    final Uint8List keypackage = await s5messenger.createKeyPackage();
    final String message =
        "luogo-user-identity:${base64UrlNoPaddingEncode(keypackage)}";
    logger.d(message);
    emit(MapOverlayQRPopupPressed(keypair: message));
  }

  // When a group is selected, put their pins on the map
  void groupSelectedEngagePins(GroupInfo groupInfo) async {
    // Nuke all the old listeners & symbols
    final controller = await mapController.future;
    logger.d("Nuking previous pins");
    for (final Symbol symbol in _activeSymbols.values) {
      controller.removeSymbol(symbol);
    }
    _activeSymbols.clear();
    for (final StreamSubscription<dynamic> sub in _activeListeners.values) {
      sub.cancel();
    }
    _activeListeners.clear();

    // Now add all the new guys back
    final GroupState groupState = s5messenger.group(groupInfo.id);
    logger.d("now adding pins");
    for (final GroupMember member in groupState.members) {
      final String memberID = base64UrlNoPaddingEncode(member.signatureKey);

      // First gotta add the initial symbols
      final UserState? userState = locationService.userStateBox.get(memberID);
      if (userState != null) {
        logger.d("adding pin $memberID");
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
          iconAnchor: 'bottom',
        ));
        _activeSymbols[memberID] = userSymbol;
      }
      // Then add listeners to keep them updated on locaiton updates
      final listener = locationService.userStateBox
          .watch(key: memberID)
          .listen((event) async {
        if (event.value == null) {
          return;
        } else {
          final UserState userState = event.value;
          // If it hasn't been added, add it
          if (_activeSymbols[memberID] == null) {
            logger.d("adding pin $memberID");
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
