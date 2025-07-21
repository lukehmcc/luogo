import 'package:flutter/material.dart';
import 'package:luogo/model/user_state.dart';
import 'package:intl/intl.dart';
import 'package:luogo/view/widgets/circle_avatar_styled_named.dart';

/// A modal that displays user information when a symbol is clicked.
///
/// This widget shows a circular avatar with the user's initial and their name.
/// The avatar's color is derived from [userState.color], and the name is displayed
/// adjacent to the avatar.
///
/// **Example**:
/// ```dart
/// BottomSheetInfoModal(
///   userState: UserState(...),
///   isYou: false,
/// )
/// ```
///
/// See also:
/// - [UserState], the model providing user data.
/// - [CircleAvatar], the widget used for the circular display.
class BottomSheetInfoModal extends StatelessWidget {
  final UserState userState;
  final bool isYou;
  const BottomSheetInfoModal({
    super.key,
    required this.userState,
    required this.isYou,
  });
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatarStyledNamed(
                name: userState.name,
                color: Color(userState.color),
              ),
              SizedBox(
                width: 10,
              ),
              Text(
                "${userState.name} ${(isYou) ? "(you)" : ""}",
                style: TextStyle(fontSize: 20),
              ),
            ],
          ),
          SizedBox(
            height: 10,
          ),
          Text(
              "Last seen: ${DateFormat('EEE, HH:mm').format(DateTime.fromMillisecondsSinceEpoch(userState.ts))}"),
        ],
      ),
    );
  }
}
