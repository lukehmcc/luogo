import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/map/invite_user_qr/invite_user_qr_state.dart';
import 'package:luogo/model/group_info.dart';
import 'package:s5_messenger/s5_messenger.dart';

/// A Cubit class for managing the invite user QR state.
///
/// This cubit handles QR code processing for user invitations.
///
/// Example usage:
/// ```dart
/// BlocProvider(
///   create: (context) => InviteUserQrCubit(
///     s5messenger: yourS5MessengerInstance,
///     groupInfo: yourGroupInfoInstance,
///   ),
///   child: YourInviteUserQrWidget(),
/// )
/// ```
class InviteUserQrCubit extends Cubit<InviteUserQrState> {
  S5Messenger s5messenger;
  GroupInfo groupInfo;
  InviteUserQrCubit({required this.s5messenger, required this.groupInfo})
      : super(InviteUserQrInital()) {
    _populateQrCode();
  }
  String luogoInviteToken = "";
  String? welcomeMsg; // This is the invite token that another user scans
  final TextEditingController textController = TextEditingController();

  void _populateQrCode() async {
    luogoInviteToken =
        "luogo-invite-key: ${(await s5messenger.group(groupInfo.id).generateExternalCommitInvite())}";
    emit(InviteUserQrInviteCreated());
  }
}
