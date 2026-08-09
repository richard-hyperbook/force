import 'dart:math';
import 'node.dart';

class Group {
  String? name;
  List<int>? nodeUids;
  bool? isVisible;
  int? groupNodeUid;
  bool? isCollapsed;

  Group({this.name, this.nodeUids, this.isVisible, this.groupNodeUid});

  Map<String, dynamic> toJson() {
    Map<String, dynamic> m = {
      'name': name,
      'nodeUids': getStringFromNodeUids(nodeUids!),
      'isVisible': isVisible,
      'groupNodeIndex': groupNodeUid,
      'isCollapsed': isCollapsed,
    };
    print('(FH84)${this.name}....${this.nodeUids},,,,${this.groupNodeUid}@@@@${m}');
    return m;
  }

  String? getStringFromNodeUids(List<int> ni) {
    String json = '[';
    for (int i = 0; i < ni.length; i++) {
      String separator = ',';
      if (i == 0) {
        separator = '';
      }
      json = json + separator + ni[i].toString();
    }
    return json + ']';
  }

}

