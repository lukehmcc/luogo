import 'package:flutter/material.dart';
import 'package:s5_messenger_example/main.dart';

import 'group_chat.dart';
import 'group_list.dart';

class MLS5DemoAppView extends StatelessWidget {
  const MLS5DemoAppView({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
            title: const Text(
          'Vup Chat - Decentralized E2EE group chats with MLS and the S5 Network',
        )),
        body: StreamBuilder<void>(
            stream: s5messenger.messengerState.stream,
            builder: (context, snapshot) {
              return Row(
                children: [
                  SizedBox(
                    width: 256,
                    child: GroupListView(),
                  ),
                  if (s5messenger.messengerState.groupId != null) ...[
                    VerticalDivider(
                      width: 1,
                    ),
                    Expanded(
                      child: GroupChatView(
                        s5messenger.messengerState.groupId!,
                      ),
                    )
                  ]
                  /*  Center(
                  child: ElevatedButton(
                    onPressed: mls.test,
                    child: Text('Run'),
                  ),
                ), */
                ],
              );
            }),
      ),
    );
  }
}
