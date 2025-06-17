import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:luogo/view/page/map.dart';

void _deleteHive() {
  Hive.deleteFromDisk();
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                // Scrollable content
                child: Column(
                  children: [
                    const DrawerHeader(
                      child: Text('Drawer Header'),
                    ),
                    ListTile(
                      title: const Text('Item 1'),
                      onTap: () {
                        // Update the state of the app.
                        // ...
                      },
                    ),
                    ListTile(
                      title: const Text('Item 2'),
                      onTap: () {
                        // Update the state of the app.
                        // ...
                      },
                    ),
                    // Add more items here if needed
                  ],
                ),
              ),
            ),
            // Fixed-positioned button at the bottom
            if (kDebugMode)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Tooltip(
                    message: "Nuke Hive",
                    child: IconButton(
                        icon: const Icon(Icons.delete), // Customize icon
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Hive nuked (debug only)"),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          Navigator.pop(context);
                          _deleteHive();
                        }),
                  ),
                ),
              ),
          ],
        ),
      ),
      extendBodyBehindAppBar: true,
      body: MapView(),
    );
  }
}
