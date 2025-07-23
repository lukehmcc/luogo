import 'package:luogo/model/group_info.dart';

abstract class KeypairQRState {}

class KeypairQRInitial extends KeypairQRState {}

class KeypairQSelection extends KeypairQRState {
  final bool isQRSelected;
  KeypairQSelection({required this.isQRSelected});
}

class KeyPairQrGroupLoaded extends KeypairQRState {
  final GroupInfoList groups;
  final GroupInfo? group;
  KeyPairQrGroupLoaded(this.groups, [this.group]);
}

class KeyPairQrGroupError extends KeypairQRState {
  final String message;
  KeyPairQrGroupError(this.message);
}
