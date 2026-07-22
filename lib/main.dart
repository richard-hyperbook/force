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


void moveNodesInGroupWithGroupNode(int groupNodeIndex) {
  print('(FJ7)${groupNodeIndex}');
  if (_controller.graph.groups.length < 1) return;
  Group? group;
  for (int i = 0; i < _controller.graph.groups.length; i++) {
    if (_controller.graph.groups[i].groupNodeIndex == groupNodeIndex) {
      group = _controller.graph.groups[i];
      break;
    }
  }
  Node groupNode = getNodeFromIndex(groupNodeIndex)!;
  vector.Vector2 groupNodePosition = groupNode.position!;
  if (group == null) return;
  for (int i = 0; i < _controller.graph.nodes.length; i++) {
    int nodeIndex = _controller.graph.nodes[i].data.index!;
    print('(FJ6)${i}....${nodeIndex},,,,${group.nodeIndexes}<<<<${groupNodePosition}');
    if (group.nodeIndexes!.indexOf(nodeIndex) != -1) {
      _controller.graph.nodes[i].position = groupNodePosition;
    }
  }
}


const buildNumber = 17;
const double arrowHeight = 7;
const double arrowWidth = 7;
const double lineWidth = 3;
const double boxHeight = 25;
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
const kColumnFilename = 'filename';
const kColumnJson = 'json';
const imageFilenameHead = kEndpoint + '/storage/buckets';
Group chosenGroup = nullGroup;
NodeFunction chosenNodeFunction = NodeFunction.add;

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

enum NodeFunction { nof, add, multiply, reciprocate }

const NodeFunction kNof = NodeFunction.nof;
const NodeFunction kAdd = NodeFunction.add;
const NodeFunction kMultiply = NodeFunction.multiply;
const NodeFunction kReciprocate = NodeFunction.reciprocate;

const Map<NodeFunction, String> nodeFunctionSymbol = {
  kNof: '?',
  kAdd: '+',
  kMultiply: '*',
  kReciprocate: '\u2339',
};

class NodeContents {
  int? index;
  NodeKind? kind;
  String? input;
  double? doubleResult;
  DateTime? dateTimeResult;
  String? stringResult;
  bool? isStartNode;
  bool? isEndNode;
  bool? isHighlight;
  bool? isDataEntry;
  NodeFunction? nodeFunction;

  //TextEditingController? textEditingController = TextEditingController(
  // text: '',
  // );
  NodeContents({
    required this.index,
    required this.kind,
    this.input,
    this.doubleResult,
    this.dateTimeResult,
    this.stringResult,
    this.isStartNode,
    this.isEndNode,
    this.isHighlight,
    required this.isDataEntry,
    required this.nodeFunction,
  });

  Map<String, dynamic> toJson() {
    Map<String, dynamic> m = {
      'index': index,
      'kind': getStringFromNodeKind(kind),
      'input': input,
      'doubleResult': doubleResult,
      'dateTimeResult': dateTimeResult?.toIso8601String(),
      'stringResult': stringResult,
      'isStartNode': isStartNode,
      'isEndNode': isEndNode,
      'isHighlight': isHighlight,
      'isDataEntry': isDataEntry,
      'nodeFunction': nodeFunction!.name,
    };
    //1print('(FF750)${this.index}....${this.kind},,,,${m}');
    return m;
  }

