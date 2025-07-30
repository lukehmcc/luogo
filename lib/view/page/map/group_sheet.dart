import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/map/group_sheet/group_sheet_cubit.dart';
import 'package:luogo/cubit/map/group_sheet/group_sheet_state.dart';
import 'package:luogo/cubit/map/invite_user_qr/invite_user_qr_cubit.dart';
import 'package:luogo/main.dart';
import 'package:luogo/model/group_info.dart';
import 'package:luogo/model/user_state.dart';
import 'package:luogo/view/page/map/invite_user_qr_dialog.dart';
import 'package:luogo/view/widgets/circle_avatar_styled_named.dart';
import 'package:s5_messenger/s5_messenger.dart';

/// Displays a group information sheet with member list and controls.
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
          GroupSheetCubit groupSheetCubit = context.read<GroupSheetCubit>();
          showDialog<dynamic>(
              context: context,
              builder: (BuildContext context) {
                return BlocProvider(
                  create: (BuildContext context) => InviteUserQrCubit(
                      s5messenger: s5messenger, groupInfo: groupInfo),
                  child: InviteUserQrDialog(),
                );
              }).then((_) {
            logger.d("ensuring all members loaded");
            groupSheetCubit.ensureAllMembersLoaded();
          });
        }
        if (groupSheetState is GroupSheetShareLocationOneShot) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Send location to peers'),
            ),
          );
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ElevatedButton(
                      onPressed: () =>
                          groupSheetCubit.showInviteUserScreen(context),
                      child: Text("Invite User")),
                  SizedBox(
                    width: 10,
                  ),
                  ElevatedButton(
                      onPressed: groupSheetCubit.sendLocationOneshot,
                      child: Text("Send Location (once)")),
                ],
              ),
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
                  if (s5messenger.group(groupInfo.id).members.isEmpty) {
                    return Center(
                      child: Text("No that isn't right..."),
                    );
                  }
                  return ListView(
                    children: s5messenger
                        .group(groupInfo.id)
                        .members
                        .map<Widget>((GroupMember member) {
                      // define this first because will be used multiple times
                      final UserState? userState =
                          BlocProvider.of<GroupSheetCubit>(context)
                              .userStateFromSigkey(member.signatureKey);
                      if (userState == null) {
                        return Container();
                      }
                      return ListTile(
                        leading: CircleAvatarStyledNamed(
                          name: userState.name,
                          color: Color(userState.color),
                        ),
                        title: Text(
                          userState.name,
                        ),
                      );
                    }).toList(),
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
