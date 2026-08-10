import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/groups_drawer/groups_drawer_state.dart';
import 'package:luogo/main.dart';
import 'package:luogo/model/group_info.dart';
import 'package:luogo/services/group_crypto.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/services/relay_client.dart';

/// A Cubit class for managing the state of the groups drawer.
class GroupsDrawerCubit extends Cubit<GroupsDrawerState> {
  RelayClient? relayClient; // mutable so can load async
  GroupCrypto? crypto;
  LocationService locationService;
  StreamSubscription<RelayEvent>? _subscription;

  GroupsDrawerCubit({
    required this.locationService,
  }) : super(GroupsDrawerInitial());

  String? currentGroupID;

  Future<void> setRelayClient(RelayClient relayClientIn, GroupCrypto cryptoIn) async {
    relayClient = relayClientIn;
    crypto = cryptoIn;
    // Keep the drawer fresh when the relay (re)connects or when other
    // devices rename groups or leave.
    _subscription?.cancel();
    _subscription = relayClientIn.events.listen((event) {
      if (event is RelayHelloEvent) {
        loadGroups();
      } else if (event is RelayMemberEvent &&
          (event.action == 'renamed' || event.action == 'left')) {
        loadGroups();
      }
    });
    await loadGroups();
  }

  Future<void> loadGroups() async {
    if (relayClient == null) return;
    emit(GroupsDrawerLoading());
    try {
      final List<RelayGroup> relayGroups = await relayClient!.fetchGroups();
      final GroupInfoList groups = GroupInfoList(
          groups: relayGroups
              .map((g) => GroupInfo(id: g.id, name: g.name))
              .toList());
      final GroupInfo? currentGroup = groups.findByID(currentGroupID ?? "");
      emit(GroupsDrawerLoaded(groups, currentGroup));
    } catch (e) {
      logger.e(e);
      emit(GroupsDrawerError(e.toString()));
    }
  }

  // Member names for the drawer subtitle, straight from the relay so they
  // are available before the first location message.
  Future<String> getMembersPreview(String groupID) async {
    if (relayClient == null) return "Members: you";
    try {
      final List<RelayMember> members =
          await relayClient!.fetchMembers(groupID);
      final List<String> names = members
          .where((m) => m.id != locationService.myID)
          .map((m) => m.name)
          .where((n) => n.isNotEmpty)
          .toList();
      if (names.isEmpty) return "Members: you";
      return "Members: ${names.join(', ')}";
    } catch (e) {
      logger.e(e);
      return "Members: you";
    }
  }

  Future<GroupInfo?> createGroup(String? groupName) async {
    if (relayClient == null || crypto == null) {
      logger.e("relay is not yet loaded, cannot create group.");
      return null;
    }
    try {
      final RelayGroup relayGroup =
          await relayClient!.createGroup(groupName ?? 'New Group');
      // Pre-generate the group key so invites can be issued instantly.
      await crypto!.keyFor(relayGroup.id);
      await loadGroups();
      return GroupInfo(id: relayGroup.id, name: relayGroup.name);
    } catch (e) {
      emit(GroupsDrawerError(e.toString()));
      return null;
    }
  }

  Future<void> selectGroup(String? groupId) async {
    if (currentGroupID == groupId) return;
    currentGroupID = groupId;
    emit(GroupsDrawerLoaded(
        state is GroupsDrawerLoaded ? (state as GroupsDrawerLoaded).groups : GroupInfoList(groups: []),
        state is GroupsDrawerLoaded ? (state as GroupsDrawerLoaded).group : null));
  }

  Future<void> renameGroup(String groupId, String newName) async {
    if (relayClient == null) return;
    try {
      await relayClient!.renameGroup(groupId, newName);
      await loadGroups();
    } catch (e) {
      emit(GroupsDrawerError(e.toString()));
    }
  }

  Future<void> leaveGroup(String groupID) async {
    if (relayClient == null) return;
    try {
      await relayClient!.leaveGroup(groupID);
      if (currentGroupID == groupID) {
        currentGroupID = null;
      }
      await loadGroups();
    } catch (e) {
      emit(GroupsDrawerError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
