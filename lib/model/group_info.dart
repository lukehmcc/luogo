/// Class to handle MLS groups
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
