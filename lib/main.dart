import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
// import 'package:flutter_force_directed_graph/flutter_force_directed_graph.dart';
import 'package:matrix4_transform/matrix4_transform.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import 'package:vector_math/vector_math.dart' as vector;
import 'flutter_force_directed_graph.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'dart:io';
import 'dart:convert';
import 'package:function_tree/function_tree.dart';
import 'package:expressions/expressions.dart';

const buildNumber = 23;
const double arrowHeight = 5;
const double arrowWidth = 15;
const double lineWidth = 2;
const double boxHeight = 10;
const double chainYincrement = boxHeight + 10;
const double charWidth = 10;
const double boxPadding = 5;
//NodeContents? edgeStartNodeContents;

NodeContents? edgeInputNodeContentsA;
NodeContents? edgeCommonNodeContentsA;
NodeContents? edgeOutputNodeContentsA;
NodeContents? edgeInputNodeContentsB;
NodeContents? edgeCommonNodeContentsB;
NodeContents? edgeOutputNodeContentsB;
bool _running = true;

const kEndpoint = 'https://fra.cloud.appwrite.io/v1';
const kProjectID = '696ddda6001b28f2352e';
const kDevKey =
    '4de99514ee3d5a8fb3cdf236ba66a91e9bdb37c8397f9f98542530bd2f6a71797d93b068276fc23c0aba27cbd1e41912d4362456a9a167150bc5a2d66265b86a94229cfaf7d63181b173898e5f322b28f4d1c9a6c3470fa129f933062428ceb4806c26ca5bfa8e91d7e88f8dcbc430d1eb864016906a31d0dd78bf6a9450794d';
const kBucketID = '6a37881000326addb17a';
const kDatabaseID = '6a37a61700206fef051a';
const kSpreadsheets = 'spreadsheets';
const kGroups = 'groups';
const kColumnFilename = 'filename';
const kColumnJson = 'json';
const imageFilenameHead = kEndpoint + '/storage/buckets';
Group chosenGroup = nullGroup;
// NodeFunction chosenNodeFunction = NodeFunction.add;

Client? client;
Databases? appwriteDatabases;
Account? account;
Storage? storage;
Databases? databases;
TextEditingController filenameTextEditingController = TextEditingController(
  text: '',
);
TextEditingController dataEntryTextEditingController = TextEditingController(
  text: '',
);
TextEditingController groupNameTextEditingController = TextEditingController(
  text: '',
);

void moveNodesInGroupWithGroupNode(int groupNodeUid) {
  print('(FJ7)${groupNodeUid}');
  if (_controller.graph.groups.length < 1) return;
  Group? group;
  for (int i = 0; i < _controller.graph.groups.length; i++) {
    if (_controller.graph.groups[i].groupNodeUid == groupNodeUid) {
      group = _controller.graph.groups[i];
      break;
    }
  }
  Node groupNode = getNodeFromUid(groupNodeUid)!;
  vector.Vector2 groupNodePosition = groupNode.position!;
  if (group == null) return;
  for (int i = 0; i < _controller.graph.nodes.length; i++) {
    int nodeUid = _controller.graph.nodes[i].data.uid!;
    print(
      '(FJ6)${i}....${nodeUid},,,,${group.nodeUids}<<<<${groupNodePosition}',
    );
    if (group.nodeUids!.indexOf(nodeUid) != -1) {
      _controller.graph.nodes[i].position = groupNodePosition;
    }
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      config: const ToastificationConfig(
        alignment: Alignment.center,
        itemWidth: 440,
        animationDuration: Duration(milliseconds: 500),
        blockBackgroundInteraction: false,
      ),
      child: MaterialApp(
        title: 'Visual Spreadsheet ${buildNumber}',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const MyHomePage(title: 'Visual Spreadsheet ${buildNumber}'),
      ),
    );
  }
}

enum NodeKind { kindError, kindGroup, kindDouble, kindDateTime, kindString }

const NodeKind ke = NodeKind.kindError;
const NodeKind kg = NodeKind.kindGroup;
const NodeKind kd = NodeKind.kindDouble;
const NodeKind kt = NodeKind.kindDateTime;
const NodeKind ks = NodeKind.kindString;

NodeKind? getNodeKindFromString(String s) {
  switch (s) {
    case 'kindError':
      return ke;
    case 'kindGroup':
      return kg;
    case 'kindDouble':
      return kd;
    case 'kindDateTime':
      return kt;
    case 'kindString':
      return ks;
    default:
      return null;
  }
}

String? getStringFromNodeKind(NodeKind? k) {
  switch (k) {
    case ke:
      return 'kindError';
    case kg:
      return 'kindGroup';
    case kd:
      return 'kindDouble';
    case kt:
      return 'kindDateTime';
    case ks:
      return 'kindString';
    default:
      return null;
  }
}

enum NodeOperation {
  noop,
  illegal,
  functionDouble,
  functionDayToDate,
  latestDate,
  functionDoubleToString,
}

// enum NodeFunction { nof, add, multiply, reciprocate }
//
// const NodeFunction kNof = NodeFunction.nof;
// const NodeFunction kAdd = NodeFunction.add;
// const NodeFunction kMultiply = NodeFunction.multiply;
// const NodeFunction kReciprocate = NodeFunction.reciprocate;

class NodeContents {
  int? uid;
  NodeKind? kind;
  String? input;
  double? doubleResult;
  DateTime? dateTimeResult;
  String? stringResult;
  bool? isStartNode;
  bool? isEndNode;
  bool? isHighlight;
  bool? isDataEntry;

  //TextEditingController? textEditingController = TextEditingController(
  // text: '',
  // );
  NodeContents({
    required this.uid,
    required this.kind,
    this.input,
    this.doubleResult,
    this.dateTimeResult,
    this.stringResult,
    this.isStartNode,
    this.isEndNode,
    this.isHighlight,
    required this.isDataEntry,
  });

  Map<String, dynamic> toJson() {
    Map<String, dynamic> m = {
      'uid': uid,
      'kind': getStringFromNodeKind(kind),
      'input': input,
      'doubleResult': doubleResult,
      'dateTimeResult': dateTimeResult?.toIso8601String(),
      'stringResult': stringResult,
      'isStartNode': isStartNode,
      'isEndNode': isEndNode,
      'isHighlight': isHighlight,
      'isDataEntry': isDataEntry,
    };
    //1print('(FF750)${this.uid}....${this.kind},,,,${m}');
    return m;
  }

  /*NodeContents.fromJson(Map<String, dynamic> json)
    : uid = (json['uid'] as num?)?.toInt(),
      //json['uid'] as int,
      kind = getNodeKindFromString(json['kind']),
      //json['kind'] as NodeKind,
      input = json['input'] as String,
      doubleResult = (json['doubleResult'] as num?)?.toDouble(),
      //json['doubleResult'] as double,
      dateTimeResult = DateTime.parse(json['dateTimeResult'] as String),
      //json['dateTimeResult'] as DateTime,
      stringResult = json['stringResul'] as String,
      isStartNode = json['isStartNode'] as bool,
      isEndNode = json['isEndNode'] as bool;*/

  factory NodeContents.fromJson(Map<String, dynamic> json) => NodeContents(
    uid: json["uid"] as int,
    kind: getNodeKindFromString(json['kind'])!,
    input: json["input"] as String,
    doubleResult: json["doubleResult"] as double,
    dateTimeResult: DateTime.parse(json['dateTimeResult'] as String),
    stringResult: json["stringResult"] as String,
    isStartNode: json["isStartNode"] as bool,
    isEndNode: json["isEndNode"] as bool,
    isHighlight: json['isHighlight'] as bool,
    isDataEntry: json['isDataEntry'] as bool,
  );

  /*LinkItem.fromJson(Map<String, dynamic> json)
      : name = json['n'],
        url = json['u'];

  Map<String, dynamic> toJson() {
    return {
      'n': name,
      'u': url,
    };
    */

  factory NodeContents.nodeContentsfromJson(Map<String, dynamic> json) {
    return NodeContents(
      uid: (json['uid'] as num?)?.toInt(), //json['uid'] as int,
      kind: getNodeKindFromString(json['kind']), //json['kind'] as NodeKind,
      input: json['input'] as String,
      doubleResult: (json['doubleResult'] as num?)
          ?.toDouble(), //json['doubleResult'] as double,
      dateTimeResult: DateTime.parse(
        json['dateTimeResult'] as String,
      ), //json['dateTimeResult'] as DateTime,
      stringResult: json['stringResul'] as String,
      isDataEntry: json['isDataEntry'] as bool,
    );
  }
}

//The argument type 'NodeContents Function(Map<String, dynamic>)' can't be assigned to the parameter type 'NodeDataDeserializer<NodeContents>?'.
NodeContents deserializeNodeContents(dynamic d) {
  print('(FF1005A)${d.runtimeType}');
  //Map<String, dynamic> nd = d['data'];
  var dd = d as Map<String, dynamic>;
  var nd = dd['data'];
  print('(FF1005B)${d}....${dd}----${nd}----');
  if (nd == null) {
    nd = dd;
  }
  print('(FF1005C)${nd['uid']}++++${nd['kind']}');
  return NodeContents(
    uid: nd['uid'],
    kind: getNodeKindFromString(nd['kind']) ?? kd,
    input: nd['input'],
    doubleResult: nd['doubleResult'],
    dateTimeResult: DateTime.tryParse(nd['dateTimeResult'] ?? ''),
    stringResult: nd['stringResul'],
    isStartNode: nd['isStartNode'],
    isEndNode: nd['isEndNode'],
    isHighlight: nd['isHighlight'],
    isDataEntry: nd['isDataEntry'],
  );
}

Group deserializeGroupContents(dynamic d) {
  print('(FH1005A)${d.runtimeType}');
  //Map<String, dynamic> nd = d['data'];
  var dd = d as Map<String, dynamic>;
  print('(FH1005B)${d}....${dd}');

  return Group(
    name: dd['name'],
    nodeUids: getNodeUidsFromString(dd['nodeUids']),
    isVisible: dd['input'],
  );
}

class Spreadsheet {}

class Arguments {
  Map<String, dynamic> args = {};
  Arguments(this.args);
  Arguments.clear() {
    args.clear();
  }
  void add(String name, dynamic value) {
    this.args[name] = value;
  }

  List<dynamic> values() {
    List<dynamic> vv = [];
    for (var v in this.args.values) {
      vv.add(v);
    }
    return vv;
  }
}

List<int> getNodeUidsFromString(String s) {
  List<int> ni = [];
  List<String> ss = s.split(',');
  for (int i = 0; i < ss.length; i++) {
    int? uid = int.tryParse(ss[i]);
    if (uid != null) {
      ni.add(uid);
    }
  }
  return ni;
}

