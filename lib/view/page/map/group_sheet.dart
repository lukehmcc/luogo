import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/map/group_sheet/group_sheet_cubit.dart';
import 'package:luogo/cubit/map/group_sheet/group_sheet_state.dart';
import 'package:luogo/cubit/map/invite_user_qr/invite_user_qr_cubit.dart';
import 'package:luogo/model/group_info.dart';
import 'package:luogo/view/page/map/invite_user_qr_dialog.dart';
import 'package:s5_messenger/s5_messenger.dart';

class GroupSheet extends StatelessWidget {
  final GroupInfo groupInfo;
  final S5Messenger s5messenger;

  const GroupSheet(
      {super.key, required this.groupInfo, required this.s5messenger});

  @override
  Widget build(BuildContext context) {
    return BlocListener<GroupSheetCubit, GroupSheetState>(
      listener: (BuildContext context, GroupSheetState groupSheetState) {
        if (groupSheetState is GroupSheetInviteDialogPressed) {
          showDialog<dynamic>(
              context: context,
              builder: (BuildContext context) {
                return BlocProvider(
                  create: (BuildContext context) => InviteUserQrCubit(
                      s5messenger: s5messenger, groupInfo: groupInfo),
                  child: InviteUserQrDialog(),
                );
              });
        }
      },
      child: BlocBuilder<GroupSheetCubit, GroupSheetState>(
        builder: (BuildContext context, GroupSheetState state) {
          GroupSheetCubit groupSheetCubit =
              BlocProvider.of<GroupSheetCubit>(context);
          return Column(
            children: <Widget>[
              Text(groupInfo.name,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
              ElevatedButton(
                  onPressed: () =>
                      groupSheetCubit.showInviteUserScreen(context),
                  child: Text("Invite User")),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text("Share Location: "),
                  SizedBox(
                    width: 20,
                  ),
                  Switch(
                      value: groupSheetCubit.shareLocation,
                      onChanged: (bool updatedState) => groupSheetCubit
                          .clickShareLocationSwitch(updatedState)),
                ],
              ),
              Text("Members:"),
              Expanded(
                  child: StreamBuilder<void>(
                stream:
                    s5messenger.group(groupInfo.id).membersStateNotifier.stream,
                builder: (context, snapshot) {
                  return ListView(
                    children: [
                      for (final member
                          in s5messenger.group(groupInfo.id).members)
                        ListTile(
                          title: Text(BlocProvider.of<GroupSheetCubit>(context)
                                  .userNameFromSigkey(member.signatureKey) ??
                              utf8.decode(member.identity)),
                        )
                    ],
                  );
                },
              )),
            ],
          );
        },
      ),
    );
  }
}
