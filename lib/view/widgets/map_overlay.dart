import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/map_overlay/map_overlay_cubit.dart';
import 'package:luogo/cubit/map_overlay/map_overlay_state.dart';
import 'package:luogo/model/group_info.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:s5_messenger/s5_messenger.dart';

/// Provides the MapOverlay that users can interact with once a group is selected
class MapOverlay extends StatelessWidget {
  final GroupInfo group;
  final S5Messenger s5messenger;
  const MapOverlay({super.key, required this.group, required this.s5messenger});

  @override
  Widget build(BuildContext context) {
    return BlocListener<MapOverlayCubit, MapOverlayState>(
        listener: (BuildContext context, MapOverlayState mapOverlayState) {
          if (mapOverlayState is MapOverlayQRPopupPressed) {
            showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Your ID"),
                          Tooltip(
                            message:
                                "Another user can scan this QR code to create an invite link/QR code",
                            child: IconButton(
                              icon: Icon(Icons.help_outline),
                              onPressed: () {},
                            ),
                          ),
                        ],
                      ),
                    ),
                    // TODO put a user's logo and color inside the QR code
                    content: PrettyQrView.data(data: mapOverlayState.keypair),
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
        },
        child: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Card(
                  child: Padding(
                    padding: EdgeInsetsGeometry.all(8),
                    child: Text(group.name),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 0, horizontal: 25),
                    child: Column(
                      children: [
                        FloatingActionButton(
                          child: const Icon(Icons.group),
                          onPressed: () {},
                        ),
                        SizedBox(
                          height: 5,
                        ),
                        FloatingActionButton(
                          mini: true,
                          onPressed: () {
                            BlocProvider.of<MapOverlayCubit>(context)
                                .qrButtonPressed();
                          },
                          child: const Icon(Icons.qr_code_rounded),
                        ),
                      ],
                    )),
              ),
            ],
          ),
        ));
  }
}