final Group nullGroup = Group(name: '', nodeUids: [], isVisible: false);

Group groupFromMap(Map<String, dynamic> groupMap) {
  // String nodeUidsString = groupMap['nodeUids'];
  //
  // List<String> nodeUidsStringList = nodeUidsString.split(',');
  // List<int> nodeUidsList = [];
  // for (int i = 0; i < nodeUidsStringList.length; i++) {
  //   nodeUidsList.add(int.tryParse(nodeUidsStringList[i]) ?? -1);
  // }
  String guid = groupMap['nodeUids'];
  guid = guid.replaceAll('[', '');
  guid = guid.replaceAll(']', '');
  List<String> guidList = guid.split(',');
  List<int> g = [];
  for (int i = 0; i < guidList.length; i++) {
    g.add((int.tryParse(guidList[i])) ?? 0);
  }
  debugPrint('(FH86)${groupMap}....${guid},,,${guidList}++++${g}');

  Group group = Group(
    name: groupMap['name'],
    nodeUids: g,
    isVisible: groupMap['isVisible'],
    groupNodeUid: groupMap['groupNodeUid'],
  );
  print('(FH1002)${groupMap}====${group}');
  return group;
}

String groupsToJson() {
  List<Set<Map<String, dynamic>>> x = _controller.graph.groups
      .map((e) => {e.toJson()})
      .toList();
  print('(FH61)${x}');
  String s = jsonEncode({
    'groups': _controller.graph.groups.map((e) => e.toJson()).toList(),
  });
  print('(FH60)${s}');
  return s;
}

void loadGroupsFromJson(String json) {
  final decodedJson = jsonDecode(json);
  print('(FH70)${json}....${decodedJson}');
  for (final groupData in decodedJson['groups']) {
    Group group = groupFromMap(groupData);
    _controller.graph.groups.add(group);
    print('(FH7)${groupData}....${group}');
  }
}

Group? getGroupFromNodeUid(int? nodeUid) {
  if (nodeUid == null) return null;
  for (int i = 0; i < _controller.graph.groups.length; i++) {
    if (nodeUid == _controller.graph.groups[i].groupNodeUid) {
      return _controller.graph.groups[i];
    }
  }
  return null;
}

Group? getGroupFromGroupName(String? groupName) {
  if (groupName == null) return null;
  for (int i = 0; i < _controller.graph.groups.length; i++) {
    if (groupName == _controller.graph.groups[i].name) {
      return _controller.graph.groups[i];
    }
  }
  return null;
}

int? getGroupNodeUidFromGroupName(String? groupName) {
  if (groupName == null) return null;
  for (int i = 0; i < _controller.graph.groups.length; i++) {
    if (groupName == _controller.graph.groups[i].name) {
      return _controller.graph.groups[i].groupNodeUid!;
    }
  }
  return null;
}

late final ForceDirectedGraphController _controller;

List<EdgeExtra> _edgeExtras = [];

void dumpGraph() {
  print('1');
  for (var node in _controller.graph.nodes) {
    print(
      //'(FFDN)--x>${node.position.x}--y>${node.position.y}>>>>${node.data.uid}<<<<${node.data.input}££££${node.data.kind};;;;${node.data.doubleResult}::::${node.data.dateTimeResult}@@@@${node.data.stringResult}}',
      '(FFDN)${node.data.uid}<<<<${node.data.input}££££${node.data.kind};;;;${node.data.doubleResult}::::${node.data.dateTimeResult}@@@@${node.data.stringResult}}',
    );
  }
  for (var edge in _controller.graph.edges) {
    // print(
    //    '(FFDE)${edge.a.data.uid}${edge.a.data.kind}....${edge.b.data.uid}${edge.b.data.kind},,,,${edge.edgeExtra.label}',
    //  );
    print(
      //'(FFDF)${edge.a.position}||||${edge.a.mass}....${edge.b.position}!!!!${edge.b.mass},,,,${edge.distance}????${edge.angle}',
      '(FFDF)${edge.a.data.uid},,,,${edge.b.data.uid}',
    );
  }
  for (int i = 0; i < _controller.graph.groups.length; i++) {
    print(
      '(FFDG)${_controller.graph.groups[i].name}....${_controller.graph.groups[i].nodeUids},,,,${_controller.graph.groups[i].isVisible}||||${_controller.graph.groups[i].groupNodeUid}::::${_controller.graph.groups[i].isCollapsed}',
    );
  }
}

int? getEdgeIntegerFromNodeUids({int? uidA, int? uidB}) {
  for (int i = 0; i < _controller.graph.edges.length; i++) {
    if ((_controller.graph.edges[i].a.data.uid == uidA) &&
        (_controller.graph.edges[i].b.data.uid == uidB)) {
      return i;
    }
  }
  return null;
}

EdgeExtra? getEdgeExtraFromNodeUids({int? uidA, int? uidB}) {
  int? i = getEdgeIntegerFromNodeUids(uidA: uidA, uidB: uidB);
  if (i == null) return null;
  return _controller.graph.edges[i].edgeExtra;
}

Node? getNodeFromUid(int? uid) {
  print('(FF3020)${uid}....${_controller.graph.nodes.length}');
  for (int i = 0; i < _controller.graph.nodes.length; i++) {
    print(
      '(FF3021)${uid}....${_controller.graph.nodes[i].data.uid},,,,${_controller.graph.nodes[i]}',
    );
    if (uid == _controller.graph.nodes[i].data.uid) {
      return _controller.graph.nodes[i];
    }
  }
  return null;
}

bool isEdgeActive({int? uidA, int? uidB}) {
  //1print(
  //1 '(FF760)${uidA}....${uidB},,,,${getEdgeExtra(uidA: uidA, uidB: uidB)}',
  //1 );
  EdgeExtra? ee = getEdgeExtraFromNodeUids(uidA: uidA, uidB: uidB);
  return ee!.isActive!;
}

void setEdgeExtraIsActive({int? uidA, int? uidB, bool? isActive = true}) {
  int? i = getEdgeIntegerFromNodeUids(uidA: uidA, uidB: uidB);
  if (i == null) return;
  _controller.graph.edges[i].edgeExtra.isActive = isActive;
}

String? getEdgeLabel({int? uidA, int? uidB}) {
  //1print(
  //1 '(FF760B)${uidA}....${uidB},,,,${getEdgeExtra(uidA: uidA, uidB: uidB)}',
  //1 );
  EdgeExtra? ee = getEdgeExtraFromNodeUids(uidA: uidA, uidB: uidB);
  return ee!.label;
}

void setEdgeLabel({int? uidA, int? uidB, String? label}) {
  int? i = getEdgeIntegerFromNodeUids(uidA: uidA, uidB: uidB);
  if (i == null) return;
  _controller.graph.edges[i].edgeExtra.label = label;
}

void addEdgeByData({
  required NodeContents? nodeA,
  required NodeContents? nodeB,
  required bool? isActive,
  required String? label,
}) {
  debugPrint('(FQ4)${nodeA!.uid}!${nodeB!.uid}');
  _controller.addEdgeByData(
    nodeA,
    nodeB,
    EdgeExtra(isActive: isActive, label: label),
  );

  print(
    '(FF761)${nodeA.uid}....${nodeB.uid},,,,${isActive}++++${getEdgeExtraFromNodeUids(uidA: nodeA.uid, uidB: nodeB.uid)!.isActive})}',
  );
  //dumpGraph();
}

void deleteEdgeByData({
  required NodeContents? nodeA,
  required NodeContents? nodeB,
}) {
  _controller.deleteEdgeByData(nodeA!, nodeB!);
}

