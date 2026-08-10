import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/map/group_sheet/group_sheet_cubit.dart';
import 'package:luogo/cubit/map/group_sheet/group_sheet_state.dart';
import 'package:luogo/cubit/map/invite_user_qr/invite_user_qr_cubit.dart';
import 'package:luogo/main.dart';
import 'package:luogo/model/group_info.dart';
import 'package:luogo/model/user_state.dart';
import 'package:luogo/services/group_crypto.dart';
import 'package:luogo/services/relay_client.dart';
import 'package:luogo/view/page/map/invite_user_qr_dialog.dart';
import 'package:luogo/view/widgets/circle_avatar_styled_named.dart';

/// Displays a group information sheet with member list and controls.
class GroupSheet extends StatelessWidget {
  final GroupInfo groupInfo;
  final RelayClient relayClient;
  final GroupCrypto groupCrypto;

  const GroupSheet({
    super.key,
    required this.groupInfo,
    required this.relayClient,
    required this.groupCrypto,
  });

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
                      relayClient: relayClient,
                      groupCrypto: groupCrypto,
                      groupInfo: groupInfo),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  groupSheetCubit.groupInfo.name,
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
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
                  child: StreamBuilder<List<RelayMember>>(
                stream: groupSheetCubit.membersStream,
                builder: (context, snapshot) {
                  final members = snapshot.data ?? [];
                  if (members.isEmpty) {
                    return Center(
                      child: Text("No that isn't right..."),
                    );
                  }
                  return ListView(
                    children: members.map<Widget>((RelayMember member) {
                      // define this first because will be used multiple times
                      final GroupSheetCubit groupSheetCubit =
                          BlocProvider.of<GroupSheetCubit>(context);
                      final UserState? userState =
                          groupSheetCubit.userStateFromId(member.id);
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
                        trailing: groupSheetCubit.isOwner &&
                                member.id != relayClient.userId
                            ? IconButton(
                                icon: const Icon(Icons.person_remove_outlined),
                                tooltip: "Remove ${userState.name}",
                                onPressed: () => _confirmRemoveMember(
                                    context, groupSheetCubit, member),
                              )
                            : null,
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

  // Owner-only kick with confirmation.
  Future<void> _confirmRemoveMember(BuildContext context,
      GroupSheetCubit cubit, RelayMember member) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text("Remove member"),
        content: Text(
            "Remove ${member.name.isEmpty ? 'this member' : member.name} from the group?\n\n"
            "They'll stop receiving location updates immediately."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final bool success = await cubit.removeMember(member);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? "Member removed" : "Failed to remove member"),
    ));
  }
}
