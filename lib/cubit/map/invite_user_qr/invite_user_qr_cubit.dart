import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/map/invite_user_qr/invite_user_qr_state.dart';
import 'package:luogo/model/group_info.dart';
import 'package:luogo/services/group_crypto.dart';
import 'package:luogo/services/relay_client.dart';

/// A Cubit class for managing the invite user QR state.
///
/// This cubit handles QR code processing for user invitations.
///
/// Example usage:
/// ```dart
/// BlocProvider(
///   create: (context) => InviteUserQrCubit(
///     relayClient: yourRelayClientInstance,
///     groupCrypto: yourGroupCryptoInstance,
///     groupInfo: yourGroupInfoInstance,
///   ),
///   child: YourInviteUserQrWidget(),
/// )
/// ```
class InviteUserQrCubit extends Cubit<InviteUserQrState> {
  RelayClient relayClient;
  GroupCrypto groupCrypto;
  GroupInfo groupInfo;
  InviteUserQrCubit({
    required this.relayClient,
    required this.groupCrypto,
    required this.groupInfo,
  }) : super(InviteUserQrInitial()) {
    _populateQrCode();
  }
  String invitePayload = "";
  final TextEditingController textController = TextEditingController();

  void _populateQrCode() async {
    final String inviteToken =
        await relayClient.createInvite(groupInfo.id);
    final Uint8List groupKey = await groupCrypto.keyFor(groupInfo.id);
    invitePayload = GroupCrypto.buildInvitePayload(
      groupId: groupInfo.id,
      inviteToken: inviteToken,
      groupKey: groupKey,
    );
    emit(InviteUserQrInviteCreated());
  }
}