  /*NodeContents.fromJson(Map<String, dynamic> json)
    : index = (json['index'] as num?)?.toInt(),
      //json['index'] as int,
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
    index: json["index"] as int,
    kind: getNodeKindFromString(json['kind'])!,
    input: json["input"] as String,
    doubleResult: json["doubleResult"] as double,
    dateTimeResult: DateTime.parse(json['dateTimeResult'] as String),
    stringResult: json["stringResult"] as String,
    isStartNode: json["isStartNode"] as bool,
    isEndNode: json["isEndNode"] as bool,
    isHighlight: json['isHighlight'] as bool,
    isDataEntry: json['isDataEntry'] as bool,
    nodeFunction: NodeFunction.values.byName(json['nodeFunction']),
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
      index: (json['index'] as num?)?.toInt(), //json['index'] as int,
      kind: getNodeKindFromString(json['kind']), //json['kind'] as NodeKind,
      input: json['input'] as String,
      doubleResult: (json['doubleResult'] as num?)
          ?.toDouble(), //json['doubleResult'] as double,
      dateTimeResult: DateTime.parse(
        json['dateTimeResult'] as String,
      ), //json['dateTimeResult'] as DateTime,
      stringResult: json['stringResul'] as String,
      isDataEntry: json['isDataEntry'] as bool,
      nodeFunction: NodeFunction.values.byName(json['nodeFunction']),
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
  print('(FF1005C)${nd['index']}++++${nd['kind']}');
  return NodeContents(
    index: nd['index'],
    kind: getNodeKindFromString(nd['kind']) ?? kd,
    input: nd['input'],
    doubleResult: nd['doubleResult'],
    dateTimeResult: DateTime.tryParse(nd['dateTimeResult'] ?? ''),
    stringResult: nd['stringResul'],
    isStartNode: nd['isStartNode'],
    isEndNode: nd['isEndNode'],
    isHighlight: nd['isHighlight'],
    isDataEntry: nd['isDataEntry'],
    nodeFunction: NodeFunction.values.byName(nd['nodeFunction']),
  );
}

Group deserializeGroupContents(dynamic d) {
  print('(FH1005A)${d.runtimeType}');
  //Map<String, dynamic> nd = d['data'];
  var dd = d as Map<String, dynamic>;
  print('(FH1005B)${d}....${dd}');

  return Group(
    name: dd['name'],
    nodeIndexes: getNodeIndexesFromString(dd['nodeIndexes']),
    isVisible: dd['input'],
  );
}

class Spreadsheet {}

List<int> getNodeIndexesFromString(String s) {
  List<int> ni = [];
  List<String> ss = s.split(',');
  for (int i = 0; i < ss.length; i++) {
    int? index = int.tryParse(ss[i]);
    if (index != null) {
      ni.add(index);
    }
  }
  return ni;
}

final Group nullGroup = Group(name: '', nodeIndexes: [], isVisible: false);

Group groupFromMap(Map<String, dynamic> groupMap) {
  String nodeIndexesString = groupMap['nodeIndexes'];

  List<String> nodeIndexesStringList = nodeIndexesString.split(',');
  List<int> nodeIndexesList = [];
  for (int i = 0; i < nodeIndexesStringList.length; i++) {
    nodeIndexesList.add(int.tryParse(nodeIndexesStringList[i]) ?? -1);
  }
  print('(FH86)${groupMap}....');
  Group group = Group(
    name: groupMap['name'],
    nodeIndexes: nodeIndexesList,
    isVisible: groupMap['isVisible'],
    groupNodeIndex: groupMap['groupNodeIndex'],
  );
  print(
    '(FH1002)${nodeIndexesString}....${groupMap},,,,${nodeIndexesList}====${group}',
  );
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

Group? getGroupFromNodeIndex(int? nodeIndex) {
  if (nodeIndex == null) return null;
  for (int i = 0; i < _controller.graph.groups.length; i++) {
    if (nodeIndex == _controller.graph.groups[i].groupNodeIndex) {
      return _controller.graph.groups[i];
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
      '(FFDN)--x>${node.position.x}--y>${node.position.y}>>>>${node.data.index}<<<<${node.data.input}££££${node.data.kind};;;;${node.data.doubleResult}::::${node.data.dateTimeResult}@@@@${node.data.stringResult}@@@@${(node.data.nodeFunction ?? kNof).name}',
    );
  }
  for (var edge in _controller.graph.edges) {
    print(
      '(FFDE)${edge.a.data.index}${edge.a.data.kind}....${edge.b.data.index}${edge.b.data.kind},,,,${edge.edgeExtra.isActive}',
    );
    print(
      '(FFDF)${edge.a.position}||||${edge.a.mass}....${edge.b.position}!!!!${edge.b.mass},,,,${edge.distance}????${edge.angle}',
    );
  }
  for (int i = 0; i < _controller.graph.groups.length; i++) {
    print(
      '(FFDG)${_controller.graph.groups[i].name}....${_controller.graph.groups[i].nodeIndexes},,,,${_controller.graph.groups[i].isVisible}||||${_controller.graph.groups[i].groupNodeIndex}',
    );
  }
}



int? getEdgeIntegerFromNodeIndexes({int? indexA, int? indexB}) {
  for (int i = 0; i < _controller.graph.edges.length; i++) {
    if ((_controller.graph.edges[i].a.data.index == indexA) &&
        (_controller.graph.edges[i].b.data.index == indexB)) {
      return i;
    }
  }
  return null;
}

EdgeExtra? getEdgeExtraFromNodeIndexes({int? indexA, int? indexB}) {
  int? i = getEdgeIntegerFromNodeIndexes(indexA: indexA, indexB: indexB);
  if (i == null) return null;
  return _controller.graph.edges[i].edgeExtra;
}

Node? getNodeFromIndex(int? index) {
  print('(FF3020)${index}....${_controller.graph.nodes.length}');
  for (int i = 0; i < _controller.graph.nodes.length; i++) {
    print(
      '(FF3021)${index}....${_controller.graph.nodes[i].data.index},,,,${_controller.graph.nodes[i]}',
    );
    if (index == _controller.graph.nodes[i].data.index) {
      return _controller.graph.nodes[i];
    }
  }
  return null;
}

bool isEdgeActive({int? indexA, int? indexB}) {
  //1print(
  //1 '(FF760)${indexA}....${indexB},,,,${getEdgeExtra(indexA: indexA, indexB: indexB)}',
  //1 );
  EdgeExtra? ee = getEdgeExtraFromNodeIndexes(indexA: indexA, indexB: indexB);
  return ee!.isActive!;
}

void setEdgeExtraIsActive({int? indexA, int? indexB, bool? isActive = true}) {
  int? i = getEdgeIntegerFromNodeIndexes(indexA: indexA, indexB: indexB);
  if (i == null) return;
  _controller.graph.edges[i].edgeExtra.isActive = isActive;
}

void addEdgeByData({
  required NodeContents? nodeA,
  required NodeContents? nodeB,
  bool? isActive = true,
}) {
  _controller.addEdgeByData(nodeA!, nodeB!, EdgeExtra(isActive: isActive));

  print(
    '(FF761)${nodeA.index}....${nodeB.index},,,,${isActive}++++${getEdgeExtraFromNodeIndexes(indexA: nodeA.index, indexB: nodeB.index)!.isActive})}',
  );
  //dumpGraph();
}

void deleteEdgeByData({
  required NodeContents? nodeA,
  required NodeContents? nodeB,
}) {
  _controller.deleteEdgeByData(nodeA!, nodeB!);
}

int _indexIndex = 0;

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

    _indexIndex = 0;
    _controller =
        ForceDirectedGraphController(
          graph: ForceDirectedGraph.generateNTree(
            config: GraphConfig(elasticity: 0.15),
            nodeCount: 1,
            maxDepth: 20,
            n: 4,
            generator: () {
              return NodeContents(
                kind: kd,
                index: _indexIndex++,
                input: '',
                isDataEntry: false,
                nodeFunction: NodeFunction.add,
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
      //1print('(FF600)${_indexIndex}');
      _controller.needUpdate();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  NodeContents? getNodeContentsFromIndex(int index) {
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.index == index) {
        return _controller.graph.nodes[i].data;
      }
    }
    return null;
  }

  void setControllerResult({int? index, dynamic value}) {
    //1print('(FF331)${index}....${value}');
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.index == index) {
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
        //1 '(FF332)${_controller.graph.nodes[i].data.index}++++${_controller.graph.nodes[i].data.doubleResult}....${_controller.graph.nodes[i].data.dateTimeResult},,,,${_controller.graph.nodes[i].data.stringResult}',
        //1);
        break;
      }
    }
  }

  void setControllerInput({int? index, dynamic value}) {
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.index == index) {
        _controller.graph.nodes[i].data.input = value;
        break;
      }
    }
  }

  void setControllerIsStartNode({int? index, bool? value}) {
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.index == index) {
        _controller.graph.nodes[i].data.isStartNode = value;
        break;
      }
    }
  }

  void setControllerIsEndNode({int? index, bool? value}) {
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.index == index) {
        _controller.graph.nodes[i].data.isEndNode = value;
        break;
      }
    }
  }

  void setControllerIsDataEntry({int? index, bool? value}) {
    print('(FG7)${index}....${value}');
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.index == index) {
        _controller.graph.nodes[i].data.isDataEntry = value;
        print('(FG8)${index}....${value}');
        break;
      }
    }
  }

  void setControllerIsHighlight({int? index, bool? value}) {
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.index == index) {
        _controller.graph.nodes[i].data.isHighlight = value;
        break;
      }
    }
  }

  void setControllerNodeFunction({int? index, NodeFunction? value}) {
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.index == index) {
        _controller.graph.nodes[i].data.nodeFunction = value;
        break;
      }
    }
  }

  vector.Vector2? getNodePosition(int? index) {
    vector.Vector2? pos;
    for (var node in _controller.graph.nodes) {
      if (node.data.index == index) {
        pos = node.position;
        break;
      }
    }
    return pos;
  }

  setNodePosition(int? index, vector.Vector2 pos) {
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.index == index) {
        print('(FI42)${index}....${getNodePosition(index)}');
        _controller.graph.nodes[i].position = pos;
        break;
      }
    }
  }

  void setControllerKind({int? index, NodeKind? kind}) {
    for (var node in _controller.graph.nodes) {
      if (node.data.index == index) {
        node.data.kind = kind;
        break;
      }
    }
  }

  dynamic processEdge({dynamic total, Edge? edge, isFirstEdge = false}) {
    EdgeExtra? edgeExtra = getEdgeExtraFromNodeIndexes(
      indexA: edge!.a.data.index,
      indexB: edge.b.data.index,
    );
    if (!edgeExtra!.isActive!) return total;
    dynamic result = total;
    const Map<NodeKind, NodeOperation> mapADouble = {
      kd: NodeOperation.functionDouble,
      kt: NodeOperation.functionDayToDate,
      ks: NodeOperation.functionDoubleToString,
    };
    const Map<NodeKind, NodeOperation> mapADateTime = {
      kd: NodeOperation.functionDayToDate,
      kt: NodeOperation.functionDayToDate,
      ks: NodeOperation.functionDoubleToString,
    };
    const Map<NodeKind, NodeOperation> mapAString = {
      kd: NodeOperation.functionDouble,
      kt: NodeOperation.functionDayToDate,
      ks: NodeOperation.functionDoubleToString,
    };

    const Map<NodeKind, Map> aMap = {
      kd: mapADouble,
      kt: mapADateTime,
      ks: mapAString,
    };
    NodeKind aKind = edge.a.data.kind!;
    NodeKind bKind = edge.b.data.kind!;

    //1print('(FF400)${edge},,,,${aKind}....${bKind}');
    NodeOperation op = NodeOperation.noop;
    if ((aMap[aKind] != null) && (aMap[aKind]![bKind] != null)) {
      op = aMap[aKind]![bKind]!;
    }

    print('(FG1${total}%%%%${aKind}....${bKind},,,,${op}');
    switch (op) {
      case (NodeOperation.noop):
        break;
      case (NodeOperation.functionDouble):
        result = 0.0;
        print(
          '(FF330A)${total}****${edge.a.data.doubleResult},,,,${result}....${edge.b.data.doubleResult}',
        );
        switch (edge.b.data.nodeFunction) {
          case (kAdd):
            result = (total ?? 0.0) + (edge.a.data.doubleResult ?? 0.0);
            break;
          case (kMultiply):
            result = (total ?? 1.0) * (edge.a.data.doubleResult ?? 0.0);
            break;
          case (kReciprocate):
            result = (total ?? 1.0) / (edge.a.data.doubleResult ?? 0.0);
            break;
          default:
            print('(FH100)${edge.b.data.nodeFunction!.name}');
            result = null;
            break;
        }

        //setControllerResult(index: edge.b.data.index, value: result);
        print('(FF330Z)${result}');
        break;
      case (NodeOperation.functionDayToDate):
        result = DateTime.now();
        if ((total is DateTime) && (edge.a.data.kind == kd)) {
          result = total.add(
            Duration(days: ((edge.a.data.doubleResult!.floor()) ?? 0.0) as int),
          );
        } else {
          print(
            '(FG4)${total}....${edge.a.data.kind},,,,${edge.a.data.dateTimeResult}',
          );
          if ((total is double) &&
              (edge.a.data.kind == kt) &&
              (edge.edgeExtra.isActive!)) {
            setControllerKind(index: edge.b.data.index, kind: kt);
            if (edge.a.data.dateTimeResult == null) {
              setControllerResult(
                index: edge.b.data.index,
                value: DateTime.now(),
              );
            } else {
              result = edge.a.data.dateTimeResult!.add(
                Duration(days: ((total.floor()) ?? 0.0) as int),
              );
            }
          } else {
            result = null;
            setControllerKind(index: edge.b.data.index, kind: kd);
          }
        }
        //setControllerResult(index: edge.b.data.index, value: result);
        print('(FG2)${edge.b.data.index},,,,${total}....${edge.a.data.kind}');
        break;
      case (NodeOperation.functionDoubleToString):
        edge.b.data.stringResult =
            (edge.b.data.input ?? '') + (edge.a.data.stringResult ?? '');
        break;
      case (NodeOperation.latestDate):
        //2 edge.b.data.dateTimeResult =  edge.a.data.result;
        break;
      case (NodeOperation.illegal):
        //2 edge.b.data!.result = null;
        break;
    }
    print(
      '(FF320)${op}....${edge.b.data.input},,,,${edge.a.data.doubleResult}++++${edge.b.data.doubleResult}????${result}',
    );
    return result;
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
    for (var edge in _controller.graph.edges) {
      //1print(
      //1  '(FF5)${nodeContents.index}----${nodeContents.kind}++++${edge.a.data.index}....${edge.a.data.kind}>>>>${edge.b.data.index},,,,${edge.b.data.kind}',
      //1);
      if (edge.b.data.index == nodeContents.index) {
        //1print('(FF51)${nodeContents.kind}');
        Node? nn;
        nn = edge.a;
        total = processEdge(total: total, edge: edge, isFirstEdge: isFirstEdge);
        edgeFound = true;
        if (total == null) edgeFound = false;
        isFirstEdge = false;
      }
    }
    if (edgeFound) {
      setControllerResult(index: nodeContents.index, value: total);
    } else {
      setControllerResult(
        index: nodeContents.index,
        value: double.tryParse(nodeContents.input ?? '') ?? 0.0,
      );
      total = double.tryParse(nodeContents.input ?? '') ?? 0.0;
    }
    switch (nodeContents.kind) {
      case (ke):
        return '1ERROR 1';
      case (kg):
        final String groupName =
            (getGroupFromNodeIndex(nodeContents.index)!.name) ?? 'NO Group';
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
    //1print('(FF202)${node.index}....${node.isStartNode},,,,${node.isEndNode}');
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
        '(FH7)${_controller.graph.edges[i].a.data.index}....${_controller.graph.edges[i].b.data.index}',
      );
      if ((_controller.graph.edges[i].b.data.index == data.index) &&
          (!_controller.graph.edges[i].edgeExtra.isActive!)) {
        print(
          '(FH8)${_controller.graph.edges[i].a.data.index}....${_controller.graph.edges[i].a!.data.kind}',
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
      for (
        int j = 0;
        j < _controller.graph.groups[i].nodeIndexes!.length;
        j++
      ) {
        if (_controller.graph.groups[i].nodeIndexes![j] == data.index) {
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
                      print('(FH5)${value}++++${data.index}');
                      double? doubleValue = double.tryParse(value);
                      setState(() {
                        if (doubleValue == null) {
                          setControllerKind(index: data.index, kind: ks);
                        } else {
                          setControllerKind(index: data.index, kind: kd);
                          double? doubleValue = double.tryParse(value);
                          setControllerInput(index: data.index, value: value);
                          setControllerResult(
                            index: data.index,
                            value: doubleValue ?? 'Y',
                          );
                        }
                        setControllerInput(index: data.index, value: value);
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                  ElevatedButton(
                    child: const Text('Clear data entry'),
                    onPressed: () {
                      setState(() {
                        setControllerIsDataEntry(
                          index: data.index,
                          value: false,
                        );
                      });
                      setControllerIsDataEntry(index: data.index, value: false);
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
                          //1print('(FF11)${value}++++${data.index}');
                          double? doubleValue = double.tryParse(value);
                          setState(() {
                            if (doubleValue == null) {
                              setControllerKind(index: data.index, kind: ks);
                            } else {
                              setControllerKind(index: data.index, kind: kd);
                            }
                            setControllerInput(index: data.index, value: value);
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                      ElevatedButton(
                        child: const Text('Set data entry'),
                        onPressed: () async {
                          setState(() {
                            setControllerIsDataEntry(
                              index: data.index,
                              value: true,
                            );
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                      ElevatedButton(
                        child: const Text('Enter date'),
                        onPressed: () async {
                          setControllerKind(index: data.index, kind: kt);
                          DateTime? d = await selectDate();
                          setState(() {
                            if (d == null) {
                              setControllerInput(
                                index: data.index,
                                value: null,
                              );
                            } else {
                              setControllerInput(
                                index: data.index,
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
                              index: _indexIndex,
                              input: '',
                              isDataEntry: false,
                              nodeFunction: NodeFunction.add,
                            ),
                          );
                          _indexIndex++;
                          // _nodes.clear();
                          // _edges.clear();
                          Navigator.of(context).pop();
                        },
                      ),

                      Container(
                        width: 300,
                        height: 34,
                        child: Row(
                          children: [
                            Text('Function: '),
                            SizedBox(width: 10),
                            Container(
                              width: 120,
                              height: 30,

                              child: DropdownButton<NodeFunction>(
                                //  key: ValueKey(widget),
                                value: data.nodeFunction,
                                hint: const Text('Please select group'),
                                items: NodeFunction.values
                                    .map<DropdownMenuItem<NodeFunction>>((
                                      NodeFunction item,
                                    ) {
                                      return DropdownMenuItem<NodeFunction>(
                                        value: item,
                                        child: Text(item.name),
                                      );
                                    })
                                    .toList(),
                                elevation: 2,
                                onChanged: (value) {
                                  setState(() {
                                    setControllerNodeFunction(
                                      index: data.index,
                                      value: value,
                                    );
                                  });
                                  setStateMain(() {});
                                  print(
                                    '(FH90)${value!.name}....${value.index}',
                                  );
                                },
                                isExpanded: true,
                                focusColor: Colors.transparent,
                              ),
                            ),
                          ],
                        ),
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
                            setControllerInput(index: data.index, value: '');
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                      ElevatedButton(
                        child: const Text('Delete node'),
                        onPressed: () {
                          setState(() {
                            //1print('(FF411)${data.index}');
                            if (data.index == 0) {
                              toastification.show(
                                context: context,
                                title: Text('Cannot delete first node'),
                              );
                            } else {
                              for (
                                int i = 0;
                                i < _controller.graph.edges.length;
                                i++
                              ) {
                                if ((_controller.graph.edges[i].a.data.index ==
                                        data.index) ||
                                    (_controller.graph.edges[i].b.data.index ==
                                        data.index)) {
                                  //1print(
                                  //1      '(FF412)${_controller.graph.edges[i].a.data.index}....${_controller.graph.edges[i].b.data.index}',
                                  //1 );
                                  /*_controller.*/
                                  deleteEdgeByData(
                                    nodeA: _controller.graph.edges[i].a.data,
                                    nodeB: _controller.graph.edges[i].a.data,
                                  );
                                }
                                //1print('(FF413)${data.index}');
                                _controller.deleteNodeByData(data);
                              }
                              setControllerInput(
                                index: data.index,
                                value: null,
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
                        child: const Text('Set start node'),
                        onPressed: () {
                          setState(() {
                            //1print('(FF16)');
                            setControllerIsStartNode(
                              index: data.index!,
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
                            setControllerIsEndNode(
                              index: data.index!,
                              value: true,
                            );
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
                  ElevatedButton(
                    child: const Text('Highlight node'),
                    onPressed: () {
                      setState(() {
                        setControllerIsHighlight(
                          index: data.index!,
                          value: true,
                        );
                      });

                      Navigator.of(context).pop();
                    },
                  ),

                  ElevatedButton(
                    child: const Text('Make chain'),
                    onPressed: () {
                      //1print('(FF700)');
                      NodeContents currentNodeContents = data;
                      double rootNodeX = getNodePosition(data.index)!.x;
                      double rootNodeY = getNodePosition(data.index)!.y;
                      int? replicationCount =
                          int.tryParse(textEditingController!.text) ?? 1;
                      for (int i = 0; i < replicationCount; i++) {
                        NodeContents nextNodeContents = NodeContents(
                          index: _indexIndex,
                          kind: currentNodeContents.kind,
                          isDataEntry: false,
                          nodeFunction: NodeFunction.add,
                        );
                        /*_controller.*/
                        addEdgeByData(
                          nodeA: currentNodeContents,
                          nodeB: nextNodeContents,
                        );
                        vector.Vector2 nextPos = vector.Vector2(
                          rootNodeX,
                          rootNodeY - ((i.toDouble() + 1) * chainYincrement),
                        );
                        //1print('(FF747)${rootNodeX}....${rootNodeY},,,,${nextPos}');
                        setNodePosition(nextNodeContents.index, nextPos);
                        setControllerInput(
                          index: nextNodeContents.index,
                          value: currentNodeContents.input,
                        );
                        _indexIndex++;
                        currentNodeContents = nextNodeContents;
                      }

                      Navigator.of(context).pop();
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

  void onNodeTap(NodeContents data) {
    print('(FH6)${data.index}....${data.isDataEntry}');
    if (data.isDataEntry ?? false) {
      showDataEntryDialog(data);
    } else {
      showStandardDialog(data);
    }
  }

  bool isIndexEqual(NodeContents? n1, NodeContents? n2) {
    if ((n1 == null) || (n2 == null)) return false;
    if (n1.index == n2.index) return true;
    return false;
  }

  Widget drawNode(NodeContents data) {
    //1print('(FF430)${data.index}');
    if (data.isDataEntry ?? false) {
      return Text((data.doubleResult ?? '').toString());
    } else {
      String inputString = data.input ?? '';
      print('(FG6)${data.index}....${data.kind}');
      switch (data.kind) {
        case (ke):
          return Text('ERROR}....${inputString}>${getResult(data)}');
        case (kg):
          final String groupName =
              (getGroupFromNodeIndex(data.index)!.name) ?? 'NO Group';
          return Text('G: ' + groupName);
        case (kd):
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

  bool isVisibleAnyGroupsNode({int? nodeIndex}) {
    bool inGroup = false;
    bool isVisible = false;
    for (int i = 0; i < _controller.graph.groups.length; i++) {
      for (
        int j = 0;
        j < _controller.graph.groups[i].nodeIndexes!.length;
        j++
      ) {
        if (_controller.graph.groups[i].nodeIndexes![j] == nodeIndex) {
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
                    _draggingData = data;
                  });
                },
                onDraggingEnd: (NodeContents data) {
                  setState(() {
                    _draggingData = null;
                  });
                },
                onDraggingUpdate: (NodeContents data) {
                  debugPrint('(FJ1)${data.index}');
                },
                nodesBuilder: (context, NodeContents data) {
                  Color color;
                  if (!isVisibleAnyGroupsNode(nodeIndex: data.index)) {
                    return Container();
                  }
                  for (int i = 0; i < _controller.graph.edges.length; i++) {
                    if (_controller.graph.edges[i].b.data.index == data.index) {
                      if ((_controller.graph.edges[i].a.data.kind == kt) &&
                          (_controller.graph.edges[i].edgeExtra.isActive!)) {
                        setControllerKind(index: data.index, kind: kt);
                        break;
                      }
                    }
                  }

                  switch (getNodeFromIndex(data.index)!.data.kind) {
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
                  //1 '(FF800)${data.index}....${data.isStartNode},,,,${data.isEndNode}++++${setBoxColor(data)}',
                  //1 );
                  double resultWidth = 0;
                  switch (data.kind) {
                    case (ke):
                      resultWidth = 50;
                      break;
                    case (kg):
                      resultWidth = 150;
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
                  double boxWidth =
                      ((data.input ?? '').length.toDouble() +
                      charWidth +
                      resultWidth);
                  print(
                    '(FG3)${data.index}<<<<${(data.input ?? '').length.toDouble()}....${data.kind},,,,${boxWidth}>>>>${color}',
                  );
                  return GestureDetector(
                    onTap: () {
                      //1print('(FF10)');
                      onNodeTap(data);
                    },

                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,

                          child: Center(
                            child: Text(
                              nodeFunctionSymbol[data.nodeFunction] ?? '£',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black, //setBoxColor(data),
                            borderRadius: BorderRadius.circular(
                              (data.isDataEntry ?? false) ? 10 : 1,
                            ),
                            border: Border.all(color: color, width: 1),
                          ),
                        ),
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
                  if ((!isVisibleAnyGroupsNode(nodeIndex: a.index!)) ||
                      (!isVisibleAnyGroupsNode(nodeIndex: b.index))) {
                    return Container();
                  }
                  if ((isIndexEqual(edgeInputNodeContentsA, a)) &&
                      (isIndexEqual(edgeInputNodeContentsB, b)))
                    color = Colors.red;
                  if ((isIndexEqual(edgeCommonNodeContentsA, a)) &&
                      (isIndexEqual(edgeCommonNodeContentsB, b)))
                    color = Colors.blue;
                  if ((isIndexEqual(edgeOutputNodeContentsA, a)) &&
                      (isIndexEqual(edgeOutputNodeContentsB, b)))
                    color = Colors.green;
                  //1print(
                  //1 '(FF762)${a.index}....${b.index},,,,${isEdgeActive(indexA: a.index, indexB: b.index)}',
                  //1);
                  //dumpGraph();
                  if (!isEdgeActive(indexA: a.index, indexB: b.index)) {
                    color = Colors.grey;
                  }
                  return /*GestureDetector(
                    onTap: () {
                      final edge = "$a <-> $b";
                      setState(() {
                        if (_edges.contains(edge)) {
                          _edges.remove(edge);
                        } else {
                          _edges.add(edge);
                        }
                        //1print("onTap $a <-$distance-> $b");
                      });
                    },
                    child:*/ arrowEdge(
                    distance: distance,
                    a: a,
                    b: b,
                    color: color,
                    // ),
                  );
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
      if ((_controller.graph.edges[i].a.data.index == a!.index) &&
          (_controller.graph.edges[i].b.data.index == b!.index)) {
        _controller.deleteEdge(_controller.graph.edges[i]);
      }
    }
  }

  Widget arrowEdge({
    NodeContents? a,
    NodeContents? b,
    double distance = 0,
    color = Colors.black87,
  }) {
    double angle = 0;
    bool reverse = false;
    if (getX(index: a!.index)! > getX(index: b!.index)!) {
      angle = pi;
      reverse = true;
    }
    //1print('(FF2)${distance}....${reverse}');

    return Transform.rotate(
      angle: angle,
      child: ClipPath(
        clipper: DrawArrow(a: a, b: b),
        child: GestureDetector(
          onTap: () {
            showDialog<double>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Edge operations'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
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
                              deleteEdgeByData(nodeA: a, nodeB: b);
                              /*_controller.*/
                              addEdgeByData(nodeA: b, nodeB: a);
                              Navigator.of(context).pop();
                            },
                          ),

                          ElevatedButton(
                            child:
                                isEdgeActive(indexA: a.index, indexB: b.index)
                                ? Text('Make passive')
                                : Text('Make active'),
                            onPressed: () {
                              //1print(
                              //1  '(FF763)${isEdgeActive(indexA: a.index, indexB: b.index)}',
                              //1);
                              setEdgeExtraIsActive(
                                indexA: a.index,
                                indexB: b.index,
                                isActive: !isEdgeActive(
                                  indexA: a.index,
                                  indexB: b.index,
                                ),
                              );
                              //1print(
                              //1  '(FF76)${a.index}....${b.index},,,,${isEdgeActive(indexA: a.index, indexB: b.index)}',
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
            );
          }
        }
    }
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      setControllerIsStartNode(
        index: _controller.graph.nodes[i].data.index,
        value: false,
      );
      setControllerIsEndNode(
        index: _controller.graph.nodes[i].data.index,
        value: false,
      );
    }
    setState(() {});
  }

  void alignHoriz() {
    double topY = double.maxFinite;
    double topX = 0.0;
    int? topIndex;
    for (int i = 0; i < _controller.graph.nodes.length; i++) {
      if (_controller.graph.nodes[i].data.isHighlight ?? false) {
        if (_controller.graph.nodes[i].position.y < topY) {
          topY = _controller.graph.nodes[i].position.y;
          topX = _controller.graph.nodes[i].position.x;
          topIndex = i;
        }
      }
    }
    if (topIndex != null) {
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

  void setGroupNodeIndex({String? groupName, int? nodeIndex}) {
    for (int i = 0; i < _controller.graph.groups.length; i++) {
      print(
        '(FH187A)${i},,,,${groupName}....${_controller.graph.groups[i].name}',
      );
      if (groupName == _controller.graph.groups[i].name) {
        _controller.graph.groups[i].groupNodeIndex = nodeIndex;
        print('(FH187A)${i},,,,${_controller.graph.groups[i].groupNodeIndex}');
      }
    }
  }

  void addNodeToGroup({String? groupName, int? nodeIndex}) {
    if ((groupName == null) || (nodeIndex == null)) {
      return;
    }
    print('(FH8A)');
    for (int i = 0; i < _controller.graph.groups.length; i++) {
      print('(FH8A)');
      if (groupName == _controller.graph.groups[i].name) {
        print(
          '(FH8B)${i}....${_controller.graph.groups[i].nodeIndexes!.length}',
        );
        if (_controller.graph.groups[i].nodeIndexes!.length == 0) {
          _controller.graph.groups[i].nodeIndexes!.add(nodeIndex);
        } else {
          bool found = false;
          for (
            int j = 0;
            j < _controller.graph.groups[i].nodeIndexes!.length;
            j++
          ) {
            print('(FH8C)');
            if (_controller.graph.groups[i].nodeIndexes![j] == nodeIndex) {
              print('(FH8D)');
              found = true;
            }
          }
          if (!found) {
            _controller.graph.groups[i].nodeIndexes!.add(nodeIndex);
            print('(FH8E)${_controller.graph.groups[i].nodeIndexes}');
          }
        }
      }
    }
  }

  void removeNodeFromGroup({String? groupName, int? nodeIndex}) {
    if ((groupName == null) || (nodeIndex == null)) {
      return;
    }
    print('(FH6A)');
    for (int i = 0; i < _controller.graph.groups.length; i++) {
      print('(FH6A)');
      if (groupName == _controller.graph.groups[i].name) {
        print(
          '(FH6B)${i}....${_controller.graph.groups[i].nodeIndexes!.length}',
        );
        if (_controller.graph.groups[i].nodeIndexes!.length == 0) {
          _controller.graph.groups[i].nodeIndexes!.add(nodeIndex);
        } else {
          bool found = false;
          for (
            int j = 0;
            j < _controller.graph.groups[i].nodeIndexes!.length;
            j++
          ) {
            print('(FH6C)');
            if (_controller.graph.groups[i].nodeIndexes![j] == nodeIndex) {
              print('(FH6D)');
              found = true;
            }
          }
          if (!found) {
            _controller.graph.groups[i].nodeIndexes!.remove(nodeIndex);
            print('(FH6E)${_controller.graph.groups[i].nodeIndexes}');
          }
        }
      }
    }
  }

  void clearAllNodeStatus() {
    setState(() {
      //1print('(FF16)');
      for (int i = 0; i < _controller.graph.nodes.length; i++) {
        int index = _controller.graph.nodes[i].data.index!;
        setControllerIsStartNode(index: index, value: false);
        setControllerIsEndNode(index: index, value: false);
        setControllerIsHighlight(index: index, value: false);
      }
    });
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
                                '(FH9D)${_controller.graph.nodes[i].data.index}',
                              );
                              addNodeToGroup(
                                groupName: chosenGroup!.name,
                                nodeIndex:
                                    _controller.graph.nodes[i].data.index,
                              );
                            }
                          }
                        }
                        for (Group group in _controller.graph.groups) {
                          print('(FH10)${group.name}....${group.nodeIndexes}');
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
                                '(FH91)${_controller.graph.nodes[i].data.index}',
                              );
                            } else {
                              removeNodeFromGroup(
                                groupName: chosenGroup!.name,
                                nodeIndex:
                                    _controller.graph.nodes[i].data.index,
                              );
                            }
                          }
                        }
                        for (Group group in _controller.graph.groups) {
                          print('(FH10)${group.name}....${group.nodeIndexes}');
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
                              k <
                                  _controller
                                      .graph
                                      .groups[j]
                                      .nodeIndexes!
                                      .length;
                              k++
                            ) {
                              print(
                                '(FH30)${i}<${j}>${k}....${_controller.graph.groups[j].nodeIndexes},,,,${_controller.graph.nodes[i].data.index}',
                              );

                              if (_controller.graph.groups[j].nodeIndexes![i] ==
                                  _controller.graph.nodes[i].data.index) {
                                setState(() {
                                  _controller.graph.nodes[i].data.isHighlight =
                                      true;
                                  print(
                                    '(FH31)${i}<${j}>${k}....${_controller.graph.groups[j].nodeIndexes},,,,${_controller.graph.nodes[i].data.index}',
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
                        '(FI23)${chosenGroup.nodeIndexes}....${chosenGroup.name}',
                      );
                      if (chosenGroup == nullGroup) {
                        toastification.show(
                          context: context,
                          title: Text('Select group'),
                        );
                      } else {
                        double topY = -double.maxFinite;
                        double topX = 0.0;
                        int? topIndex;
                        List<int> nodeIndexes = chosenGroup.nodeIndexes!;
                        for (int i = 0; i < nodeIndexes.length; i++) {
                          print('(FI24)${topY}....${i},,,,${nodeIndexes}');
                          if (_controller
                                  .graph
                                  .nodes[nodeIndexes[i]]
                                  .position
                                  .y >
                              topY) {
                            topY = _controller
                                .graph
                                .nodes[nodeIndexes[i]]
                                .position
                                .y;
                            topX = _controller
                                .graph
                                .nodes[nodeIndexes[i]]
                                .position
                                .x;
                            topIndex = nodeIndexes[i];
                          }
                        }
                        debugPrint('(FI11)${topX}....${topY}...${topIndex}');
                        int groupNodeIndex = createNode(
                          kind: kg,
                          isDataEntry: false,
                        );
                        debugPrint('(FI12)${topX}....${topY}...${topIndex}');
                        setGroupNodeIndex(
                          groupName: chosenGroup.name,
                          nodeIndex: groupNodeIndex,
                        );
                        debugPrint('(FI13)${topX}....${topY}...${topIndex}');
                        setNodePosition(
                          groupNodeIndex,
                          vector.Vector2(topX, topY),
                        );
                        debugPrint('(FI14)${topX}....${topY}...${topIndex}');
                        setState(() {
                          for (int i = 0; i < nodeIndexes.length; i++) {
                            setNodePosition(
                              nodeIndexes[i],
                              vector.Vector2(topX, topY),
                            );
                            print(
                              '(FI31)${i}....${nodeIndexes[i]},,,,${topX}<<<<${topY}',
                            );
                          }
                        });
                        print(
                          '(FH40)${chosenGroup.name}....${_controller.graph.groups}',
                        );
                        Navigator.of(context).pop();
                      }
                      dumpGraph();
                    },
                  ),

                  /* CheckboxListTile(
                    title: Text('Is group visible?'),
                    tristate: true,
                    value: chosenGroupIsVisible,
                    onChanged: (value) {
                      if (chosenGroup != null) {
                        setState(() {
                          chosenGroupIsVisible = value;
                          setGroupIsVisible(
                            groupName: chosenGroup!.name,
                            value: value,
                          );
                        });
                      }
                    },
                  ),*/
                  Divider(),
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
                        debugPrint('(FI1)');
                        setState(() {
                          createGroupButtonCaption =
                              kCreateGroupButtonCaptionGroupExists;
                        });
                      } else {
                        setState(() {
                          _controller.graph.groups.add(
                            Group(
                              name: groupNameTextEditingController.text,
                              nodeIndexes: [],
                              isVisible: true,
                            ),
                          );
                          chosenGroup = _controller.graph.groups.last;
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

  int createNode({NodeKind? kind, bool? isDataEntry = false}) {
    int current_indexIndex = _indexIndex;
    NodeContents n = NodeContents(
      index: _indexIndex,
      kind: kind,
      isDataEntry: isDataEntry,
      nodeFunction: NodeFunction.add,
    );
    _controller.addNode(n);
    _indexIndex++;
    return current_indexIndex;
  }

  Widget _buildMenu(BuildContext context) {
    return Wrap(
      children: [
        ElevatedButton(
          onPressed: () {
            /*  NodeContents n = NodeContents(
              index: _indexIndex,
              kind: kd,
              isDataEntry: false,
              nodeFunction: NodeFunction.add,
            );
            _controller.addNode(n);
            _indexIndex++;*/
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
                              //1print('(FF710)${_json}');
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
                                    _indexIndex = 0;
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
                                      int maxIndex = 0;
                                      for (
                                        int i = 0;
                                        i < _controller.graph.nodes.length;
                                        i++
                                      ) {
                                        if (_controller
                                                .graph
                                                .nodes[i]
                                                .data
                                                .index! >
                                            maxIndex) {
                                          maxIndex = _controller
                                              .graph
                                              .nodes[i]
                                              .data
                                              .index!;
                                        }
                                      }
                                      _indexIndex = maxIndex + 1;

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
                index: _controller.graph.nodes[i].data.index!,
                value: false,
              );
              setControllerIsEndNode(
                index: _controller.graph.nodes[i].data.index!,
                value: false,
              );
              setControllerIsHighlight(
                index: _controller.graph.nodes[i].data.index!,
                value: false,
              );
            }
            setState(() {});
          },
          child: const Text('clear node status'),
        ),
        ElevatedButton(
          onPressed: () {
            showGroupsDialog();
          },
          child: const Text('groups'),
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

double? getX({int? index}) {
  double? x;
  for (var node in _controller.graph.nodes) {
    if (node.data.index == index) {
      x = node.position.x;
      break;
    }
  }
  //1print('(FF9)${index}....${x}');
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
    //1    '(FF8)${a!.index}|${getX(index: a!.index)}...${b!.index}|${getX(index: b!.index)}',
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
