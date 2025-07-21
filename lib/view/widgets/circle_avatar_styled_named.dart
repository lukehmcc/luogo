import 'package:flutter/material.dart';

class CircleAvatarStyledNamed extends StatelessWidget {
  final String name;
  final Color color;
  const CircleAvatarStyledNamed({
    super.key,
    required this.name,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.black,
          width: 2.0, // Adjust border thickness as needed
        ),
      ),
      child: CircleAvatar(
        backgroundColor: color,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              name[0].toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 40, // large font size; will be scaled to fit
                height: 40.0, // remove extra line spacing
              ),
              textHeightBehavior: TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
