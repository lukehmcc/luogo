import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/key_pair_qr/keypair_qr_cubit.dart';
import 'package:luogo/cubit/map_overlay/map_overlay_cubit.dart';
import 'package:luogo/cubit/map_overlay/map_overlay_state.dart';
import 'package:luogo/model/group_info.dart';
import 'package:luogo/view/page/map/keypair_qr_read_write_dialog.dart';
import 'package:s5_messenger/s5_messenger.dart';

/// Provides the MapOverlay that users can interact with once a group is selected
class MapOverlay extends StatelessWidget {
  final GroupInfo? groupInfo;
  final S5Messenger s5messenger;
  const MapOverlay(
      {super.key, required this.groupInfo, required this.s5messenger});

  @override
  Widget build(BuildContext context) {
    // If groupInfo present, do the overlay for group
    if (groupInfo != null) {
      return BlocListener<MapOverlayCubit, MapOverlayState>(
          listener: (BuildContext context, MapOverlayState mapOverlayState) {
            if (mapOverlayState is MapOverlayQRPopupPressed) {
              // Shows dialog for the QR button so user can scan
              showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return BlocProvider<KeypairQRCubit>(
                      create: (BuildContext context) => KeypairQRCubit(),
                      child: KeypairQrReadWriteDialog(
                          keypair: mapOverlayState.keypair),
                    );
                  });
            }
            if (mapOverlayState is MapOverlayGroupPopupPressed) {
              // Shows dialog for group so user can see group info
              showModalBottomSheet<dynamic>(
                context: context,
                builder: (BuildContext context) => Column(
                  children: [
                    Text(groupInfo!.name,
                        style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w700)),
                    Text("Members:"),
                    StreamBuilder<void>(
                      stream: s5messenger
                          .group(groupInfo!.id)
                          .membersStateNotifier
                          .stream,
                      builder: (context, snapshot) {
                        return ListView(
                          children: [
                            for (final member
                                in s5messenger.group(groupInfo!.id).members)
                              ListTile(
                                title: Text(utf8.decode(member.identity)),
                              )
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
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
                      child: Text(groupInfo!.name),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 0, horizontal: 25),
                      child: Column(
                        children: [
                          FloatingActionButton(
                            child: const Icon(Icons.group),
                            onPressed: () {
                              BlocProvider.of<MapOverlayCubit>(context)
                                  .groupButtonPressed();
                            },
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
    } else {
      return BlocListener<MapOverlayCubit, MapOverlayState>(
        listener: (BuildContext context, MapOverlayState mapOverlayState) {
          if (mapOverlayState is MapOverlayQRPopupPressed) {
            // Shows dialog for the QR button so user can scan
            showDialog(
                context: context,
                builder: (BuildContext context) {
                  return BlocProvider<KeypairQRCubit>(
                    create: (BuildContext context) => KeypairQRCubit(),
                    child: KeypairQrReadWriteDialog(
                        keypair: mapOverlayState.keypair),
                  );
                });
          }
        },
        child: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 0, horizontal: 25),
                    child: Column(
                      children: [
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
        ),
      );
    }
  }
}
