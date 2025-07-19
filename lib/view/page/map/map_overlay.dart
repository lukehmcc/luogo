import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/home_cubit.dart';
import 'package:luogo/cubit/home/home_state.dart';
import 'package:luogo/cubit/map/group_sheet/group_sheet_cubit.dart';
import 'package:luogo/cubit/map/key_pair_qr/keypair_qr_cubit.dart';
import 'package:luogo/cubit/map/map_overlay/map_overlay_cubit.dart';
import 'package:luogo/cubit/map/map_overlay/map_overlay_state.dart';
import 'package:luogo/model/group_info.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/view/page/map/group_sheet.dart';
import 'package:luogo/view/page/map/keypair_qr_read_write_dialog.dart';
import 'package:s5_messenger/s5_messenger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides the MapOverlay that users can interact with once a group is selected
class MapOverlay extends StatelessWidget {
  final GroupInfo? groupInfo;
  final S5Messenger s5messenger;
  final SharedPreferencesWithCache prefs;
  final LocationService locationService;
  const MapOverlay(
      {super.key,
      required this.groupInfo,
      required this.s5messenger,
      required this.prefs,
      required this.locationService});

  @override
  Widget build(BuildContext context) {
    // put a listener here so whenever the group is changed the mapoverlay can respond to that
    return BlocListener<HomeCubit, HomeState>(
        listener: (BuildContext context, HomeState homeState) {
          if (homeState is HomeGroupSelected) {
            BlocProvider.of<MapOverlayCubit>(context)
                .groupSelectedEngagePins(homeState.group);
          }
        },
        child: _MapOverlayContent(
          groupInfo: groupInfo,
          s5messenger: s5messenger,
          prefs: prefs,
          locationService: locationService,
        ));
  }
}

// Put the content here so I can wrap it in a listener properly
class _MapOverlayContent extends StatelessWidget {
  final GroupInfo? groupInfo;
  final S5Messenger s5messenger;
  final SharedPreferencesWithCache prefs;
  final LocationService locationService;
  const _MapOverlayContent(
      {required this.groupInfo,
      required this.s5messenger,
      required this.prefs,
      required this.locationService});

  @override
  Widget build(BuildContext context) {
    // If groupInfo present, do the overlay for group
    if (groupInfo != null) {
      return BlocListener<MapOverlayCubit, MapOverlayState>(
          listener: (BuildContext context, MapOverlayState mapOverlayState) {
            if (mapOverlayState is MapOverlayQRPopupPressed) {
              // Shows dialog for the QR button so user can scan
              showDialog<dynamic>(
                  context: context,
                  builder: (BuildContext context) {
                    return BlocProvider<KeypairQRCubit>(
                      create: (BuildContext context) => KeypairQRCubit(
                          s5messenger: s5messenger,
                          locationService: locationService),
                      child: KeypairQrReadWriteDialog(
                          keypair: mapOverlayState.keypair),
                    );
                  });
            }
            if (mapOverlayState is MapOverlayGroupPopupPressed) {
              // Shows dialog for group so user can see group info
              showModalBottomSheet<dynamic>(
                context: context,
                builder: (BuildContext context) {
                  return BlocProvider<GroupSheetCubit>(
                    create: (BuildContext context) => GroupSheetCubit(
                        s5messenger: s5messenger,
                        groupInfo: groupInfo!,
                        prefs: prefs,
                        locationService: locationService),
                    child: GroupSheet(
                      groupInfo: groupInfo!,
                      s5messenger: s5messenger,
                    ),
                  );
                },
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
                    create: (BuildContext context) => KeypairQRCubit(
                        s5messenger: s5messenger,
                        locationService: locationService),
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
