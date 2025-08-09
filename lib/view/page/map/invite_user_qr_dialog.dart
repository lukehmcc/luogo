import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/map/invite_user_qr/invite_user_qr_cubit.dart';
import 'package:luogo/cubit/map/invite_user_qr/invite_user_qr_state.dart';
import 'package:luogo/main.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
              const Text("ID Scanner"),
              Tooltip(
                message:
                    "Scan another user's ID to generate an invite token (which they can then scan).",
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
              if (inviteUserQrCubit.welcomeMsg != null)
                Column(
                  children: [
                    Container(
                      color: Colors.purple.shade50,
                      width: MediaQuery.of(context).size.width * .7,
                      height: MediaQuery.of(context).size.width * .7,
                      child: QrImageView(
                        data: inviteUserQrCubit.welcomeMsg!,
                      ),
                    ),
                    ElevatedButton(
                        onPressed: () => Clipboard.setData(
                              ClipboardData(
                                text: inviteUserQrCubit.welcomeMsg!,
                              ),
                            ),
                        child: Text("Copy Invite")),
                  ],
                ),
              if (inviteUserQrCubit.welcomeMsg == null)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width * .7,
                      height: MediaQuery.of(context).size.width * .7,
                      child: MobileScanner(
                        onDetect: (result) async {
                          logger.d(
                              "Scanned: ${result.barcodes.first.rawValue ?? "No value"}");
                          if (result.barcodes.first.rawValue != null) {
                            try {
                              await inviteUserQrCubit.processQRData(
                                  result.barcodes.first.rawValue!);
                            } catch (e) {
                              logger.e(e);
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Or enter code manually',
                              ),
                              controller: inviteUserQrCubit
                                  .textController, // Declare this in your state
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () async {
                              if (inviteUserQrCubit
                                  .textController.text.isNotEmpty) {
                                try {
                                  await inviteUserQrCubit.processQRData(
                                      inviteUserQrCubit.textController.text);
                                } catch (e) {
                                  inviteUserQrCubit.textController.clear();
                                  logger.e(e);
                                }
                              }
                            },
                            child: const Text('Submit'),
                          ),
                        ],
                      ),
                    ),
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
