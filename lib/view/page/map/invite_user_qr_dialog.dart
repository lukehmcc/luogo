import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/map/invite_user_qr/invite_user_qr_cubit.dart';
import 'package:luogo/cubit/map/invite_user_qr/invite_user_qr_state.dart';
import 'package:qr_flutter/qr_flutter.dart';

class InviteUserQrDialog extends StatelessWidget {
  // Explicityly defined here because popups have different context
  const InviteUserQrDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InviteUserQrCubit, InviteUserQrState>(
        builder: (BuildContext content, InviteUserQrState state) {
      final InviteUserQrCubit inviteUserQrCubit =
          BlocProvider.of<InviteUserQrCubit>(context);
      return AlertDialog(
        title: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Invite Code"),
              Tooltip(
                message: "Scan this code on another device to pair.",
                triggerMode: TooltipTriggerMode.tap,
                child: IconButton(
                  icon: Icon(Icons.help_outline),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                children: [
                  Container(
                    color: Colors.purple.shade50,
                    width: MediaQuery.of(context).size.width * .7,
                    height: MediaQuery.of(context).size.width * .7,
                    child: QrImageView(
                      data: inviteUserQrCubit.luogoInviteToken,
                    ),
                  ),
                  ElevatedButton(
                      onPressed: () => Clipboard.setData(
                            ClipboardData(
                              text: inviteUserQrCubit.luogoInviteToken,
                            ),
                          ),
                      child: Text("Copy Invite")),
                ],
              ),
            ],
          ),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close"),
            ),
          )
        ],
      );
    });
  }
}
