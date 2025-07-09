import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/map/group_sheet/group_sheet_state.dart';
import 'package:luogo/model/group_info.dart';
import 'package:s5_messenger/s5_messenger.dart';

/// Defines the state for the group sheet
class GroupSheetCubit extends Cubit<GroupSheetState> {
  S5Messenger s5messenger;
  GroupInfo groupInfo;
  GroupSheetCubit({required this.s5messenger, required this.groupInfo})
      : super(GroupSheetInitial());

  // Shows the screen that scans the other user's ID and generates a QR code
  // for them to scan back.
  void showInviteUserScreen(BuildContext context) {
    emit(GroupSheetInviteDialogPressed());
  }
}
