import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lib5/util.dart';
import 'package:luogo/cubit/map/group_sheet/group_sheet_state.dart';
import 'package:luogo/model/group_info.dart';
import 'package:luogo/model/group_settings.dart';
import 'package:luogo/model/hive_latlng.dart';
import 'package:luogo/model/user_state.dart';
import 'package:luogo/services/location_service.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s5_messenger/s5_messenger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Cubit class for managing the group sheet UI state.
///
/// Example usage:
/// ```dart
/// BlocProvider(
///   create: (context) => GroupSheetCubit(
///     s5messenger: yourS5MessengerInstance,
///     groupInfo: yourGroupInfoInstance,
///     prefs: yourSharedPreferencesInstance,
///     locationService: yourLocationServiceInstance,
///   ),
///   child: YourGroupSheetWidget(),
/// )
/// ```
class GroupSheetCubit extends Cubit<GroupSheetState> {
  S5Messenger s5messenger;
  GroupInfo groupInfo;
  SharedPreferencesWithCache prefs;
  LocationService locationService;
  late bool shareLocation;
  GroupSheetCubit(
      {required this.s5messenger,
      required this.groupInfo,
      required this.prefs,
      required this.locationService})
      : super(GroupSheetInitial()) {
    shareLocation = GroupSettings.load(groupInfo.id, prefs).shareLocation;
  }

  // Shows the screen that scans the other user's ID and generates a QR code
  // for them to scan back.
  void showInviteUserScreen(BuildContext context) {
    emit(GroupSheetInviteDialogPressed());
  }

  // When the share location switch is hit, gotta update the UI, then push it to the backend.
  void clickShareLocationSwitch(bool newState) async {
    shareLocation = newState;
    emit(GroupSheetShareLocationUpdated());
    GroupSettings groupSettings = GroupSettings.load(groupInfo.id, prefs);
    groupSettings.shareLocation = newState;
    await GroupSettings.save(prefs, groupSettings);
  }

  // Pass in the signed key and get back information about the user to draw
  UserState? userStateFromSigkey(Uint8List sigkey) {
    final String memberID = base64UrlNoPaddingEncode(sigkey);
    final String? yourID = (s5messenger.dataBox.get('identity_default')
        as Map<dynamic, dynamic>)['publicKey'];
    final String? yourName = prefs.getString("name");
    final int? yourColor = prefs.getInt("color");
    // If you are the user, return that
    if (yourID == memberID) {
      final UserState toReturnUserState = UserState(
        coords: HiveLatLng.fromLatLng(LatLng(0, 0)),
        ts: DateTime.now().millisecondsSinceEpoch,
        name: "${yourName ?? ""} (you)",
        color: yourColor ?? 0,
      );
      return toReturnUserState;
      // Else return their name from the box
    } else {
      final UserState? userState = locationService.userStateBox.get(memberID);
      return userState;
    }
  }

  // sends the user location just that once without enableing live location
  void sendLocationOneshot() {
    locationService.pingPeers();
    emit(GroupSheetShareLocationOneShot());
  }
}
