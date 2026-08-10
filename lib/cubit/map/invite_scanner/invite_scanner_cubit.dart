import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/map/invite_scanner/invite_scanner_state.dart';
import 'package:luogo/main.dart';
import 'package:luogo/model/group_info.dart';
import 'package:luogo/services/group_crypto.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/services/relay_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Cubit class for managing the invite scanner state.
///
/// Scans (or pastes) a `luogo-invite-key:` payload and joins the group it
/// describes, storing the group key so messages can be decrypted.
///
/// Example usage:
/// ```dart
/// BlocProvider(
///   create: (context) => InviteScannerCubit(
///     relayClient: yourRelayClientInstance,
///     groupCrypto: yourGroupCryptoInstance,
///     locationService: yourLocationServiceInstance,
///     prefs: yourSharedPreferencesInstance,
///   ),
///   child: YourInviteScannerWidget(),
/// )
/// ```
class InviteScannerCubit extends Cubit<InviteScannerState> {
  final RelayClient relayClient;
  final GroupCrypto groupCrypto;
  final LocationService locationService;
  final SharedPreferencesWithCache prefs;
  InviteScannerCubit({
    required this.relayClient,
    required this.groupCrypto,
    required this.locationService,
    required this.prefs,
  }) : super(InviteScannerInitial());

  TextEditingController textController = TextEditingController();

  // Once the invite has been scanned on this client you can then join the group.
  Future<void> handleInvitePayload(String welcomeMessage) async {
    log(welcomeMessage);

    // Parse the invite payload: groupId, inviteToken, and groupKey
    final parsed = GroupCrypto.parseInvitePayload(welcomeMessage);
    if (parsed == null) {
      emit(InviteScannerGroupError('Incorrect group invite'));
      return;
    }

    try {
      // Store the group key so we can decrypt messages in this group
      await groupCrypto.storeKey(parsed.groupId, parsed.groupKey);

      // Accept the invite to join the group
      final RelayGroup group = await relayClient.joinGroup(
        parsed.groupId,
        parsed.inviteToken,
      );

      // Now make sure to set the group and update UI
      final GroupInfo groupInfo =
          GroupInfo(id: group.id, name: group.name);
      final GroupInfoList groups = GroupInfoList(groups: [groupInfo]);
      emit(InviteScannerGroupLoaded(groups, groupInfo));

      // Send our location so the inviter can see where we are immediately
      locationService.pingPeers();
    } catch (e) {
      logger.e(e);
      emit(InviteScannerGroupError(e.toString()));
    }
  }
}
