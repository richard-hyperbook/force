import 'dart:math';
import 'node.dart';

class Group {
  String? name;
  List<int>? nodeIndexes;
  bool? isVisible;

  Group({this.name, this.nodeIndexes, this.isVisible});

  Map<String, dynamic> toJson() {
    Map<String, dynamic> m = {
      'name': name,
      'nodeIndexes': getStringFromNodeIndexes(nodeIndexes!),
      'isVisible': isVisible,
    };
    print('(FH84)${this.name}....${this.nodeIndexes},,,,${m}');
    return m;
  }

  String? getStringFromNodeIndexes(List<int> ni) {
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

