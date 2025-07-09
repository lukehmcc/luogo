import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lib5/util.dart';
import 'package:luogo/cubit/map/invite_user_qr/invite_user_qr_state.dart';
import 'package:luogo/model/group_info.dart';
import 'package:s5_messenger/s5_messenger.dart';

/// Defines the state for the group sheet
class InviteUserQrCubit extends Cubit<InviteUserQrState> {
  S5Messenger s5messenger;
  GroupInfo groupInfo;
  InviteUserQrCubit({required this.s5messenger, required this.groupInfo})
      : super(InviteUserQrInital());

  String? welcomeMsg; // This is the invite token that another user scans
  final TextEditingController textController = TextEditingController();

  // Deal with incoming keypackage
  // make sure to try catch this!
  Future<void> processQRData(String kp) async {
    if (!kp.startsWith('luogo-user-identity:')) {
      throw 'Incorrect keypackage prefix.';
    }

    log(kp);
    final Uint8List bytes = base64UrlNoPaddingDecode(
      kp.substring(20),
    );
    welcomeMsg = await s5messenger.group(groupInfo.id).addMemberToGroup(bytes);

    debugPrint(welcomeMsg);

    Clipboard.setData(
      ClipboardData(
        text: welcomeMsg ?? "",
      ),
    );
    emit(InviteUserQrInviteCreated());
  }
}
