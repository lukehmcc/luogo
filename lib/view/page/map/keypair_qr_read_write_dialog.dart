import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/home_cubit.dart';
import 'package:luogo/cubit/map/key_pair_qr/keypair_qr_cubit.dart';
import 'package:luogo/cubit/map/key_pair_qr/keypair_qr_state.dart';
import 'package:luogo/cubit/map/map_overlay/map_overlay_cubit.dart';
import 'package:luogo/main.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

class KeypairQrReadWriteDialog extends StatelessWidget {
  final String keypair;
  final HomeCubit homeCubit;
  final MapOverlayCubit mapOverlayCubit;
  const KeypairQrReadWriteDialog({
    super.key,
    required this.keypair,
    required this.homeCubit,
    required this.mapOverlayCubit,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<KeypairQRCubit, KeypairQRState>(
      // Us a listener here so widget state isn't handled form bloc thread
      listener: (BuildContext context, KeypairQRState keypairQRState) {
        // Pop once a gorup has been joined
        if (keypairQRState is KeyPairQrGroupLoaded) {
          if (keypairQRState.group != null) {
            homeCubit.groupSelected(keypairQRState.group!);
            mapOverlayCubit
                .ensureSufficientPinsPopulated(keypairQRState.group!);
          }
          logger.d("Group loaded and popping context back to overlay");
          Navigator.pop(context);
        }
        if (keypairQRState is KeyPairQrGroupError) {
          Navigator.pop(context);
          logger.d("Group error and popping context back to overlay");
        }
      },
      child: AlertDialog(
        title: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Your ID Zone"),
              Tooltip(
                message:
                    "Another user can scan this QR code to create an invite link/QR code. Then you can scan their generated QR code to join.",
                child: IconButton(
                  icon: Icon(Icons.help_outline),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
        content: BlocBuilder<KeypairQRCubit, KeypairQRState>(
          builder: (BuildContext context, KeypairQRState keypairQRState) {
            final KeypairQRCubit kpCubit =
                BlocProvider.of<KeypairQRCubit>(context);
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: ToggleButtons(
                      isSelected: [kpCubit.isQRSelected, !kpCubit.isQRSelected],
                      onPressed: (int index) =>
                          kpCubit.setQRSelected(index == 0),
                      borderRadius: BorderRadius.circular(8),
                      children: [
                        SizedBox(
                          width: 100,
                          child: Center(
                            child: Text('QR'),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Center(child: Text('Scanner')),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (kpCubit.isQRSelected)
                    Column(
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width * .7,
                          height: MediaQuery.of(context).size.width * .7,
                          child: QrImageView(data: keypair),
                        ),
                        ElevatedButton(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: keypair),
                          ),
                          child: const Text("Copy Key"),
                        ),
                      ],
                    ),
                  if (!kpCubit.isQRSelected)
                    Column(
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width * .7,
                          height: MediaQuery.of(context).size.width * .7,
                          child: MobileScanner(
                            onDetect: (result) {
                              if (result.barcodes.first.rawValue != null) {
                                try {
                                  BlocProvider.of<KeypairQRCubit>(context)
                                      .handleQRWelcomeMessage(
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
                                      BlocProvider.of<KeypairQRCubit>(context)
                                          .handleQRWelcomeMessage(
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
