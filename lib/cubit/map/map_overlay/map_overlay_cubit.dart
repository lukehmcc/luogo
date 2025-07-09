import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lib5/util.dart';
import 'package:luogo/cubit/map/map_overlay/map_overlay_state.dart';
import 'package:luogo/main.dart';
import 'package:luogo/model/group_info.dart';
import 'package:s5_messenger/s5_messenger.dart';

class MapOverlayCubit extends Cubit<MapOverlayState> {
  GroupInfo? selectedGroup;
  S5Messenger s5messenger;
  MapOverlayCubit({required this.selectedGroup, required this.s5messenger})
      : super(MapOverlayInitial());

  // Create keypackage, marshal it, then send it to the UI to make a QR code
  qrButtonPressed() async {
    final Uint8List keypackage = await s5messenger.createKeyPackage();
    final String message =
        "luogo-user-identity:${base64UrlNoPaddingEncode(keypackage)}";
    logger.d(message);
    emit(MapOverlayQRPopupPressed(keypair: message));
  }

  groupButtonPressed() {
    emit(MapOverlayGroupPopupPressed());
  }
}
