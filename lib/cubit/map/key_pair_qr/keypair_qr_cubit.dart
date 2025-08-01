import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lib5/util.dart';
import 'package:luogo/cubit/map/key_pair_qr/keypair_qr_state.dart';
import 'package:luogo/main.dart';
import 'package:luogo/model/group_info.dart';
import 'package:luogo/model/message_embed.dart';
import 'package:luogo/services/location_service.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s5_messenger/s5_messenger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// A Cubit class for managing the keypair QR state.
///
/// Example usage:
/// ```dart
/// BlocProvider(
///   create: (context) => KeypairQRCubit(
///     s5messenger: yourS5MessengerInstance,
///     locationService: yourLocationServiceInstance,
///   ),
///   child: YourKeypairQRWidget(),
/// )
/// ```
class KeypairQRCubit extends Cubit<KeypairQRState> {
  final S5Messenger s5messenger;
  final LocationService locationService;
  final SharedPreferencesWithCache prefs;
  KeypairQRCubit({
    required this.s5messenger,
    required this.locationService,
    required this.prefs,
  }) : super(KeypairQRInitial());

  bool isQRSelected = true;
  TextEditingController textController = TextEditingController();

  void setQRSelected(bool selected) {
    isQRSelected = selected;
    emit(KeypairQSelection(isQRSelected: isQRSelected));
  }

  // Once the welcome message has been generated on the other client you
  // can then scan it to join the group.
  Future<void> handleQRWelcomeMessage(String welcomeMessage) async {
    log(welcomeMessage);

    if (!welcomeMessage.startsWith('s5messenger-group-invite:')) {
      throw 'Incorrect group invite';
    }

    String myID = (s5messenger.dataBox.get('identity_default')
        as Map<dynamic, dynamic>)['publicKey'];

    // Grab the locaiton and encode it to bytes
    final LatLng? loc =
        locationService.locationBox.get('local_position')?.toLatLng();
    final Uint8List? messageEmbedBytes = (loc != null)
        ? MessageEmbed.fromPrefs(loc, prefs, null).toMsgpack()
        : null;

    // Accept the invite and send along the location so the other person knows
    // where you are immediately
    final groupId = await s5messenger.acceptInviteAndJoinGroup(
      base64UrlNoPaddingDecode(
        welcomeMessage.substring(25),
      ),
      myID,
      Uuid().v4(),
      messageEmbedBytes,
    );

    // Now make sure to set the group and update UI
    try {
      s5messenger.messengerState.groupId = groupId;
      s5messenger.messengerState.update();
      final GroupInfoList groups =
          GroupInfo.fromJsonList(s5messenger.groupsBox.values.toList());
      final GroupInfo? group = groups.findByID(groupId);
      emit(KeyPairQrGroupLoaded(groups, group)); // Use same state
    } catch (e) {
      logger.e(e);
      emit(KeyPairQrGroupError(e.toString()));
    }

    // refresh the pins now that a new member is added
    locationService.setupListenToPeer(s5messenger.group(groupId));
  }
}
