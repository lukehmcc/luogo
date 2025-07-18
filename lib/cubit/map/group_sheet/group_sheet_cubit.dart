import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lib5/util.dart';
import 'package:luogo/cubit/map/group_sheet/group_sheet_state.dart';
import 'package:luogo/main.dart';
import 'package:luogo/model/group_info.dart';
import 'package:luogo/model/group_settings.dart';
import 'package:luogo/model/user_state.dart';
import 'package:luogo/services/location_service.dart';
import 'package:s5_messenger/s5_messenger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Defines the state for the group sheet
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

  String? userNameFromSigkey(Uint8List sigkey) {
    final String memberID = base64UrlNoPaddingEncode(sigkey);
    final UserState? userState = locationService.userStateBox.get(memberID);
    logger.d(userState);
    return userState?.name;
  }
}
