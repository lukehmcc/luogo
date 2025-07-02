import 'package:flutter/material.dart';
import 'package:luogo/model/group_info.dart';
import 'package:s5_messenger/s5_messenger.dart';

/// Provides the MapOverlay that users can interact with once a group is selected
class MapOverlay extends StatelessWidget {
  final GroupInfo group;
  final S5Messenger s5messenger;
  const MapOverlay({super.key, required this.group, required this.s5messenger});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(top: 48),
          child: Align(
            alignment: Alignment.topCenter,
            child: Card(
              child: Padding(
                padding: EdgeInsetsGeometry.all(8),
                child: Text(group.name),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 48, horizontal: 25),
            child: Card(
                child: IconButton(
              icon: const Icon(Icons.group),
              onPressed: () {
                // Add your settings logic here
              },
            )),
          ),
        )
      ],
    );
  }
}