int _uidMaster = 1;

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // int _nodeCount = 0;
  // final Set<NodeContents> _nodes = {};
  // final Set<String> _edges = {};
  double _scale = 1.0;
  int _locatedTo = 0;
  NodeContents? _draggingData;
  String? _json;

  void initAppwrite() {
    client = Client()
        .setEndpoint(kEndpoint)
        .setProject(kProjectID)
        .setDevKey(kDevKey)
        .setSelfSigned();
    account = Account(client!);
    storage = Storage(client!);
    databases = Databases(client!);
  }

  @override
  void initState() {
    super.initState();
    initAppwrite();

    _uidMaster = 0;
    _controller =
        ForceDirectedGraphController(
          graph: ForceDirectedGraph.generateNTree(
            config: GraphConfig(elasticity: 0.15),
            nodeCount: 1,
            maxDepth: 20,
            n: 4,
            generator: () {
              int uid = _uidMaster;
              _uidMaster++;
              return NodeContents(
                kind: kd,
                uid: uid,
                input: '',
                isDataEntry: false,
              );
            },
          ),
        )..setOnScaleChange((scale) {
          // can use to optimize the performance
          // if scale is too small, can use simple node and edge builder to improve performance
          if (!mounted) return;
          setState(() {
            _scale = scale;
          });
        });

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _controller.needUpdate();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  NodeContents? getNodeContentsFromUid(int uid) {
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.uid == uid) {
        return _controller.graph.nodes[i].data;
      }
    }
    return null;
  }

  void setControllerResult({int? uid, dynamic value}) {
    //1print('(FF331)${uid}....${value}');
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.uid == uid) {
        if (value is double) {
          _controller.graph.nodes[i].data.doubleResult = value;
        } else {
          if (value is DateTime) {
            _controller.graph.nodes[i].data.dateTimeResult = value;
          } else {
            if (value is String) {
              _controller.graph.nodes[i].data.stringResult = value;
            }
          }
        }
        //1print(
        //1 '(FF332)${_controller.graph.nodes[i].data.uid}++++${_controller.graph.nodes[i].data.doubleResult}....${_controller.graph.nodes[i].data.dateTimeResult},,,,${_controller.graph.nodes[i].data.stringResult}',
        //1);
        break;
      }
    }
  }

  void setControllerInput({int? uid, dynamic value}) {
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.uid == uid) {
        _controller.graph.nodes[i].data.input = value;
        break;
      }
    }
  }

  void setControllerIsStartNode({int? uid, bool? value}) {
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.uid == uid) {
        _controller.graph.nodes[i].data.isStartNode = value;
        break;
      }
    }
  }

  void setControllerIsEndNode({int? uid, bool? value}) {
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.uid == uid) {
        _controller.graph.nodes[i].data.isEndNode = value;
        break;
      }
    }
  }

  void setControllerIsDataEntry({int? uid, bool? value}) {
    print('(FG7)${uid}....${value}');
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.uid == uid) {
        _controller.graph.nodes[i].data.isDataEntry = value;
        print('(FG8)${uid}....${value}');
        break;
      }
    }
  }

  void setControllerIsHighlight({int? uid, bool? value}) {
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.uid == uid) {
        _controller.graph.nodes[i].data.isHighlight = value;
        break;
      }
    }
  }

  vector.Vector2? getNodePosition(int? uid) {
    vector.Vector2? pos;
    for (var node in _controller.graph.nodes) {
      if (node.data.uid == uid) {
        pos = node.position;
        break;
      }
    }
    return pos;
  }

  setNodePosition(int? uid, vector.Vector2 pos) {
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.uid == uid) {
        print('(FI42)${uid}....${getNodePosition(uid)}||||${pos}');
        _controller.graph.nodes[i].position = pos;
        break;
      }
    }
  }

  setNodeKind(int? uid, NodeKind kind) {
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.uid == uid) {
        print(
          '(FI42B)${uid}....${_controller.graph.nodes[i].data.kind}||||${kind}',
        );
        _controller.graph.nodes[i].data.kind = kind;
        break;
      }
    }
  }

  void setControllerKind({int? uid, NodeKind? kind}) {
    for (var node in _controller.graph.nodes) {
      if (node.data.uid == uid) {
        node.data.kind = kind;
        break;
      }
    }
  }

  String getResult(NodeContents nodeContents) {
    if (nodeContents.kind == ke) {
      return '4ERROR 4';
    }
    DateTime? totalDateTime = stringToDateTime(nodeContents.input ?? '');
    double? totalDouble = double.tryParse(nodeContents.input ?? '');
    String? totalString = nodeContents.input;
    dynamic total = totalString;
    if (total == '') total = null;
    total = totalDouble ?? total;
    total = totalDateTime ?? total;
    bool edgeFound = false;
    bool isFirstEdge = true;
    //dumpGraph();
    Arguments args = Arguments.clear();
    AsciiCodec ac = AsciiCodec();
    String alpha = 'A';
    Map<String, num> mapOfLabels = {};
    for (var edge in _controller.graph.edges) {
      print(
        '(FF5)${nodeContents.uid}----${nodeContents.kind}++++${edge.a.data.uid}....${edge.a.data.kind}>>>>${edge.b.data.uid},,,,${edge.b.data.kind}',
      );
      if (edge.b.data.uid == nodeContents.uid) {
        print('(FF51)${nodeContents.kind}');
        if ((edge.edgeExtra.label ?? '') != '') {
          if (edge.a.data.kind == kg) {
            for (int j = 0; j < _controller.graph.edges.length; j++) {
              if (_controller.graph.edges[j].b.data.uid == edge.a.data.uid) {
                if (_controller.graph.edges[j].edgeExtra.label ==
                    edge.edgeExtra.label) {
                  mapOfLabels[edge.edgeExtra.label!] =
                      (_controller.graph.edges[j].a.data.doubleResult ?? 0)
                          as num;
                  print(
                    '(FFM1)${edge.edgeExtra.label}....${_controller.graph.edges[j].a.data.doubleResult}',
                  );
                  break;
                }
              }
            }
          } else {
            mapOfLabels[edge.edgeExtra.label!] =
                (edge.a.data.doubleResult ?? 0) as num;
          }
          print(
            '(FFE1)${edge.edgeExtra.label}....${edge.a.data.doubleResult},,,',
          );
        }
        isFirstEdge = false;
        edgeFound = true;
      }
    }
    print('(FFE4)${edgeFound}');
    if (edgeFound) {
      print('(FFE2)${nodeContents.input}....');

      /* ////////////CODE FOR UNLABELLED EDGES


      Map<String, num> n = {};
      for (var k in args.args.keys){
        n[k] = (args.args[k]?? 0) as num;
      }*/
      String? input = nodeContents.input;
      if ((input ?? '') == '') {
        total = 0.0;
      } else {
        try {
          Expression expression = Expression.parse(input!);
          final evaluator = const ExpressionEvaluator();
          total = evaluator.eval(expression, mapOfLabels);
          print('(FFL1)${mapOfLabels}....${expression}');
          setNodeKind(nodeContents.uid, kd);
        } catch (e) {
          total = 0.0;
          print('(FFL2)${e}....${input},,,,${mapOfLabels}');
        }
        print('(FFL3)${mapOfLabels}....${args.values()},,,,${total}');
      }
    }
    setControllerResult(
      uid: nodeContents.uid,
      value: total, //double.tryParse(nodeContents.input ?? '') ?? 0.0,
    );
    // total = double.tryParse(nodeContents.input ?? '') ?? 0.0;
    print('(FFP1)${nodeContents.uid}....${nodeContents.kind},,,,${total}');
    switch (nodeContents.kind) {
      case (ke):
        return '1ERROR 1';
      case (kg):
        final String groupName =
            (getGroupFromNodeUid(nodeContents.uid)!.name) ?? 'NO Group';
        return 'G: ' + groupName;
      case (kd):
        return total.toString();
      case (kt):
        if (total is DateTime) {
          return dateToString(total);
        } else {
          return '';
        }
      case (ks):
        if (total is double) {
          total = total.toString();
        }
        if (total is num) {
          total = total.toString();
        }
        if (total is bool) {
          total = '${total}';
        }
        if (total == null) {
          total = '';
        }
        return total;
      case (null):
        return '!!!';
    }
  }

  String dateToString(DateTime? dateTime) {
    if (dateTime == null) {
      return '';
    }
    return DateFormat('dd-MM-yyyy').format(dateTime);
  }

  DateTime? stringToDateTime(String s) {
    final customFormat = DateFormat('dd-MM-yyyy');
    DateTime? parsedDate;
    try {
      parsedDate = customFormat.parse(s);
    } on FormatException catch (e) {
      return null;
    }
    return parsedDate;
  }

  Color setBoxColor(NodeContents node) {
    //1print('(FF202)${node.uid}....${node.isStartNode},,,,${node.isEndNode}');
    if (node.isStartNode ?? false) {
      return Colors.pinkAccent;
    }
    if (node.isEndNode ?? false) {
      return Colors.lightGreenAccent;
    }
    if (node.isHighlight ?? false) {
      return Colors.amber;
    }
    return Colors.white;
  }

  Future<DateTime?> selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    return pickedDate;
  }

  String getPassiveEdgeResult(NodeContents data) {
    String passiveEdgeResult = '';
    for (int i = 0; i < _controller.graph.edges.length; i++) {
      print(
        '(FH7)${_controller.graph.edges[i].a.data.uid}....${_controller.graph.edges[i].b.data.uid}',
      );
      if ((_controller.graph.edges[i].b.data.uid == data.uid) &&
          (!_controller.graph.edges[i].edgeExtra.isActive!)) {
        print(
          '(FH8)${_controller.graph.edges[i].a.data.uid}....${_controller.graph.edges[i].a!.data.kind}',
        );
        switch (_controller.graph.edges[i].a!.data.kind) {
          case ke:
            passiveEdgeResult = '5ERROR';
            break;
          case kg:
            passiveEdgeResult = '6ERROR';
            break;
          case kd:
            passiveEdgeResult =
                (_controller.graph.edges[i].a!.data.doubleResult ?? 0)
                    .toString();
            break;
          case kt:
            passiveEdgeResult = dateToString(
              _controller.graph.edges[i].a!.data.dateTimeResult,
            );
            break;
          case ks:
            passiveEdgeResult =
                _controller.graph.edges[i].a!.data.stringResult ?? '';
            break;
          case null:
            passiveEdgeResult = '';
            break;
        }
        break;
      }
    }
    return passiveEdgeResult;
  }

  String getGroupsStringList(NodeContents data) {
    String groupStringList = '';
    for (int i = 0; i < _controller.graph.groups.length; i++) {
      for (int j = 0; j < _controller.graph.groups[i].nodeUids!.length; j++) {
        if (_controller.graph.groups[i].nodeUids![j] == data.uid) {
          groupStringList =
              '${groupStringList}, ${_controller.graph.groups[i].name!}';
        }
      }
    }
    return groupStringList;
  }

  void showDataEntryDialog(NodeContents data) {
    String passiveEdgeResult = getPassiveEdgeResult(data);
    showDialog<double>(
      context: context,
      builder: (BuildContext context) {
        TextEditingController dataEntryController = TextEditingController(
          text: data.input,
        );
        return AlertDialog(
          title: Text(passiveEdgeResult),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(controller: dataEntryController, onChanged: (value) {}),
              Row(
                children: [
                  ElevatedButton(
                    child: const Text('Enter'),
                    onPressed: () {
                      String value = dataEntryController!.text;
                      // double? doubleValue = double.tryParse(value);
                      print('(FH5)${value}++++${data.uid}');
                      double? doubleValue = double.tryParse(value);
                      setState(() {
                        if (doubleValue == null) {
                          setControllerKind(uid: data.uid, kind: ks);
                        } else {
                          setControllerKind(uid: data.uid, kind: kd);
                          double? doubleValue = double.tryParse(value);
                          setControllerInput(uid: data.uid, value: value);
                          setControllerResult(
                            uid: data.uid,
                            value: doubleValue ?? 'Y',
                          );
                        }
                        setControllerInput(uid: data.uid, value: value);
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                  ElevatedButton(
                    child: const Text('Clear data entry'),
                    onPressed: () {
                      setState(() {
                        setControllerIsDataEntry(uid: data.uid, value: false);
                      });
                      setControllerIsDataEntry(uid: data.uid, value: false);
                      Navigator.of(context).pop();
                      showStandardDialog(data);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void showStandardDialog(NodeContents data) {
    String passiveEdgeResult = getPassiveEdgeResult(data);
    String groupsStringList = getGroupsStringList(data);
    if (groupsStringList.length > 0) {
      groupsStringList = 'Groups: ${groupsStringList}';
    }
    print('(FH7)${passiveEdgeResult}');
    showDialog<double>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateMain) {
            TextEditingController textEditingController = TextEditingController(
              text: data.input,
            );

            return AlertDialog(
              title: Text(passiveEdgeResult + '     ' + groupsStringList),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: textEditingController,
                    onChanged: (value) {
                      //1print('(FF12)');
                    },
                  ),

                  Row(
                    children: [
                      ElevatedButton(
                        child: const Text('Enter'),
                        onPressed: () {
                          String value = textEditingController!.text;
                          // double? doubleValue = double.tryParse(value);
                          //1print('(FF11)${value}++++${data.uid}');
                          double? doubleValue = double.tryParse(value);
                          setState(() {
                            if (doubleValue == null) {
                              setControllerKind(uid: data.uid, kind: ks);
                            } else {
                              setControllerKind(uid: data.uid, kind: kd);
                            }
                            setControllerInput(uid: data.uid, value: value);
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                      ElevatedButton(
                        child: const Text('Set data entry'),
                        onPressed: () async {
                          setState(() {
                            setControllerIsDataEntry(
                              uid: data.uid,
                              value: true,
                            );
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                      ElevatedButton(
                        child: const Text('Enter date'),
                        onPressed: () async {
                          setControllerKind(uid: data.uid, kind: kt);
                          DateTime? d = await selectDate();
                          setState(() {
                            if (d == null) {
                              setControllerInput(uid: data.uid, value: null);
                            } else {
                              setControllerInput(
                                uid: data.uid,
                                value: dateToString(d),
                              );
                            }
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton(
                        child: const Text('Add node'),
                        onPressed: () {
                          //1print('(FF13A)');

                          /*_controller.*/
                          addEdgeByData(
                            nodeA: data,
                            nodeB: NodeContents(
                              kind: kd,
                              uid: _uidMaster,
                              input: '',
                              isDataEntry: false,
                            ),
                            isActive: true,
                            label: '',
                          );
                          _uidMaster++;
                          // _nodes.clear();
                          // _edges.clear();
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton(
                        child: const Text('Nullify node'),
                        onPressed: () {
                          setState(() {
                            //1print('(FF410)');
                            setControllerInput(uid: data.uid, value: '');
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                      ElevatedButton(
                        child: const Text('Delete node'),
                        onPressed: () {
                          setState(() {
                            //1print('(FF411)${data.uid}');
                            for (
                              int i = 0;
                              i < _controller.graph.groups.length;
                              i++
                            ) {
                              if (_controller.graph.groups[i].groupNodeUid ==
                                  data.uid) {
                                _controller.graph.groups.removeAt(i);
                                break;
                              } else {
                                for (
                                int j = 0;
                                j <
                                    _controller
                                        .graph
                                        .groups[i]
                                        .nodeUids!
                                        .length;
                                j++
                                ) {
                                  if (_controller.graph.groups[i]
                                      .nodeUids![j] ==
                                      data.uid) {
                                    _controller.graph.groups[i].nodeUids!
                                        .removeAt(j);

                                    break;
                                  }
                                }
                              }
                            }
                            for (
                              int i = 0;
                              i < _controller.graph.edges.length;
                              i++
                            ) {
                              if ((_controller.graph.edges[i].a.data.uid ==
                                      data.uid) ||
                                  (_controller.graph.edges[i].b.data.uid ==
                                      data.uid)) {
                                //1print(
                                //1      '(FF412)${_controller.graph.edges[i].a.data.uid}....${_controller.graph.edges[i].b.data.uid}',
                                //1 );
                                /*_controller.*/
                                deleteEdgeByData(
                                  nodeA: _controller.graph.edges[i].a.data,
                                  nodeB: _controller.graph.edges[i].a.data,
                                );
                              }
                              //1print('(FF413)${data.uid}');
                              _controller.deleteNodeByData(data);
                            }
                            setControllerInput(uid: data.uid, value: null);
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton(
                        child: const Text('Set start node'),
                        onPressed: () {
                          setState(() {
                            //1print('(FF16)');
                            setControllerIsStartNode(
                              uid: data.uid!,
                              value: true,
                            );
                          });

                          Navigator.of(context).pop();
                        },
                      ),

                      ElevatedButton(
                        child: const Text('Set end node'),
                        onPressed: () {
                          //1print('(FF17)');
                          setState(() {
                            //1print('(FF16)');
                            setControllerIsEndNode(uid: data.uid!, value: true);
                          });

                          Navigator.of(context).pop();
                        },
                      ),
                      ElevatedButton(
                        child: const Text('Clear all node status'),
                        onPressed: () {
                          //1print('(FF17)');
                          clearAllNodeStatus();
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton(
                        child: const Text('Highlight node'),
                        onPressed: () {
                          setState(() {
                            setControllerIsHighlight(
                              uid: data.uid!,
                              value: true,
                            );
                          });

                          Navigator.of(context).pop();
                        },
                      ),
                      (data.kind == kg)
                          ? ElevatedButton(
                              child: const Text('Goto group'),
                              onPressed: () {
                                chosenGroup = getGroupFromNodeUid(data.uid)!;
                                debugPrint('(FFP1)${chosenGroup.name}');
                                Navigator.of(context).pop();
                                showGroupsDialog();
                              },
                            )
                          : Container(),
                      ElevatedButton(
                        child: const Text('Make chain'),
                        onPressed: () {
                          //1print('(FF700)');
                          NodeContents currentNodeContents = data;
                          double rootNodeX = getNodePosition(data.uid)!.x;
                          double rootNodeY = getNodePosition(data.uid)!.y;
                          int? replicationCount =
                              int.tryParse(textEditingController!.text) ?? 1;
                          for (int i = 0; i < replicationCount; i++) {
                            NodeContents nextNodeContents = NodeContents(
                              uid: _uidMaster,
                              kind: currentNodeContents.kind,
                              isDataEntry: false,
                            );
                            /*_controller.*/
                            addEdgeByData(
                              nodeA: currentNodeContents,
                              nodeB: nextNodeContents,
                              isActive: true,
                              label: '',
                            );
                            vector.Vector2 nextPos = vector.Vector2(
                              rootNodeX,
                              rootNodeY -
                                  ((i.toDouble() + 1) * chainYincrement),
                            );
                            //1print('(FF747)${rootNodeX}....${rootNodeY},,,,${nextPos}');
                            setNodePosition(nextNodeContents.uid, nextPos);
                            setControllerInput(
                              uid: nextNodeContents.uid,
                              value: currentNodeContents.input,
                            );
                            _uidMaster++;
                            currentNodeContents = nextNodeContents;
                          }

                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void onNodeTap(NodeContents data) {
    print('(FH6)${data.uid}....${data.isDataEntry}');
    if (data.isDataEntry ?? false) {
      showDataEntryDialog(data);
    } else {
      showStandardDialog(data);
    }
  }

  bool isUidEqual(NodeContents? n1, NodeContents? n2) {
    if ((n1 == null) || (n2 == null)) return false;
    if (n1.uid == n2.uid) return true;
    return false;
  }

  Widget drawNode(NodeContents data) {
    //1print('(FF430)${data.uid}');

    if (data.isDataEntry ?? false) {
      return Text((data.doubleResult ?? '').toString());
    } else {
      String inputString = data.input ?? '';
      print('(FG6)${data.uid}....${data.kind}');
      switch (data.kind) {
        case (ke):
          return Text('ERROR}....${inputString}>e${getResult(data)}');
        case (kg):
          final Group nullGroup = Group(name: 'NO GROUP');
          final String groupName =
              (((getGroupFromNodeUid(data.uid))?? nullGroup).name) ?? 'NO Group';
          return Text('G: ' + groupName);
        case (kd):
          print('(FFQ1)${data.uid}....${getResult(data)}');
          return Text('${inputString}>${getResult(data)}');
        case (kt):
          return Text('${inputString}>${getResult(data)}');
        case (ks):
          return Text('${inputString}>${getResult(data)}');
        case (null):
          return Text('NULL');
      }
    }
  }

  bool isVisibleAnyGroupsNode({int? nodeUid}) {
    bool inGroup = false;
    bool isVisible = false;
    for (int i = 0; i < _controller.graph.groups.length; i++) {
      for (int j = 0; j < _controller.graph.groups[i].nodeUids!.length; j++) {
        if (_controller.graph.groups[i].nodeUids![j] == nodeUid) {
          inGroup = true;
          if (_controller.graph.groups[i].isVisible!) {
            isVisible = true;
            break;
          }
        }
      }
    }
    return (isVisible || !inGroup);
  }

  String? getGroupNameFromGroupNodeUid(int uid) {
    String? groupName;
    for (int i = 0; i < _controller.graph.groups.length; i++) {
      if (_controller.graph.groups[i].groupNodeUid == uid) {
        groupName = _controller.graph.groups[i].name;
        break;
      }
    }
    return groupName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          _buildMenu(context),
          Expanded(
            child: TickerMode(
              enabled: _running,
              child: ForceDirectedGraphWidget(
                controller: _controller,

                onDraggingStart: (NodeContents data) {
                  setState(() {
                    if (data.kind == kg) {
                      String? groupName = getGroupNameFromGroupNodeUid(
                        data.uid!,
                      );
                      setGroupIsCollapsed(
                        groupName: groupName,
                        isCollapsed: false,
                      );
                    }
                    _draggingData = data;
                  });
                },
                onDraggingEnd: (NodeContents data) {
                  setState(() {
                    _draggingData = null;
                  });
                },
                onDraggingUpdate: (NodeContents data) {
                  debugPrint('(FJ1)${data.uid}');
                },
                nodesBuilder: (context, NodeContents data) {
                  Color color;
                  if (!isVisibleAnyGroupsNode(nodeUid: data.uid)) {
                    return Container();
                  }
                  for (int i = 0; i < _controller.graph.edges.length; i++) {
                    if (_controller.graph.edges[i].b.data.uid == data.uid) {
                      if ((_controller.graph.edges[i].a.data.kind == kt) &&
                          (_controller.graph.edges[i].edgeExtra.isActive!)) {
                        setControllerKind(uid: data.uid, kind: kt);
                        break;
                      }
                    }
                  }

                  switch (getNodeFromUid(data.uid)!.data.kind) {
                    case ke:
                      color = Colors.black;
                      break;
                    case kg:
                      color = Colors.brown;
                      break;
                    case kd:
                      color = Colors.purple;
                      break;
                    case kt:
                      color = Colors.red;
                      break;
                    case ks:
                      color = Colors.green;
                      break;
                    case null:
                      color = Colors.black;
                      break;
                  }
                  //1print(
                  //1 '(FF800)${data.uid}....${data.isStartNode},,,,${data.isEndNode}++++${setBoxColor(data)}',
                  //1 );
                  double resultWidth = 0;
                  bool isInCollapsedGroup = false;
                  for (int i = 0; i < _controller.graph.groups.length; i++) {
                    if (_controller.graph.groups[i].groupNodeUid != null) {
                      for (
                        int j = 0;
                        j < (_controller.graph.groups[i].nodeUids ?? []).length;
                        j++
                      ) {
                        if ((_controller.graph.groups[i].nodeUids![j] ==
                                data.uid) &&
                            (_controller.graph.groups[i].isCollapsed ??
                                false)) {
                          isInCollapsedGroup = true;
                          break;
                        }
                      }
                    }
                  }
                  print('(FFQ2)${data.uid}....${isInCollapsedGroup}');
                  if (isInCollapsedGroup) {
                    resultWidth = 20;
                  } else {
                    switch (data.kind) {
                      case (ke):
                        resultWidth = 50;
                        break;
                      case (kg):
                        resultWidth = 80;
                        break;
                      case (kd):
                        resultWidth = 80;
                        break;
                      case (kt):
                        resultWidth = 150;
                        break;
                      case (ks):
                        resultWidth = 200;
                        break;
                        ;
                      case (null):
                        resultWidth = 50;
                        break;
                    }
                  }
                  double boxWidth =
                      ((data.input ?? '').length.toDouble() +
                      charWidth +
                      resultWidth);
                  print(
                    '(FG3)${data.uid}<<<<${(data.input ?? '').length.toDouble()}....${data.kind},,,,${boxWidth}',
                  );
                  return GestureDetector(
                    onTap: () {
                      //1print('(FF10)');
                      onNodeTap(data);
                    },

                    child: Row(
                      children: [
                        Container(
                          width: boxWidth + (boxPadding * 2) + 30,
                          height: 24,
                          decoration: BoxDecoration(
                            color: setBoxColor(data),
                            borderRadius: BorderRadius.circular(
                              (data.isDataEntry ?? false) ? 10 : 1,
                            ),
                            border: Border.all(color: color, width: 1),
                          ),
                          alignment: Alignment.center,
                          child: _scale > 0.5
                              ? Row(
                                  children: [
                                    Container(
                                      width: boxWidth,
                                      height: 22,
                                      //     color: Colors.amber,
                                      child: drawNode(data),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ],
                    ),
                  );
                },
                edgesBuilder: (context, a, b, distance) {
                  Color color = Colors.black87;
                  if ((!isVisibleAnyGroupsNode(nodeUid: a.uid!)) ||
                      (!isVisibleAnyGroupsNode(nodeUid: b.uid))) {
                    return Container();
                  }
                  if ((isUidEqual(edgeInputNodeContentsA, a)) &&
                      (isUidEqual(edgeInputNodeContentsB, b)))
                    color = Colors.red;
                  if ((isUidEqual(edgeCommonNodeContentsA, a)) &&
                      (isUidEqual(edgeCommonNodeContentsB, b)))
                    color = Colors.blue;
                  if ((isUidEqual(edgeOutputNodeContentsA, a)) &&
                      (isUidEqual(edgeOutputNodeContentsB, b)))
                    color = Colors.green;
                  print(
                    '(FF762)${a.uid}....${b.uid},,,,${isEdgeActive(uidA: a.uid, uidB: b.uid)}',
                  );
                  //dumpGraph();
                  if (!isEdgeActive(uidA: a.uid, uidB: b.uid)) {
                    color = Colors.grey;
                  }
                  Widget aE = arrowEdge(
                    distance: distance,
                    a: a,
                    b: b,
                    color: color,
                    label: getEdgeLabel(uidA: a.uid, uidB: b.uid),

                    // ),
                  );
                  return aE;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void deleteEdge({NodeContents? a, NodeContents? b}) {
    for (int i = 0; i < _controller.graph.edges.length; i++) {
      if ((_controller.graph.edges[i].a.data.uid == a!.uid) &&
          (_controller.graph.edges[i].b.data.uid == b!.uid)) {
        _controller.deleteEdge(_controller.graph.edges[i]);
      }
    }
  }

  void deleteEdgeByUid({int? uidA, int? uidB}) {
    for (int i = 0; i < _controller.graph.edges.length; i++) {
      if ((_controller.graph.edges[i].a.data.uid == uidA!) &&
          (_controller.graph.edges[i].b.data.uid == uidB!)) {
        _controller.deleteEdge(_controller.graph.edges[i]);
      }
    }
  }

  Widget arrowEdge({
    NodeContents? a,
    NodeContents? b,
    double distance = 0,
    color = Colors.black87,
    required String? label,
  }) {
    double angle = 0;
    bool reverse = false;
    if (getX(uid: a!.uid)! > getX(uid: b!.uid)!) {
      angle = pi;
      reverse = true;
    }
    print('(FF2)${distance}....${reverse}');

    Widget arrow = Transform.rotate(
      angle: angle,
      child: ClipPath(
        clipper: DrawArrow(a: a, b: b),
        child: GestureDetector(
          onTap: () {
            showDialog<double>(
              context: context,
              builder: (BuildContext context) {
                TextEditingController labelController = TextEditingController(
                  text: label ?? '',
                );
                return AlertDialog(
                  title: const Text('Edge operations'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: labelController,
                        onChanged: (value) {},
                      ),

                      ElevatedButton(
                        child: const Text('Set label'),
                        onPressed: () {
                          setState(() {
                            setEdgeLabel(
                              uidA: a.uid,
                              uidB: b.uid,
                              label: labelController.text,
                            );
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            child: const Text('Delete edge'),
                            onPressed: () {
                              deleteEdge(a: a, b: b);
                              Navigator.of(context).pop();
                            },
                          ),
                          ElevatedButton(
                            child: const Text('Reverse edge'),
                            onPressed: () {
                              /*_controller.*/
                              EdgeExtra edgeExtra = getEdgeExtraFromNodeUids(
                                uidA: a.uid,
                                uidB: b.uid,
                              )!;
                              deleteEdgeByData(nodeA: a, nodeB: b);
                              /*_controller.*/
                              addEdgeByData(
                                nodeA: b,
                                nodeB: a,
                                isActive: edgeExtra.isActive,
                                label: edgeExtra.label,
                              );
                              Navigator.of(context).pop();
                            },
                          ),

                          ElevatedButton(
                            child: isEdgeActive(uidA: a.uid, uidB: b.uid)
                                ? Text('Make passive')
                                : Text('Make active'),
                            onPressed: () {
                              //1print(
                              //1  '(FF763)${isEdgeActive(uidA: a.uid, uidB: b.uid)}',
                              //1);
                              setEdgeExtraIsActive(
                                uidA: a.uid,
                                uidB: b.uid,
                                isActive: !isEdgeActive(
                                  uidA: a.uid,
                                  uidB: b.uid,
                                ),
                              );
                              //1print(
                              //1  '(FF76)${a.uid}....${b.uid},,,,${isEdgeActive(uidA: a.uid, uidB: b.uid)}',
                              //1);
                              //dumpGraph();
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            child: const Text('Set as input'),
                            onPressed: () {
                              edgeInputNodeContentsA = a;
                              edgeInputNodeContentsB = b;
                              Navigator.of(context).pop();
                            },
                          ),
                          ElevatedButton(
                            child: const Text('Set as common'),
                            onPressed: () {
                              edgeCommonNodeContentsA = a;
                              edgeCommonNodeContentsB = b;
                              Navigator.of(context).pop();
                            },
                          ),
                          ElevatedButton(
                            child: const Text('Set as output'),
                            onPressed: () {
                              edgeOutputNodeContentsA = a;
                              edgeOutputNodeContentsB = b;
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                      ElevatedButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
          child: Container(
            width: distance,
            height: boxHeight * 2,
            color: color,
          ),
        ),
      ),
    );
    return Container(
      child: Column(
        children: [
          Text(getEdgeLabel(uidA: a.uid, uidB: b.uid) ?? '.'),
          arrow,
        ],
      ),
    );
  }

  void addEdges(bool isActive) {
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.isStartNode ?? false)
        for (int j = 0; j < _controller.graph.nodes.length; j++) {
          if (_controller.graph.nodes[j].data.isEndNode ?? false) {
            addEdgeByData(
              nodeA: _controller.graph.nodes[i].data,
              nodeB: _controller.graph.nodes[j].data,
              isActive: isActive,
              label: '',
            );
          }
        }
    }
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      setControllerIsStartNode(
        uid: _controller.graph.nodes[i].data.uid,
        value: false,
      );
      setControllerIsEndNode(
        uid: _controller.graph.nodes[i].data.uid,
        value: false,
      );
    }
    setState(() {});
  }

  void alignHoriz() {
    double topY = double.maxFinite;
    double topX = 0.0;
    int? topUid;
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.isHighlight ?? false) {
        if (_controller.graph.nodes[i].position.y < topY) {
          topY = _controller.graph.nodes[i].position.y;
          topX = _controller.graph.nodes[i].position.x;
          topUid = i;
        }
      }
    }
    if (topUid != null) {
      for (int i = 0; i < _controller.graph.nodes.length; i++) {
        if (_controller.graph.nodes[i].data.isHighlight ?? false) {
          print('(FG50)${i}....${_controller.graph.nodes[i].position.x}');
          _controller.graph.nodes[i].position.x = topX;
          print('(FG51)${i}....${_controller.graph.nodes[i].position.x}');
        }
      }
    }

    setState(() {});
  }

  void setGroupIsVisible({String? groupName, bool? value}) {
    for (int i = 0; i < _controller.graph.groups.length; i++) {
      print(
        '(FH87A)${i},,,,${groupName}....${_controller.graph.groups[i].name}',
      );
      if (groupName == _controller.graph.groups[i].name) {
        _controller.graph.groups[i].isVisible = value;
        print('(FH87A)${i},,,,${_controller.graph.groups[i].isVisible}');
      }
    }
  }

  void setGroupNodeUid({String? groupName, int? nodeUid}) {
    for (int i = 0; i < _controller.graph.groups.length; i++) {
      print(
        '(FH187A)${i},,,,${groupName}....${_controller.graph.groups[i].name}',
      );
      if (groupName == _controller.graph.groups[i].name) {
        _controller.graph.groups[i].groupNodeUid = nodeUid;
        print('(FH187A)${i},,,,${_controller.graph.groups[i].groupNodeUid}');
      }
    }
  }

  void setGroupIsCollapsed({String? groupName, bool? isCollapsed}) {
    for (int i = 0; i < _controller.graph.groups.length; i++) {
      print(
        '(FH187A)${i},,,,${groupName}....${_controller.graph.groups[i].name}',
      );
      if (groupName == _controller.graph.groups[i].name) {
        _controller.graph.groups[i].isCollapsed = isCollapsed;
        print('(FH187B)${i},,,,${_controller.graph.groups[i].isCollapsed}');
      }
    }
  }

  void addNodeToGroup({String? groupName, int? nodeUid}) {
    if ((groupName == null) || (nodeUid == null)) {
      return;
    }
    print('(FH8AA)');
    for (int i = 0; i < _controller.graph.groups.length; i++) {
      print('(FH8AB)');
      if (groupName == _controller.graph.groups[i].name) {
        print('(FH8B)${i}....${_controller.graph.groups[i].nodeUids!.length}');
        if (_controller.graph.groups[i].nodeUids!.length == 0) {
          _controller.graph.groups[i].nodeUids!.add(nodeUid);
        } else {
          bool found = false;
          for (
            int j = 0;
            j < _controller.graph.groups[i].nodeUids!.length;
            j++
          ) {
            print('(FH8C)');
            if (_controller.graph.groups[i].nodeUids![j] == nodeUid) {
              print('(FH8D)');
              found = true;
            }
          }
          if (!found) {
            _controller.graph.groups[i].nodeUids!.add(nodeUid);
            print('(FH8E)${_controller.graph.groups[i].nodeUids}');
          }
        }
      }
    }
  }

  void removeNodeFromGroup({String? groupName, int? nodeUid}) {
    if ((groupName == null) || (nodeUid == null)) {
      return;
    }
    print('(FH6A)');
    for (int i = 0; i < _controller.graph.groups.length; i++) {
      print('(FH6A)');
      if (groupName == _controller.graph.groups[i].name) {
        print('(FH6B)${i}....${_controller.graph.groups[i].nodeUids!.length}');
        if (_controller.graph.groups[i].nodeUids!.length == 0) {
          _controller.graph.groups[i].nodeUids!.add(nodeUid);
        } else {
          bool found = false;
          for (
            int j = 0;
            j < _controller.graph.groups[i].nodeUids!.length;
            j++
          ) {
            print('(FH6C)');
            if (_controller.graph.groups[i].nodeUids![j] == nodeUid) {
              print('(FH6D)');
              found = true;
            }
          }
          if (!found) {
            _controller.graph.groups[i].nodeUids!.remove(nodeUid);
            print('(FH6E)${_controller.graph.groups[i].nodeUids}');
          }
        }
      }
    }
  }

  int? getGroupIndexFromName(String groupName) {
    for (int i = 0; i < _controller.graph.groups.length; i++) {
      if (_controller.graph.groups[i].name == groupName) {
        return i;
      }
    }
  }

  void clearAllNodeStatus() {
    setState(() {
      //1print('(FF16)');
      for (int i = 0; i < _controller.graph.nodes.length; i++) {
        int uid = _controller.graph.nodes[i].data.uid!;
        setControllerIsStartNode(uid: uid, value: false);
        setControllerIsEndNode(uid: uid, value: false);
        setControllerIsHighlight(uid: uid, value: false);
      }
    });
  }

  void reconnectNodesThroughGroupNode(int groupNodeUid) {
    for (int i = 0; i < _controller.graph.edges.length; i++) {
      Edge edge = _controller.graph.edges[i];
      int uidA = edge.a.data.uid!;
      int uidB = edge.b.data.uid!;
      bool aInGroup = chosenGroup.nodeUids!.contains(uidA);
      bool bInGroup = chosenGroup.nodeUids!.contains(uidB);
      bool aOrBIsGroupNode =
          ((chosenGroup.groupNodeUid == uidA) ||
          (chosenGroup.groupNodeUid == uidB));
      debugPrint(
        '(FQ1)${i}.${edge.edgeExtra.label},${uidA};${uidB}:${aInGroup}@${bInGroup}',
      );
      if (aOrBIsGroupNode ||
          (aInGroup && bInGroup) ||
          (!aInGroup && !bInGroup)) {
        //DO NOTHING
      } else {
        int groupIndex = getGroupIndexFromName(chosenGroup.name!)!;
        if (aInGroup) {
          //_controller.graph.edges[i].b.data.uid = groupNodeUid;
          debugPrint('(FQ6)${groupIndex}|${groupNodeUid}');
          // _controller.graph.edges[i].a.data.uid = groupNodeUid;
          addEdgeByData(
            nodeA: getNodeFromUid(uidA)!.data,
            nodeB: getNodeFromUid(groupNodeUid)!.data,
            isActive: edge.edgeExtra.isActive,
            label: edge.edgeExtra.label,
          );
          debugPrint('(FQ5)${groupIndex}|${groupNodeUid}}');
          addEdgeByData(
            nodeA: getNodeFromUid(groupNodeUid)!.data,
            nodeB: getNodeFromUid(uidB)!.data,
            isActive: edge.edgeExtra.isActive,
            label: edge.edgeExtra.label,
          );
          deleteEdgeByUid(uidA: uidA, uidB: uidB);
          _controller.graph.groups[groupIndex].outgoingLabels =
              ((_controller.graph.groups[groupIndex].outgoingLabels) ?? '') +
              ((edge.edgeExtra.label) ?? '') +
              ',';
          debugPrint('(FQ9)${groupIndex}');
        } else {
          debugPrint('(FQ3)${groupIndex}|${groupNodeUid}}');
          // _controller.graph.edges[i].a.data.uid = groupNodeUid;
          addEdgeByData(
            nodeA: getNodeFromUid(groupNodeUid)!.data,
            nodeB: getNodeFromUid(uidB)!.data,
            isActive: edge.edgeExtra.isActive,
            label: edge.edgeExtra.label,
          );
          debugPrint('(FQ5)${groupIndex}|${groupNodeUid}}');
          addEdgeByData(
            nodeA: getNodeFromUid(uidA)!.data,
            nodeB: getNodeFromUid(groupNodeUid)!.data,
            isActive: edge.edgeExtra.isActive,
            label: edge.edgeExtra.label,
          );
          deleteEdgeByUid(uidA: uidA, uidB: uidB);
          _controller.graph.groups[groupIndex].incomingLabels =
              (_controller.graph.groups[groupIndex].incomingLabels) ??
              '' + ((edge.edgeExtra.label) ?? '') + ',';
          debugPrint('(FQ7)${groupIndex}|${groupNodeUid}}');
        }
      }
    }
  }

  void showGroupsDialog() {
    // bool? chosenGroupIsVisible;
    const String kCreateGroupButtonCaption = 'Create group';
    const String kCreateGroupButtonCaptionGroupExists = 'Group exists';

    String createGroupButtonCaption = kCreateGroupButtonCaption;
    if (_controller.graph.groups.length < 1)
      print('(FH80)${_controller.graph.groups.length}');
    else
      print(
        '(FH81)${_controller.graph.groups.length}...${_controller.graph.groups[0].name},,,,${chosenGroup.name}',
      );
    showDialog<double>(
      context: context,
      builder: (BuildContext context) {
        debugPrint('(FI7)${createGroupButtonCaption}');
        return StatefulBuilder(
          builder: (context, setStateMain) {
            return AlertDialog(
              title: Text('Group: ${(chosenGroup ?? nullGroup).name}'),
              content: Column(
                children: [
                  (_controller.graph.groups.length < 1)
                      ? Text('No groups')
                      : DropdownButton<Group>(
                          //  key: ValueKey(widget),
                          value: chosenGroup,
                          hint: const Text('Please select group'),
                          items: _controller.graph.groups
                              .map<DropdownMenuItem<Group>>((Group item) {
                                return DropdownMenuItem<Group>(
                                  value: item,
                                  child: Text(item.name!),
                                );
                              })
                              .toList(),
                          elevation: 2,
                          onChanged: (value) {
                            setState(() {
                              chosenGroup = value!;
                            });
                            setStateMain(() {});
                            print(
                              '(FH352)${value!.name}....${value.isVisible}',
                            );
                          },
                          isExpanded: true,
                          focusColor: Colors.transparent,
                        ),
                  ElevatedButton(
                    onPressed: () {
                      print('(FH9A)');
                      setState(() {
                        for (
                          int i = 0;
                          i < _controller.graph.nodes.length;
                          i++
                        ) {
                          print('(FH9B)${chosenGroup}');
                          print(
                            '(FH9C)${chosenGroup!.name},,,,${i}....${_controller.graph.nodes[i].data.isHighlight}',
                          );
                          if ((_controller.graph.nodes[i].data.isHighlight) ??
                              false) {
                            if (chosenGroup == nullGroup) {
                              toastification.show(
                                context: context,
                                title: Text('Select group before adding nodes'),
                              );
                            } else {
                              print(
                                '(FH9D)${_controller.graph.nodes[i].data.uid}',
                              );
                              addNodeToGroup(
                                groupName: chosenGroup!.name,
                                nodeUid: _controller.graph.nodes[i].data.uid,
                              );
                            }
                          }
                        }
                        for (Group group in _controller.graph.groups) {
                          print('(FH10)${group.name}....${group.nodeUids}');
                        }
                      });
                      setStateMain(() {});
                      Navigator.of(context).pop();
                    },
                    child: Text('Add highlighted nodes to group'),
                  ),

                  ElevatedButton(
                    onPressed: () {
                      print('(FH9A)');
                      setState(() {
                        for (
                          int i = 0;
                          i < _controller.graph.nodes.length;
                          i++
                        ) {
                          print('(FH9B)${chosenGroup}');
                          print(
                            '(FH9C)${chosenGroup!.name},,,,${i}....${_controller.graph.nodes[i].data.isHighlight}',
                          );
                          if ((_controller.graph.nodes[i].data.isHighlight) ??
                              false) {
                            if (chosenGroup == nullGroup) {
                              toastification.show(
                                context: context,
                                title: Text(
                                  'Select group before removing nodes',
                                ),
                              );
                              print(
                                '(FH91)${_controller.graph.nodes[i].data.uid}',
                              );
                            } else {
                              removeNodeFromGroup(
                                groupName: chosenGroup!.name,
                                nodeUid: _controller.graph.nodes[i].data.uid,
                              );
                            }
                          }
                        }
                        for (Group group in _controller.graph.groups) {
                          print('(FH10)${group.name}....${group.nodeUids}');
                        }
                      });
                      Navigator.of(context).pop();
                    },
                    child: Text('Remove highlighted nodes from group'),
                  ),

                  ElevatedButton(
                    onPressed: () {
                      clearAllNodeStatus();
                      print('(FH9A)');
                      setState(() {
                        for (
                          int i = 0;
                          i < _controller.graph.nodes.length;
                          i++
                        ) {
                          for (
                            int j = 0;
                            j < _controller.graph.groups.length;
                            j++
                          ) {
                            for (
                              int k = 0;
                              k < _controller.graph.groups[j].nodeUids!.length;
                              k++
                            ) {
                              print(
                                '(FH30)${i}<${j}>${k}....${_controller.graph.groups[j].nodeUids},,,,${_controller.graph.nodes[i].data.uid}',
                              );

                              if (_controller.graph.groups[j].nodeUids![k] ==
                                  _controller.graph.nodes[i].data.uid) {
                                setState(() {
                                  _controller.graph.nodes[i].data.isHighlight =
                                      true;
                                  print(
                                    '(FH31)${i}<${j}>${k}....${_controller.graph.groups[j].nodeUids},,,,${_controller.graph.nodes[i].data.uid}',
                                  );
                                });
                                setStateMain(() {});
                              }
                            }
                          }
                        }
                      });
                      Navigator.of(context).pop();
                    },
                    child: Text('Highlight nodes of group'),
                  ),

                  ElevatedButton(
                    child: Text('Make group visible'),
                    onPressed: () {
                      if (chosenGroup == nullGroup) {
                        toastification.show(
                          context: context,
                          title: Text('Select group'),
                        );
                      } else {
                        setState(() {
                          setGroupIsVisible(
                            groupName: chosenGroup!.name,
                            value: true,
                          );
                        });
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                  ElevatedButton(
                    child: Text('Make group invisible'),
                    onPressed: () {
                      if (chosenGroup == nullGroup) {
                        toastification.show(
                          context: context,
                          title: Text('Select group'),
                        );
                      } else {
                        setState(() {
                          setGroupIsVisible(
                            groupName: chosenGroup.name,
                            value: false,
                          );
                        });
                        print(
                          '(FH40)${chosenGroup.name}....${_controller.graph.groups}',
                        );
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  ElevatedButton(
                    child: Text('Collapse group'),

                    onPressed: () {
                      debugPrint('(FI22)${chosenGroup}');
                      debugPrint(
                        '(FI23)${chosenGroup.nodeUids}....${chosenGroup.name}',
                      );
                      if (chosenGroup == nullGroup) {
                        toastification.show(
                          context: context,
                          title: Text('Select group'),
                        );
                      } else {
                        if (chosenGroup.groupNodeUid != null) {
                          vector.Vector2 pos = getNodeFromUid(
                            chosenGroup.groupNodeUid,
                          )!.position;
                          for (
                            int i = 0;
                            i < chosenGroup.nodeUids!.length;
                            i++
                          ) {
                            setNodePosition(chosenGroup.nodeUids![i], pos);
                            print(
                              '(FI31B)${i}....${chosenGroup.nodeUids![i]},,,,${pos}',
                            );
                          }
                        } else {
                          double topY = -double.maxFinite;
                          double topX = 0.0;
                          int? topUid;
                          List<int> nodeUids = chosenGroup.nodeUids!;
                          for (int i = 0; i < nodeUids.length; i++) {
                            print('(FI24A)${topY}....${i},,,,${nodeUids}');
                            double y = getNodeFromUid(nodeUids[i])!.position.y;
                            print('(FI24B)${topY}....${i},,,,${nodeUids}');
                            double x = getNodeFromUid(nodeUids[i])!.position.x;
                            print('(FI24C)${topY}....${i},,,,${nodeUids}');

                            if (y > topY) {
                              topY = y;
                              topX = x;
                              topUid = nodeUids[i];
                            }
                          }
                          debugPrint('(FI11)${topX}....${topY}...${topUid}');
                          int groupNodeUid = createNode(
                            kind: kg,
                            isDataEntry: false,
                          );
                          debugPrint('(FI12)${topX}....${topY}...${topUid}');
                          setGroupNodeUid(
                            groupName: chosenGroup.name,
                            nodeUid: groupNodeUid,
                          );
                          addNodeToGroup(
                            groupName: chosenGroup.name,
                            nodeUid: groupNodeUid,
                          );
                          setGroupIsCollapsed(
                            groupName: chosenGroup.name,
                            isCollapsed: true,
                          );
                          debugPrint('(FI13)${topX}....${topY}...${topUid}');
                          setNodePosition(
                            groupNodeUid,
                            vector.Vector2(topX, topY),
                          );
                          debugPrint(
                            '(FI14)${topX}....${topY}...${topUid}????${nodeUids}',
                          );
                          setState(() {
                            for (int i = 0; i < nodeUids.length; i++) {
                              setNodePosition(
                                nodeUids[i],
                                vector.Vector2(topX, topY),
                              );
                              print(
                                '(FI31)${i}....${nodeUids[i]},,,,${topX}<<<<${topY}',
                              );
                            }
                          });
                          print(
                            '(FH40)${chosenGroup.name}....${_controller.graph.groups}',
                          );
                        }
                        reconnectNodesThroughGroupNode(
                          chosenGroup.groupNodeUid!,
                        );
                      }

                      setState(() {});
                      dumpGraph();
                      Navigator.of(context).pop();
                    },
                  ),

                  ElevatedButton(
                    onPressed: () async {
                      print('(FH99)');
                      String json = _controller.groupToJson(
                        groupName: chosenGroup.name!,
                      );
                      print('(FH99)${json}');
                      var result = await databases!.createDocument(
                        databaseId: kDatabaseID,
                        collectionId: kGroups,
                        documentId: ID.unique(),
                        data: {
                          "filename": chosenGroup.name,
                          "json": json,
                          "buildNumber": buildNumber,
                        },
                        // permissions: [Permission.read(Role.any())], // optional
                        // transactionId: '<TRANSACTION_ID>', // optional
                      );
                      Navigator.of(context).pop();
                    },
                    child: Text('Save group'),
                  ),
                  Text('Incoming labels: ${chosenGroup.incomingLabels ?? ""}'),
                  Text('Outgoing labels: ${chosenGroup.outgoingLabels ?? ""}'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void showCreateGroupDialog() {
    // bool? chosenGroupIsVisible;
    const String kCreateGroupButtonCaption = 'Create group';
    const String kCreateGroupButtonCaptionGroupExists = 'Group exists';

    String createGroupButtonCaption = kCreateGroupButtonCaption;
    if (_controller.graph.groups.length < 1)
      print('(FH80)${_controller.graph.groups.length}');
    else
      print(
        '(FH81)${_controller.graph.groups.length}...${_controller.graph.groups[0].name},,,,${chosenGroup.name}',
      );
    showDialog<double>(
      context: context,
      builder: (BuildContext context) {
        debugPrint('(FI7)${createGroupButtonCaption}');
        return StatefulBuilder(
          builder: (context, setStateMain) {
            return AlertDialog(
              title: Text('Create group'),
              content: Column(
                children: [
                  ///////
                  TextField(
                    controller: groupNameTextEditingController,
                    onChanged: (value) async {
                      bool found = false;
                      for (
                        int i = 0;
                        i < _controller.graph.groups.length;
                        i++
                      ) {
                        debugPrint(
                          '(FI4)${groupNameTextEditingController.text}....${_controller.graph.groups[i].name}',
                        );
                        if (groupNameTextEditingController.text ==
                            _controller.graph.groups[i].name) {
                          found = true;
                          break;
                        }
                      }

                      debugPrint(
                        '(FI3)${found}////${createGroupButtonCaption}',
                      );
                      setState(() {
                        if (found) {
                          createGroupButtonCaption =
                              kCreateGroupButtonCaptionGroupExists;
                        } else {
                          createGroupButtonCaption = kCreateGroupButtonCaption;
                        }
                      });
                    },
                  ),
                  ElevatedButton(
                    onPressed: () {
                      debugPrint('(FI6)${createGroupButtonCaption}');
                      bool found = false;
                      for (
                        int i = 0;
                        i < _controller.graph.groups.length;
                        i++
                      ) {
                        debugPrint(
                          '(FI2)${groupNameTextEditingController.text}....${_controller.graph.groups[i].name}',
                        );
                        if (groupNameTextEditingController.text ==
                            _controller.graph.groups[i].name) {
                          found = true;
                          break;
                        }
                      }
                      if (found) {
                        setState(() {
                          createGroupButtonCaption =
                              kCreateGroupButtonCaptionGroupExists;
                        });
                      } else {
                        setState(() {
                          _controller.graph.groups.add(
                            Group(
                              name: groupNameTextEditingController.text,
                              nodeUids: [],
                              isVisible: true,
                            ),
                          );
                          setGroupIsCollapsed(
                            groupName: groupNameTextEditingController.text,
                            isCollapsed: false,
                          );
                          chosenGroup = _controller.graph.groups.last;
                          int groupNodeUid = createNode(
                            kind: kg,
                            isDataEntry: false,
                          );
                          setGroupNodeUid(
                            groupName: chosenGroup.name,
                            nodeUid: groupNodeUid,
                          );
                          addNodeToGroup(
                            groupName: chosenGroup.name,
                            nodeUid: groupNodeUid,
                          );
                          debugPrint(
                            '(FI1)${groupNodeUid}....${chosenGroup.name},,,,${getGroupFromGroupName(chosenGroup.name)!.nodeUids}',
                          );
                        });
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(createGroupButtonCaption),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void showLoadGroupDialog() async {
    models.DocumentList result = await databases!.listDocuments(
      databaseId: kDatabaseID,
      collectionId: kGroups,
    );
    print('(FR1)${result.total}');
    print('(FR2)${result.documents.first}');
    print('(FR3)${result.documents.first.data}');

    models.Document? chosenGroupDocument;
    showDialog<double>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateMain) {
            return AlertDialog(
              title: Text('Load group'),
              content: Column(
                children: [
                  (result.total < 1)
                      ? Text('No groups')
                      : DropdownButton<models.Document>(
                          //  key: ValueKey(widget),
                          value: result.documents[0],
                          hint: const Text('Please select group'),
                          items: result.documents
                              .map<DropdownMenuItem<models.Document>>((
                                models.Document item,
                              ) {
                                return DropdownMenuItem<models.Document>(
                                  value: item,
                                  child: Text((item.data['filename']) ?? '?'),
                                );
                              })
                              .toList(),
                          elevation: 2,
                          onChanged: (value) {
                            setState(() {
                              chosenGroupDocument = value;
                            });
                            setStateMain(() {});
                            if (chosenGroupDocument == null) {
                              debugPrint('(FH352A)');
                            } else {
                              debugPrint(
                                '(FH352B)${chosenGroupDocument!.data}....${_uidMaster}',
                              );
                            }
                          },
                          isExpanded: true,
                          focusColor: Colors.transparent,
                        ),
                  ElevatedButton(
                    child: const Text('Load'),
                    onPressed: () async {
                      String json = chosenGroupDocument!.data['json'];
                      _controller.graph.addToGraphfromJson(
                        json,
                        deserializeData3: deserializeNodeContents,
                      );
                      // _uidMaster = _controller.graph.addGroupToGraph(
                      //   json,
                      //   deserializeData3: deserializeNodeContents,
                      //   uidMaster: _uidMaster,
                      // );
                      //   for (bool node in decodedRawJson['nodes']){
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  int createNode({NodeKind? kind, bool? isDataEntry = false}) {
    int current_uid = _uidMaster;
    NodeContents n = NodeContents(
      uid: current_uid,
      kind: kind,
      isDataEntry: false,
    );
    _controller.addNode(n);
    print('(FJ51)${n.uid}....${n.kind}');
    dumpGraph();
    _uidMaster++;
    return current_uid;
  }

  Widget _buildMenu(BuildContext context) {
    return Wrap(
      children: [
        ElevatedButton(
          onPressed: () {
            /*  NodeContents n = NodeContents(
              uid: _uidUid,
              kind: kd,
              isDataEntry: false,
              nodeFunction: NodeFunction.add,
            );
            _controller.addNode(n);
            _uidUid++;*/
            createNode(kind: kd, isDataEntry: false);
          },
          child: const Text('add node'),
        ),
        ElevatedButton(
          onPressed: () {
            /*for (var node in _controller.graph.nodes) {
              if (_running) {
                node.static();
              } else {
                node.unStatic();
              }
            }*/

            setState(() {
              _running = !_running;
            });
          },
          child: _running ? Text('stop') : Text('start'),
        ),

        ElevatedButton(
          onPressed: () {
            _controller.center();
          },
          child: const Text('center'),
        ),
        ElevatedButton(
          onPressed: () {
            print('2');
            dumpGraph();
          },
          child: Text('dump'),
        ),
        ElevatedButton(
          onPressed: () async {
            bool overwriteFlag = false;
            /*   setState(() {*/
            /*              if (_json != null) {
                _controller.graph = ForceDirectedGraph.fromJson(
                  _json!,
                  */ /*deserializeData: NodeContents.fromJson*/ /*
                );*/
            showDialog<double>(
              context: context,
              builder: (BuildContext context) {
                return StatefulBuilder(
                  builder: (context, setStateMain) {
                    return AlertDialog(
                      title: const Text('Save spreadsheet'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          (overwriteFlag) ? Text('File exists') : Text('X '),
                          TextField(
                            controller: filenameTextEditingController,
                            onChanged: (value) async {
                              //1print('(FF121)${value}');
                              models.DocumentList result = await databases!
                                  .listDocuments(
                                    databaseId: kDatabaseID,
                                    collectionId: kSpreadsheets,
                                    queries: [
                                      Query.equal(kColumnFilename, value),
                                    ],
                                    // ttl: 0, // optional
                                  );
                              //1print(
                              //1  '(FF122)${result.total}....${overwriteFlag}',
                              //1);
                              setState(() {
                                if (result.total > 0) {
                                  overwriteFlag = true;
                                } else {
                                  overwriteFlag = false;
                                }
                              });
                            },
                          ),
                          ElevatedButton(
                            child: const Text('save'),
                            onPressed: () async {
                              _json = _controller.toJson();
                              print('(FF710)${_json}');
                              var result = await databases!.createDocument(
                                databaseId: kDatabaseID,
                                collectionId: kSpreadsheets,
                                documentId: ID.unique(),
                                data: {
                                  "filename":
                                      filenameTextEditingController.text,
                                  "json": _json,
                                  "buildNumber": buildNumber,
                                },
                                // permissions: [Permission.read(Role.any())], // optional
                                // transactionId: '<TRANSACTION_ID>', // optional
                              );
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
          child: Text('save'),
        ),

        ElevatedButton(
          onPressed: () async {
            models.DocumentList? docs;
            docs = await databases!.listDocuments(
              databaseId: kDatabaseID,
              collectionId: kSpreadsheets,
              queries: [Query.limit(100)],
            );
            models.Document? chosenDocument;
            if (docs.total > 0) {
              chosenDocument = docs.documents[0];
            }
            showDialog<double>(
              context: context,
              builder: (BuildContext context) {
                return StatefulBuilder(
                  builder: (context, setStateMain) {
                    return AlertDialog(
                      title: const Text('Load spreadsheet'),

                      content: (chosenDocument == null)
                          ? Text('No files')
                          : Column(
                              children: [
                                DropdownButton<models.Document>(
                                  //  key: ValueKey(widget),
                                  value: chosenDocument,
                                  hint: const Text('Please select filename'),
                                  items: docs!.documents
                                      .map<DropdownMenuItem<models.Document>>((
                                        models.Document item,
                                      ) {
                                        return DropdownMenuItem<
                                          models.Document
                                        >(
                                          value: item,
                                          child: Text(item.data['filename']),
                                        );
                                      })
                                      .toList(),
                                  elevation: 2,
                                  onChanged: (value) {
                                    setState(() {
                                      chosenDocument = value!;
                                    });
                                    print('(FF352)${value!.data['filename']}');
                                  },
                                  isExpanded: true,
                                  focusColor: Colors.transparent,
                                ),

                                ElevatedButton(
                                  onPressed: () {
                                    String chosenFilename =
                                        chosenDocument!.data['filename'];
                                    _controller.graph.nodes.clear();
                                    _controller.graph.edges.clear();
                                    _uidMaster = 0;
                                    print(
                                      '(FF350)${chosenDocument!.data['json']}',
                                    );
                                    setState(() {
                                      _controller
                                          .graph = ForceDirectedGraph.fromJson(
                                        chosenDocument!.data['json'],
                                        deserializeData3:
                                            deserializeNodeContents, //as NodeDataDeserializer<NodeContents>,
                                      );
                                      int maxUid = 0;
                                      for (
                                        int i = 0;
                                        i < _controller.graph.nodes.length;
                                        i++
                                      ) {
                                        if (_controller
                                                .graph
                                                .nodes[i]
                                                .data
                                                .uid! >
                                            maxUid) {
                                          maxUid = _controller
                                              .graph
                                              .nodes[i]
                                              .data
                                              .uid!;
                                        }
                                      }
                                      _uidMaster = maxUid + 1;

                                      loadGroupsFromJson(
                                        chosenDocument!.data['json'],
                                      );

                                      Navigator.of(context).pop();
                                    });
                                  },
                                  child: Text('Confirm'),
                                ),
                              ],
                            ),
                    );
                  },
                );
              },
            );
          },

          child: Text('load'),
        ),

        ElevatedButton(
          onPressed: () async {
            models.DocumentList? docs;
            docs = await databases!.listDocuments(
              databaseId: kDatabaseID,
              collectionId: kSpreadsheets,
              queries: [Query.limit(100)],
            );
            models.Document? chosenDocument;
            if (docs.total > 0) {
              chosenDocument = docs.documents[0];
            }
            showDialog<double>(
              context: context,
              builder: (BuildContext context) {
                return StatefulBuilder(
                  builder: (context, setStateMain) {
                    return AlertDialog(
                      title: const Text('Delete spreadsheet'),
                      content: (chosenDocument == null)
                          ? Text('No files')
                          : Column(
                              children: [
                                DropdownButton<models.Document>(
                                  //  key: ValueKey(widget),
                                  value: chosenDocument,
                                  hint: const Text('Please select filename'),
                                  items: docs!.documents
                                      .map<DropdownMenuItem<models.Document>>((
                                        models.Document item,
                                      ) {
                                        return DropdownMenuItem<
                                          models.Document
                                        >(
                                          value: item,
                                          child: Text(item.data['filename']),
                                        );
                                      })
                                      .toList(),
                                  elevation: 2,
                                  onChanged: (value) {
                                    setState(() {
                                      chosenDocument = value!;
                                    });
                                    print('(FF352)${value!.data['filename']}');
                                  },
                                  isExpanded: true,
                                  focusColor: Colors.transparent,
                                ),

                                ElevatedButton(
                                  onPressed: () async {
                                    String chosenFilename =
                                        chosenDocument!.data['filename'];
                                    _controller.graph.nodes.clear();
                                    _controller.graph.edges.clear();
                                    print(
                                      '(FF360)${chosenDocument!.data['json']}',
                                    );

                                    await databases!.deleteDocument(
                                      databaseId: kDatabaseID,
                                      collectionId: kSpreadsheets,
                                      documentId: chosenDocument!.data['\$id'],
                                    );
                                    // setState((){});
                                    Navigator.of(context).pop();
                                  },
                                  child: Text('Confirm'),
                                ),
                              ],
                            ),
                    );
                  },
                );
              },
            );
          },

          child: Text('delete'),
        ),

        ElevatedButton(
          onPressed: () {
            _controller.scale = 1;
            //1print('(FF741)${_controller.graph.nodes.length}');
            for (int i = 0; i < _controller.graph.nodes.length; i++) {
              NodeContents n = _controller.graph.nodes[i].data;
              //1print('(FF742)${i}....${n}');
              _controller.deleteNodeByData(n);
              //1print('(FF749)${i}');
            }
          },
          child: const Text('reset'),
        ),
        ElevatedButton(
          child: const Text('add edges'),
          onPressed: () {
            addEdges(true);
          },
        ),
        ElevatedButton(
          child: const Text('add passive edges'),
          onPressed: () {
            addEdges(false);
          },
        ),
        ElevatedButton(
          child: const Text('align horiz.'),
          onPressed: () {
            alignHoriz();
          },
        ),
        ElevatedButton(
          onPressed: () {
            for (int i = 0; i < _controller.graph.nodes.length; i++) {
              setControllerIsStartNode(
                uid: _controller.graph.nodes[i].data.uid!,
                value: false,
              );
              setControllerIsEndNode(
                uid: _controller.graph.nodes[i].data.uid!,
                value: false,
              );
              setControllerIsHighlight(
                uid: _controller.graph.nodes[i].data.uid!,
                value: false,
              );
            }
            setState(() {});
          },
          child: const Text('clear node status'),
        ),
        ElevatedButton(
          onPressed: () {
            // showGroupsDialog();
            showCreateGroupDialog();
          },
          child: const Text('create group'),
        ),
        ElevatedButton(
          onPressed: () {
            showLoadGroupDialog();
          },
          child: const Text('load group'),
        ),

        Slider(
          value: _scale,
          min: _controller.minScale,
          max: _controller.maxScale,
          onChanged: (value) {
            _controller.scale = value;
          },
        ),
      ],
    );
  }

  void _clearData() {
    // _nodes.clear();
    // _edges.clear();
    _locatedTo = 0;
  }
}

double? getX({int? uid}) {
  double? x;
  for (var node in _controller.graph.nodes) {
    if (node.data.uid == uid) {
      x = node.position.x;
      break;
    }
  }
  //1print('(FF9)${uid}....${x}');
  return x;
}

class DrawArrow extends CustomClipper<Path> {
  NodeContents? a;
  NodeContents? b;
  DrawArrow({this.a, this.b});
  @override
  Path getClip(Size size) {
    double aX = _controller.graph.nodes.first.position.x;
    //1print(
    //1    '(FF8)${a!.uid}|${getX(uid: a!.uid)}...${b!.uid}|${getX(uid: b!.uid)}',
    //1  );
    var path = Path();

    path.lineTo(0, 0 + boxHeight);
    path.lineTo(0, lineWidth + boxHeight);
    path.lineTo(size.width / 2, lineWidth + boxHeight);
    path.lineTo(size.width / 2, lineWidth + arrowHeight + boxHeight);
    path.lineTo(size.width / 2 + arrowWidth, lineWidth + boxHeight);
    path.lineTo(size.width + arrowWidth, lineWidth + boxHeight);
    path.lineTo(size.width, 0 + boxHeight);
    path.lineTo(size.width / 2 + arrowWidth, 0 + boxHeight);
    path.lineTo(size.width / 2, -arrowHeight + boxHeight);
    path.lineTo(size.width / 2, 0 + boxHeight);
    path.lineTo(0, 0 + boxHeight);
    path.close();
    //1print('(FF1)${size}');
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    // //1print('(FF3)');
    return true; /*throw UnimplementedError();*/
  }
}
