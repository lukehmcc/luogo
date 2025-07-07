import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/map/key_pair_qr/keypair_qr_cubit.dart';
import 'package:luogo/cubit/map/key_pair_qr/keypair_qr_state.dart';
import 'package:luogo/main.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

class KeypairQrReadWriteDialog extends StatelessWidget {
  final String keypair;
  const KeypairQrReadWriteDialog({super.key, required this.keypair});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
      // TODO put a user's logo and color inside the QR code
      content: BlocBuilder<KeypairQRCubit, KeypairQRState>(
        builder: (BuildContext context, KeypairQRState keypairQRState) {
          final KeypairQRCubit kpCubit =
              BlocProvider.of<KeypairQRCubit>(context);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                  child: ToggleButtons(
                isSelected: [kpCubit.isQRSelected, !kpCubit.isQRSelected],
                onPressed: (int index) => kpCubit.setQRSelected(index == 0),
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
              )),
              SizedBox(
                height: 10,
              ),
              if (kpCubit.isQRSelected)
                SizedBox(
                  width: MediaQuery.of(context).size.width * .7,
                  height: MediaQuery.of(context).size.width * .7,
                  child: PrettyQrView.data(data: keypair),
                ),
              // TODO make the scanner pipe to somewhere
              if (!kpCubit.isQRSelected)
                SizedBox(
                  width: MediaQuery.of(context).size.width * .7,
                  height: MediaQuery.of(context).size.width * .7,
                  child: MobileScanner(
                    onDetect: (result) {
                      logger.d(result.barcodes.first.rawValue ?? "No QR code");
                    },
                  ),
                ),
            ],
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
    );
  }
}
