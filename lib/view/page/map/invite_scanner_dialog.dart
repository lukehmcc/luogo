import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/home_cubit.dart';
import 'package:luogo/cubit/map/invite_scanner/invite_scanner_cubit.dart';
import 'package:luogo/cubit/map/invite_scanner/invite_scanner_state.dart';
import 'package:luogo/cubit/map/map_overlay/map_overlay_cubit.dart';
import 'package:luogo/main.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class InviteScannerDialog extends StatelessWidget {
  final HomeCubit homeCubit;
  final MapOverlayCubit mapOverlayCubit;
  const InviteScannerDialog({
    super.key,
    required this.homeCubit,
    required this.mapOverlayCubit,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<InviteScannerCubit, InviteScannerState>(
      // Us a listener here so widget state isn't handled form bloc thread
      listener: (BuildContext context, InviteScannerState inviteScannerState) {
        // Pop once a gorup has been joined
        if (inviteScannerState is InviteScannerGroupLoaded) {
          if (inviteScannerState.group != null) {
            homeCubit.groupSelected(inviteScannerState.group!);
            mapOverlayCubit
                .ensureSufficientPinsPopulated(inviteScannerState.group!);
          }
          logger.d("Group loaded and popping context back to overlay");
          Navigator.pop(context);
        }
        if (inviteScannerState is InviteScannerGroupError) {
          Navigator.pop(context);
          logger.d("Group error and popping context back to overlay");
        }
      },
      child: AlertDialog(
        title: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Invite Scanner"),
              Tooltip(
                message: "Scan an invite QR to join a group!",
                child: IconButton(
                  icon: Icon(Icons.help_outline),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
        content: BlocBuilder<InviteScannerCubit, InviteScannerState>(
          builder: (BuildContext context, InviteScannerState inviteScannerState) {
            final InviteScannerCubit kpCubit =
                BlocProvider.of<InviteScannerCubit>(context);
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * .7,
                        height: MediaQuery.of(context).size.width * .7,
                        child: MobileScanner(
                          onDetect: (result) {
                            if (result.barcodes.first.rawValue != null) {
                              try {
                                BlocProvider.of<InviteScannerCubit>(context)
                                    .handleInvitePayload(
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
                                  hintText: 'Or enter key manually',
                                ),
                                controller: kpCubit.textController,
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () {
                                if (kpCubit.textController.text.isNotEmpty) {
                                  try {
                                    BlocProvider.of<InviteScannerCubit>(context)
                                        .handleInvitePayload(
                                            kpCubit.textController.text);
                                  } catch (e) {
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
            );
          },
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close"),
            ),
          )
        ],
      ),
    );
  }
}
