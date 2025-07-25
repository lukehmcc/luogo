import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/groups_drawer/groups_drawer_state.dart';
import 'package:luogo/main.dart';
import 'package:luogo/model/group_info.dart';
import 'package:luogo/services/location_service.dart';
import 'package:s5_messenger/s5_messenger.dart';

/// A Cubit class for managing the state of the groups drawer.
///
/// Example usage:
/// ```dart
/// BlocProvider(
///   create: (context) => GroupsDrawerCubit(),
///   child: YourGroupsDrawerWidget(),
/// )
/// ```
class GroupsDrawerCubit extends Cubit<GroupsDrawerState> {
  S5Messenger? s5messenger; // mutable so can load async
  LocationService locationService;

  GroupsDrawerCubit({
    required this.locationService,
  }) : super(GroupsDrawerInitial());

  String? currentGroupID;

  Future<void> setS5Messenger(S5Messenger s5messengerIn) async {
    s5messenger = s5messengerIn;
    emit(GroupsDrawerLoading());
    loadGroups();
  }

  Future<void> loadGroups() async {
    if (s5messenger == null) return;
    emit(GroupsDrawerLoading());
    try {
      final GroupInfoList groups =
          GroupInfo.fromJsonList(s5messenger!.groupsBox.values.toList());
      final GroupInfo? currentGroup =
          groups.findByID(s5messenger!.messengerState.groupId ?? "");
      emit(GroupsDrawerLoaded(groups, currentGroup));
    } catch (e) {
      logger.e(e);
      emit(GroupsDrawerError(e.toString()));
    }
  }

  Future<void> createGroup() async {
    if (s5messenger == null) return;
    try {
      GroupState newGroup = await s5messenger!.createNewGroup();
      loadGroups(); // Refresh the list
      // Then add listener
      locationService.setupListenToPeer(newGroup);
    } catch (e) {
      emit(GroupsDrawerError(e.toString()));
    }
  }

  Future<void> selectGroup(String groupId) async {
    if (s5messenger == null || currentGroupID == groupId) return;
    try {
      s5messenger!.messengerState.groupId = groupId;
      s5messenger!.messengerState.update();
      final GroupInfoList groups =
          GroupInfo.fromJsonList(s5messenger!.groupsBox.values.toList());
      final GroupInfo? group = groups.findByID(groupId);
      emit(GroupsDrawerLoaded(groups, group)); // Use same state
    } catch (e) {
      emit(GroupsDrawerError(e.toString()));
    }
  }

  Future<void> renameGroup(String groupId, String newName) async {
    if (s5messenger == null) return;
    try {
      s5messenger!.group(groupId).rename(newName);
      loadGroups(); // Refresh the list
    } catch (e) {
      emit(GroupsDrawerError(e.toString()));
    }
  }
}
