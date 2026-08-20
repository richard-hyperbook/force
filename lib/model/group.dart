import 'dart:math';
import 'node.dart';

class Group {
  String? name;
  List<int>? nodeUids;
  bool? isVisible;
  int? groupNodeUid;
  bool? isCollapsed;
  String? incomingLabels;
  String? outgoingLabels;

  Group({
    this.name,
    this.nodeUids,
    this.isVisible,
    this.groupNodeUid,
    this.incomingLabels,
    this.outgoingLabels,
  });

  Map<String, dynamic> toJson() {
    Map<String, dynamic> m = {
      'name': name,
      'nodeUids': getStringFromNodeUids(nodeUids!),
      'isVisible': isVisible,
      'groupNodeUid': groupNodeUid,
      'isCollapsed': isCollapsed,
      'incomingLabels': incomingLabels,
      'outgoingLabels': outgoingLabels,
    };
    print(
      '(FH84)${this.name}....${this.nodeUids},,,,${this.groupNodeUid}@@@@${m}',
    );
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

Group cloneGroup(Group g) {
  List<int>? nu;
  if (g.nodeUids != null){
    nu = List<int>.from(g.nodeUids!);
  }
  Group gg = Group(
    name: g.name,
    nodeUids: nu,
    isVisible: g.isVisible,
    groupNodeUid: g.groupNodeUid,
    incomingLabels: g.incomingLabels,
    outgoingLabels: g.outgoingLabels,
  );
  return gg;
}
