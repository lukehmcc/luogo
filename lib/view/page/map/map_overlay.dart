import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/home_cubit.dart';
import 'package:luogo/cubit/home/home_state.dart';
import 'package:luogo/cubit/map/group_sheet/group_sheet_cubit.dart';
import 'package:luogo/cubit/map/invite_scanner/invite_scanner_cubit.dart';
import 'package:luogo/cubit/map/map_overlay/map_overlay_cubit.dart';
import 'package:luogo/cubit/map/map_overlay/map_overlay_state.dart';
import 'package:luogo/model/group_info.dart';
import 'package:luogo/services/group_crypto.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/services/relay_client.dart';
import 'package:luogo/view/page/map/group_sheet.dart';
import 'package:luogo/view/page/map/invite_scanner_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides the MapOverlay that users can interact with once a group is selected
class MapOverlay extends StatelessWidget {
  final GroupInfo? groupInfo;
  final RelayClient relayClient;
  final GroupCrypto crypto;
  final SharedPreferencesWithCache prefs;
  final LocationService locationService;
  const MapOverlay({
    super.key,
    required this.groupInfo,
    required this.relayClient,
    required this.crypto,
    required this.prefs,
    required this.locationService,
  });

  @override
  Widget build(BuildContext context) {
    // put a listener here so whenever the group is changed the mapoverlay can respond to that
    return BlocListener<HomeCubit, HomeState>(
        listener: (BuildContext context, HomeState homeState) {
          if (homeState is HomeGroupSelected && homeState.group != null) {
            BlocProvider.of<MapOverlayCubit>(context)
                .groupSelectedEngagePins(homeState.group!);
          }
        },
        child: _MapOverlayContent(
          groupInfo: groupInfo,
          relayClient: relayClient,
          crypto: crypto,
          prefs: prefs,
          locationService: locationService,
        ));
  }
}

// Put the content here so I can wrap it in a listener properly
class _MapOverlayContent extends StatelessWidget {
  final GroupInfo? groupInfo;
  final RelayClient relayClient;
  final GroupCrypto crypto;
  final SharedPreferencesWithCache prefs;
  final LocationService locationService;
  const _MapOverlayContent(
      {required this.groupInfo,
      required this.relayClient,
      required this.crypto,
      required this.prefs,
      required this.locationService});

  @override
  Widget build(BuildContext context) {
    // If groupInfo present, do the overlay for group
    final HomeCubit homeCubit = context.read<HomeCubit>();
    final MapOverlayCubit mapOverlayCubit = context.read<MapOverlayCubit>();
    if (groupInfo != null) {
      return BlocListener<MapOverlayCubit, MapOverlayState>(
          listener: (BuildContext context, MapOverlayState mapOverlayState) {
            if (mapOverlayState is MapOverlayScannerPopupPressed) {
              // Shows dialog for the QR button so user can scan
              showDialog<dynamic>(
                context: context,
                builder: (BuildContext context) {
                  return BlocProvider<InviteScannerCubit>(
                    create: (BuildContext context) => InviteScannerCubit(
                      relayClient: relayClient,
                      groupCrypto: crypto,
                      locationService: locationService,
                      prefs: prefs,
                    ),
                    child: InviteScannerDialog(
                      homeCubit: homeCubit,
                      mapOverlayCubit: mapOverlayCubit,
                    ),
                  );
                },
              );
            }
            if (mapOverlayState is MapOverlayGroupPopupPressed) {
              // Shows dialog for group so user can see group info
              showModalBottomSheet<dynamic>(
                context: context,
                builder: (BuildContext context) {
                  return Scaffold(
                    body: BlocProvider<GroupSheetCubit>(
                      create: (BuildContext context) => GroupSheetCubit(
                          relayClient: relayClient,
                          groupInfo: groupInfo!,
                          prefs: prefs,
                          locationService: locationService),
                      child: GroupSheet(
                        groupInfo: groupInfo!,
                        relayClient: relayClient,
                        groupCrypto: crypto,
                      ),
                    ),
                  );
                },
              ).then((_) {
                // Since there is no reliable notifier when the user has joined the group,
                // put on a listener to check for when they send their first message
                mapOverlayCubit.ensureSufficientPinsPopulated(groupInfo!);
              });
            }
          },
          child: SafeArea(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsetsGeometry.all(8),
                        child: Text(
                          groupInfo!.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
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
                            heroTag: "map-overlay-floater",
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
          if (mapOverlayState is MapOverlayScannerPopupPressed) {
            // Shows dialog for the QR button so user can scan
            showDialog(
                context: context,
                builder: (BuildContext context) {
                  return BlocProvider<InviteScannerCubit>(
                    create: (BuildContext context) => InviteScannerCubit(
                      relayClient: relayClient,
                      groupCrypto: crypto,
                      locationService: locationService,
                      prefs: prefs,
                    ),
                    child: InviteScannerDialog(
                      homeCubit: homeCubit,
                      mapOverlayCubit: mapOverlayCubit,
                    ),
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
