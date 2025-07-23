/// A model class for representing group information.
///
/// Example usage:
/// ```dart
/// final group = GroupInfo(id: "xxx", name: "xxx");
/// ```
class GroupInfo {
  final String id;
  final String name;

  GroupInfo({required this.id, required this.name});

  factory GroupInfo.fromJson(dynamic json) {
    return GroupInfo(
      id: json['id'],
      name: json['name'],
    );
  }

  static GroupInfoList fromJsonList(List<dynamic> jsonList) {
    return GroupInfoList(
        groups: jsonList.map((json) => GroupInfo.fromJson(json)).toList());
  }

  @override
  String toString() {
    return "ID: $id, Name: $name";
  }
}

/// A utility class for managing a list of GroupInfo objects.
///
///
/// Example usage:
/// ```dart
/// final groups = GroupInfoList(groups: [GroupInfo(id: "xxx", name: "xxx")]);
/// final group = groups.findByID("xxx");  // Returns the GroupInfo if found
/// final firstGroup = groups[0];  // Accesses the first group
/// final count = groups.length;  // Gets the number of groups
/// ```
class GroupInfoList {
  List<GroupInfo> groups;
  GroupInfoList({required this.groups});

  GroupInfo? findByID(String id) {
    for (GroupInfo group in groups) {
      if (group.id == id) {
        return group;
      }
    }
    return null;
  }

  GroupInfo operator [](int index) => groups[index];
  int get length => groups.length;
}
