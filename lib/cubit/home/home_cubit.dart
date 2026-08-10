import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/home_state.dart';
import 'package:luogo/model/group_info.dart';
import 'package:s5_messenger/s5_messenger.dart';

/// A Cubit class for managing the home state.
///
/// Example usage:
/// ```dart
/// BlocProvider(
///   create: (context) => HomeCubit(),
///   child: YourHomeWidget(),
/// )
/// ```

class HomeCubit extends Cubit<HomeState> {
  GroupInfo? group;
  S5Messenger? _s5messenger;
  StreamSubscription? _subscription;

  HomeCubit() : super(HomeInitial());

  void setS5Messenger(S5Messenger s5messenger) {
    _s5messenger = s5messenger;
    // When messenger state updates (e.g. rename), refresh the current group info
    _subscription = _s5messenger!.messengerState.stream.listen((_) {
      if (group != null) {
        final groupData = _s5messenger!.groupsBox.get(group!.id);
        if (groupData != null) {
          final updatedGroup = GroupInfo.fromJson({
            'id': group!.id,
            'name': groupData['name'],
          });
          if (updatedGroup.name != group!.name) {
            group = updatedGroup;
            emit(HomeGroupSelected(group));
          }
        }
      }
    });
  }

  void groupSelected(GroupInfo? groupSelected) {
    if (group != groupSelected) {
      group = groupSelected;
      emit(HomeGroupSelected(group));
    }
  }

  void clearSelection() {
    emit(HomeInitial());
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
