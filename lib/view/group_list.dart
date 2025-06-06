import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:lib5/util.dart';
import 'package:flutter/services.dart';
import 'package:s5_messenger_example/main.dart';

class GroupListView extends StatefulWidget {
  const GroupListView({super.key});

  @override
  State<GroupListView> createState() => _GroupListViewState();
}

class _GroupListViewState extends State<GroupListView> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (final group in s5messenger.groupsBox.values)
          ListTile(
            onTap: () {
              s5messenger.messengerState.groupId = group['id'];
              s5messenger.messengerState.update();
            },
            onLongPress: () async {
              final res = await showTextInputDialog(
                context: context,
                textFields: [
                  DialogTextField(hintText: 'Edit Group Name (local)'),
                ],
              );
              if (res == null) return;
              s5messenger.group(group['id']).rename(res.first);
            },
            title: Text(group['name']),
            subtitle: Text(group['id']),
            enabled: s5messenger.groups.isNotEmpty,
            selected: s5messenger.messengerState.groupId == group['id'],
            selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
          ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final res = await showTextInputDialog(
                    context: context,
                    textFields: [
                      DialogTextField(hintText: 's5messenger-group-invite:')
                    ],
                  );
                  if (res == null) return;
                  final String welcome = res.first;
                  if (!welcome.startsWith('s5messenger-group-invite:')) throw 'TODO1';

                  final groupId = await s5messenger.acceptInviteAndJoinGroup(
                    base64UrlNoPaddingDecode(
                      welcome.substring(18),
                    ),
                  );
                  s5messenger.messengerState.groupId = groupId;
                  s5messenger.messengerState.update();
                },
                child: Text(
                  'Join Group',
                ),
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  await s5messenger.createNewGroup();
                  setState(() {});
                },
                child: Text(
                  'Create Group',
                ),
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final kp = await s5messenger.createKeyPackage();

                  Clipboard.setData(
                    ClipboardData(
                      text: 's5messenger-key-package:${base64UrlNoPaddingEncode(kp)}',
                    ),
                  );
                },
                child: Text(
                  'Copy KeyPackage',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
