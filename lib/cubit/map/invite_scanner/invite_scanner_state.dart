import 'package:luogo/model/group_info.dart';

abstract class InviteScannerState {}

class InviteScannerInitial extends InviteScannerState {}

class InviteScannerGroupLoaded extends InviteScannerState {
  final GroupInfoList groups;
  final GroupInfo? group;
  InviteScannerGroupLoaded(this.groups, [this.group]);
}

class InviteScannerGroupError extends InviteScannerState {
  final String message;
  InviteScannerGroupError(this.message);
}
