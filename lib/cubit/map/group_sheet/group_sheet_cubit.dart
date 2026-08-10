import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/map/group_sheet/group_sheet_state.dart';
import 'package:luogo/main.dart';
import 'package:luogo/model/group_info.dart';
import 'package:luogo/model/group_settings.dart';
import 'package:luogo/model/hive_latlng.dart';
import 'package:luogo/model/user_state.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/services/relay_client.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Cubit class for managing the group sheet UI state.
///
/// Example usage:
/// ```dart
/// BlocProvider(
///   create: (context) => GroupSheetCubit(
///     relayClient: yourRelayClientInstance,
///     groupInfo: yourGroupInfoInstance,
///     prefs: yourSharedPreferencesInstance,
///     locationService: yourLocationServiceInstance,
///   ),
///   child: YourGroupSheetWidget(),
/// )
/// ```
class GroupSheetCubit extends Cubit<GroupSheetState> {
  RelayClient relayClient;
  GroupInfo groupInfo;
  SharedPreferencesWithCache prefs;
  LocationService locationService;
  late bool shareLocation;
  late final Stream<List<RelayMember>> membersStream;
  GroupSheetCubit(
      {required this.relayClient,
      required this.groupInfo,
      required this.prefs,
      required this.locationService})
      : super(GroupSheetInitial()) {
    shareLocation = GroupSettings.load(groupInfo.id, prefs).shareLocation;
    membersStream = _pollMembers();
  }

  // Polls members so the sheet stays in sync with joins/leaves.
  Stream<List<RelayMember>> _pollMembers() async* {
    while (true) {
      try {
        yield await relayClient.fetchMembers(groupInfo.id);
      } catch (e) {
        yield const [];
      }
      await Future.delayed(const Duration(seconds: 5));
    }
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

  // Whether the current user can remove members (only the group owner can).
  bool get isOwner {
    for (final RelayGroup group in relayClient.groups) {
      if (group.id == groupInfo.id) {
        return group.ownerId == relayClient.userId;
      }
    }
    return false;
  }

  // Owner-only kick. Returns true on success; the member list refreshes
  // within the next poll cycle.
  Future<bool> removeMember(RelayMember member) async {
    try {
      await relayClient.removeMember(groupInfo.id, member.id);
      return true;
    } catch (e) {
      logger.e("Failed to remove member: $e");
      return false;
    }
  }

  // Pass in the member id and get back information about the user to draw
  UserState? userStateFromId(String memberID) {
    final String yourID = relayClient.userId;
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
      if (userState != null) {
        return userState;
      }
      // Fallback for members we've never heard from (fresh join or relay
      // offline): show the last-known profile from the cached member list
      // instead of an empty row.
      for (final RelayMember member
          in relayClient.cachedMembers(groupInfo.id)) {
        if (member.id == memberID) {
          return UserState(
            coords: HiveLatLng.fromLatLng(LatLng(0, 0)),
            ts: DateTime.now().millisecondsSinceEpoch,
            name: member.name,
            color: member.color,
          );
        }
      }
      return null;
    }
  }

  // sends the user location just that once without enableing live location
  void sendLocationOneshot() {
    locationService.pingPeers();
    emit(GroupSheetShareLocationOneShot());
  }

  // Simmilar to [ensureSufficientPinsPopulated] it recursively checks for new members until they
  // exist to update the UI.
  Future<void> ensureAllMembersLoaded() async {
    while (true) {
      final List<RelayMember> members;
      try {
        members = await relayClient.fetchMembers(groupInfo.id);
      } catch (e) {
        logger.d("Failed to fetch members: $e");
        return;
      }
      logger.d("trying again to load all members");
      bool areAllPopulated = true;
      for (final RelayMember member in members) {
        final String memberID = member.id;
        if (memberID == locationService.myID) {
          continue; // skip if self, no need to check
        }
        final UserState? userState = locationService.userStateBox.get(memberID);
        if (userState == null) {
          areAllPopulated = false;
          break; // no need to check others if one is false
        }
      }
      // If all are populated emit to rebuild UI with new user.
      if (areAllPopulated == true) {
        logger.d("all members loaded, pushing to UI");
        emit(GroupSheetAllUsersLoaded());
        return; // can safely leave
      }
      await Future.delayed(Duration(seconds: 1));
    }
  }
}
