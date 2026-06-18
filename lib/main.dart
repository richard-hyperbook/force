// ignore_for_file: avoid_print

import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
// import 'package:flutter_force_directed_graph/flutter_force_directed_graph.dart';
import 'package:matrix4_transform/matrix4_transform.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import 'package:vector_math/vector_math.dart' as vector;
import 'flutter_force_directed_graph.dart';

const buildNumber = 9;
const double arrowHeight = 7;
const double arrowWidth = 7;
const double lineWidth = 3;
const double boxHeight = 25;
const double chainYincrement = boxHeight + 10;
//NodeContents? edgeStartNodeContents;

NodeContents? edgeInputNodeContentsA;
NodeContents? edgeCommonNodeContentsA;
NodeContents? edgeOutputNodeContentsA;
NodeContents? edgeInputNodeContentsB;
NodeContents? edgeCommonNodeContentsB;
NodeContents? edgeOutputNodeContentsB;
bool _running = true;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: MaterialApp(
        title: 'Visual Spreadsheet ${buildNumber}',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const MyHomePage(title: 'Visual Spreadsheet ${buildNumber}'),
      ),
    );
  }
}

enum NodeKind { kindDouble, kindDateTime, kindString }

NodeKind? getNodeKindFromString(String s) {
  switch (s) {
    case 'kindDouble':
      return NodeKind.kindDouble;
    case 'kindDateTime':
      return NodeKind.kindDateTime;
    case 'kindString':
      return NodeKind.kindString;
    default:
      return null;
  }
}

String? getStringFromNodeKind(NodeKind? k) {
  switch (k) {
    case NodeKind.kindDouble:
      return 'kindDouble';
    case NodeKind.kindDateTime:
      return 'kindDateTime';
    case NodeKind.kindString:
      return 'kindString';
    default:
      return null;
  }
}

enum NodeOperation {
  illegal,
  addDouble,
  addDayToDate,
  latestDate,
  addDoubleToString,
}

class NodeContents {
  int? index;
  NodeKind? kind;
  String? input;
  double? doubleResult;
  DateTime? dateTimeResult;
  String? stringResult;
  bool? isStartNode;
  bool? isEndNode;

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
    };
    print('(FF750)${this.index}....${this.kind},,,,${m}');
    return m;
  }

  NodeContents.fromJson(Map<String, dynamic> json)
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
      isEndNode = json['isEndNode'] as bool;

  /*LinkItem.fromJson(Map<String, dynamic> json)
      : name = json['n'],
        url = json['u'];

  Map<String, dynamic> toJson() {
    return {
      'n': name,
      'u': url,
    };

nodeContentsfromJson(Map<String, dynamic> json) {
  return NodeContents(
      index: (json['index'] as num?)?.toInt()
      , //json['index'] as int,
      kind: getNodeKindFromString(json['kind']), //json['kind'] as NodeKind,
      input: json['input'] as String,
      doubleResult: (json['doubleResult'] as num?)
          ?.toDouble(), //json['doubleResult'] as double,
      dateTimeResult: DateTime.parse(
        json['dateTimeResult'] as String,
      ), //json['dateTimeResult'] as DateTime,
      stringResult: json['stringResul'] as String);
}
*/
}

late final ForceDirectedGraphController<NodeContents> _controller;

/*class EdgeExtra {
  int? indexA;
  int? indexB;
  bool? isActive;
  EdgeExtra(this.indexA, this.indexB, this.isActive);
}*/

// List<EdgeExtra> _edgeExtras = [];

void dumpGraph() {
  for (var node in _controller.graph.nodes) {
    print(
      '(FFDN)${node.data.index}<<<<${node.data.input}££££${node.data.kind};;;;${node.data.doubleResult}::::${node.data.dateTimeResult}@@@@${node.data.stringResult}',
    );
  }
  for (var edge in _controller.graph.edges) {
    print(
      '(FFDE)${edge.a.data.index}${edge.a.data.kind}....${edge.b.data.index}${edge.b.data.kind},,,,${edge.edgeExtra.isActive}',
    );
  }

}

int? getEdgeIntegerFromNodeIndexes({int? indexA, int? indexB}){
  for (int i = 0; i < _controller.graph.edges.length; i++) {
    if ((_controller.graph.edges[i].a.data.index == indexA) &&
        (_controller.graph.edges[i].b.data.index == indexB)) {
      return i;
    }
  }
  return null;
}

EdgeExtra? getEdgeExtra({int? indexA, int? indexB}) {
  int? i = getEdgeIntegerFromNodeIndexes(indexA: indexA, indexB: indexB);
  if (i == null) return null;
      return _controller.graph.edges[i].edgeExtra;
}

bool isEdgeActive({int? indexA, int? indexB}) {
  print(
    '(FF760)${indexA}....${indexB},,,,${getEdgeExtra(indexA: indexA, indexB: indexB)}',
  );
  EdgeExtra? ee = getEdgeExtra(indexA: indexA, indexB: indexB);
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
    '(FF761)${nodeA.index}....${nodeB.index}....${getEdgeExtra(indexA: nodeA.index, indexB: nodeB.index)}',
  );
  dumpGraph();
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
  final Set<NodeContents> _nodes = {};
  final Set<String> _edges = {};
  double _scale = 1.0;
  int _locatedTo = 0;
  NodeContents? _draggingData;
  String? _json;

  @override
  void initState() {
    super.initState();
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
                kind: NodeKind.kindDouble,
                index: _indexIndex++,
                input: '',
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
      print('(FF600)${_indexIndex}');
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
    print('(FF331)${index}....${value}');
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
        print(
          '(FF332)${_controller.graph.nodes[i].data.index}++++${_controller.graph.nodes[i].data.doubleResult}....${_controller.graph.nodes[i].data.dateTimeResult},,,,${_controller.graph.nodes[i].data.stringResult}',
        );
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
    for (var node in _controller.graph.nodes) {
      if (node.data.index == index) {
        print('(FF748)${index}....${getNodePosition(index)}');
        node.position = pos;
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
    EdgeExtra? edgeExtra = getEdgeExtra(
      indexA: edge!.a.data.index,
      indexB: edge.b.data.index,
    );
    if (!edgeExtra!.isActive!) return total;
    dynamic result = total;
    const Map<NodeKind, NodeOperation> mapADouble = {
      NodeKind.kindDouble: NodeOperation.addDouble,
      NodeKind.kindDateTime: NodeOperation.addDayToDate,
      NodeKind.kindString: NodeOperation.addDoubleToString,
    };
    const Map<NodeKind, NodeOperation> mapADateTime = {
      NodeKind.kindDouble: NodeOperation.addDouble,
      NodeKind.kindDateTime: NodeOperation.addDayToDate,
      NodeKind.kindString: NodeOperation.addDoubleToString,
    };

    const Map<NodeKind, Map> aMap = {NodeKind.kindDouble: mapADouble};
    NodeKind bKind = edge!.b.data.kind;
    NodeKind aKind = edge.a.data.kind;
    print('(FF400)${edge},,,,${aKind}....${bKind}');
    NodeOperation op = aMap[aKind]![bKind]!;
    switch (op) {
      case (NodeOperation.addDouble):
        double inputValue = 0.0;
        if (isFirstEdge) {
          inputValue = double.tryParse(edge.b.data.input ?? '') ?? 0;
        }
        result = (total ?? 0.0) + inputValue + (edge.a.data.doubleResult ?? 0);
        //setControllerResult(index: edge.b.data.index, value: result);
        print(
          '(FF330A)${edge.b.data.index},,,,${result}....${edge.b.data.doubleResult}',
        );
        break;
      case (NodeOperation.addDayToDate):
        DateTime? inputValue;
        if (isFirstEdge) {
          if ((edge.b.data.input == null) || (edge.b.data.input == '')) {
            inputValue = DateTime.now();
          } else {
            inputValue = stringToDateTime(edge.b.data.input);
          }
          result = inputValue!.add(
            Duration(days: (edge.a.data.doubleResult.floor()) ?? 0.0),
          );
        } else {
          result = result!.add(
            Duration(days: (edge.a.data.doubleResult.floor()) ?? 0.0),
          );
        }
        //setControllerResult(index: edge.b.data.index, value: result);
        print(
          '(FF330A)${edge.b.data.index},,,,${result}....${edge.b.data.doubleResult}',
        );
        break;
      case (NodeOperation.addDoubleToString):
        edge.b.data.stringResult = edge.b.data.input + edge.a.data.stringResult;
        break;
      case (NodeOperation.latestDate):
        edge.b.data.result = edge.b.data.input + edge.a.data.result;
        break;
      case (NodeOperation.illegal):
        edge.b.data.result = null;
        break;
    }
    print(
      '(FF320)${op}....${edge.b.data.input},,,,${edge.a.data.doubleResult}++++${edge.b.data.doubleResult}????${result}',
    );
    return result;
  }

  String getResult(NodeContents nodeContents) {
    dynamic total;
    /*switch(nodeContents.kind){
      case(NodeKind.kindDouble):
        total = double.tryParse(nodeContents.input!)?? 0.0; break;
      case(NodeKind.kindDateTime):
        total = double.tryParse(nodeContents.input!)?? 0.0; break;
      case(NodeKind.kindString):
        total = nodeContents.input!; break;
      case(null):
        total = null; break;
    }*/
    bool edgeFound = false;
    bool isFirstEdge = true;
    dumpGraph();
    for (var edge in _controller.graph.edges) {
      print(
        '(FF5)${nodeContents.index}----${nodeContents.kind}++++${edge.a.data.index}....${edge.a.data.kind}>>>>${edge.b.data.index},,,,${edge.b.data.kind}',
      );
      if (edge.b.data.index == nodeContents.index) {
        print('(FF51)${nodeContents.kind}');
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
      case (NodeKind.kindDouble):
        return total.toString();
      case (NodeKind.kindDateTime):
        return dateToString(total);
      case (NodeKind.kindString):
        return total;
      case (null):
        return '!!!';
    }
  }

  String dateToString(DateTime? dateTime) {
    if (dateTime == null) {
      return '???';
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
    if ((node.isStartNode == null) || (node.isEndNode == null)) {
      print('(FF201)${node}');
      return Colors.white;
    }
    print('(FF202)${node.index}');
    if (node.isStartNode!) {
      return Colors.amber;
    }
    if (node.isEndNode!) {
      return Colors.pink;
    }
    return Colors.white;
  }

  Future<void> selectDate({int? index}) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    setState(() {
      setControllerResult(index: index, value: pickedDate);
    });
  }

  void onNodeTap(NodeContents data) {
    showDialog<double>(
      context: context,
      builder: (BuildContext context) {
        TextEditingController textEditingController = TextEditingController(
          text: data.input,
        );
        return AlertDialog(
          title: const Text('Enter Value'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: textEditingController,
                onChanged: (value) {
                  print('(FF12)');
                },
              ),

              ElevatedButton(
                child: const Text('Enter'),
                onPressed: () {
                  String value = textEditingController!.text;
                  // double? doubleValue = double.tryParse(value);
                  print('(FF11)${value}++++${data.index}');
                  setState(() {
                    setControllerInput(index: data.index, value: value);
                  });
                  Navigator.of(context).pop();
                },
              ),
              Row(
                children: [
                  ElevatedButton(
                    child: const Text('Add number'),
                    onPressed: () {
                      print('(FF13A)');

                      /*_controller.*/
                      addEdgeByData(
                        nodeA: data,
                        nodeB: NodeContents(
                          kind: NodeKind.kindDouble,
                          index: _indexIndex,
                          input: '',
                        ),
                      );
                      _indexIndex++;
                      _nodes.clear();
                      _edges.clear();
                      Navigator.of(context).pop();
                    },
                  ),
                  ElevatedButton(
                    child: const Text('Add date'),
                    onPressed: () async {
                      print('(FF13B)');

                      /*_controller.*/
                      addEdgeByData(
                        nodeA: data,
                        nodeB: NodeContents(
                          kind: NodeKind.kindDateTime,
                          index: _indexIndex,
                          input: dateToString(DateTime.now()),
                        ),
                      );
                      await selectDate(index: _indexIndex);
                      _indexIndex++;
                      _nodes.clear();
                      _edges.clear();
                      Navigator.of(context).pop();
                    },
                  ),
                  ElevatedButton(
                    child: const Text('Add text'),
                    onPressed: () {
                      print('(FF13C)');

                      /*_controller.*/
                      addEdgeByData(
                        nodeA: data,
                        nodeB: NodeContents(
                          kind: NodeKind.kindString,
                          index: _indexIndex,
                          input: '',
                        ),
                      );
                      _indexIndex++;
                      _nodes.clear();
                      _edges.clear();
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
                        print('(FF410)');
                        setControllerInput(index: data.index, value: '');
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                  ElevatedButton(
                    child: const Text('Delete node'),
                    onPressed: () {
                      setState(() {
                        print('(FF411)${data.index}');
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
                              print(
                                '(FF412)${_controller.graph.edges[i].a.data.index}....${_controller.graph.edges[i].b.data.index}',
                              );
                              /*_controller.*/
                              deleteEdgeByData(
                                nodeA: _controller.graph.edges[i].a.data,
                                nodeB: _controller.graph.edges[i].a.data,
                              );
                            }
                            print('(FF413)${data.index}');
                            _controller.deleteNodeByData(data);
                          }
                          setControllerInput(index: data.index, value: null);
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
                        print('(FF16)');
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
                      print('(FF17)');
                      setState(() {
                        print('(FF16)');
                        setControllerIsEndNode(index: data.index!, value: true);
                      });

                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              ElevatedButton(
                child: const Text('XXXX'),
                onPressed: () {
                  NodeContents currentNodeContents = data;
                  int? replicationCount = int.tryParse(
                    textEditingController!.text,
                  );
                  if ((edgeInputNodeContentsA != null) &&
                      (edgeInputNodeContentsB != null) &&
                      (edgeCommonNodeContentsA != null) &&
                      (edgeCommonNodeContentsB != null) &&
                      (edgeOutputNodeContentsA != null) &&
                      (edgeOutputNodeContentsB != null)) {
                    print(
                      '(FF444A)${replicationCount}++++${edgeInputNodeContentsA!.index}^${edgeInputNodeContentsB!.index}....${edgeCommonNodeContentsA!.index}*${edgeCommonNodeContentsB!.index},,,,${edgeOutputNodeContentsA!.index}&${edgeOutputNodeContentsB!.index}',
                    );
                  }
                  if ((replicationCount == null) || (replicationCount == 0)) {
                    replicationCount = 1;
                  }
                  print('(FF444B)${_indexIndex}....${replicationCount}');
                  Navigator.pop(context);

                  if (edgeInputNodeContentsA == null) {
                    toastification.show(
                      context: context,
                      title: Text('Set input edge'),
                    );
                    print('(FF444C)${_indexIndex}');
                    Navigator.pop(context);
                  } else {
                    if (edgeCommonNodeContentsA == null) {
                      toastification.show(
                        context: context,
                        title: Text('Set common edge'),
                      );
                      print('(FF444D)${_indexIndex}');
                      Navigator.pop(context);
                    } else {
                      if (edgeOutputNodeContentsA == null) {
                        toastification.show(
                          context: context,
                          title: Text('Set output edge'),
                        );
                        print('(FF444E)${_indexIndex}');
                        Navigator.pop(context);
                      } else {
                        print('(FF441A)${replicationCount}');
                        dumpGraph();
                        if (replicationCount > 9) {
                          replicationCount = 10;
                        }
                        for (int j = 0; j < replicationCount; j++) {
                          /*_controller.*/
                          deleteEdgeByData(
                            nodeA: currentNodeContents,
                            nodeB: edgeOutputNodeContentsB!,
                          );
                          print('(FF441B)${_indexIndex}');
                          dumpGraph();
                          // _controller.addNode(
                          //   NodeContents(index: _indexIndex, kind: data.kind),
                          // );
                          // _indexIndex++;
                          print('(FF441C)${_indexIndex}');
                          dumpGraph();
                          NodeContents nextNodeContents = NodeContents(
                            index: _indexIndex,
                            kind: currentNodeContents.kind,
                          );
                          /*_controller.*/
                          addEdgeByData(
                            nodeA: currentNodeContents,
                            nodeB: nextNodeContents,
                          );
                          _indexIndex++;
                          NodeContents? nextNode = getNodeContentsFromIndex(
                            nextNodeContents.index!,
                          );
                          print('(FF441D)${_indexIndex}');
                          dumpGraph();
                          /*_controller.*/
                          addEdgeByData(
                            nodeA: edgeCommonNodeContentsA!,
                            nodeB: nextNode!,
                          );
                          print('(FF441E)${nextNode.index}');
                          dumpGraph();
                          /*_controller.*/
                          addEdgeByData(
                            nodeA: nextNode,
                            nodeB: edgeOutputNodeContentsB!,
                          );
                          print('(FF441F)${_indexIndex}');
                          dumpGraph();

                          for (
                            int i = 0;
                            i < _controller.graph.nodes.length;
                            i++
                          ) {
                            _controller.graph.nodes[i].static();
                          }
                          print(
                            '(FF440)${replicationCount}>>>>${j}++++${edgeInputNodeContentsA!.index}....${edgeCommonNodeContentsA!.index},,,,${edgeOutputNodeContentsB!.index}',
                          );
                          dumpGraph();
                          edgeInputNodeContentsA = currentNodeContents;
                          edgeInputNodeContentsB = nextNodeContents;
                          edgeOutputNodeContentsA = nextNodeContents;
                        }
                        edgeInputNodeContentsA = null;
                        edgeCommonNodeContentsA = null;
                        edgeOutputNodeContentsA = null;
                        edgeInputNodeContentsB = null;
                        edgeCommonNodeContentsB = null;
                        edgeOutputNodeContentsB = null;
                        Navigator.pop(context);
                      }
                    }
                  }
                },
              ),

              ElevatedButton(
                child: const Text('Make chain'),
                onPressed: () {
                  print('(FF700)');
                  NodeContents currentNodeContents = data;
                  double rootNodeX = getNodePosition(data.index)!.x;
                  double rootNodeY = getNodePosition(data.index)!.y;
                  int? replicationCount =
                      int.tryParse(textEditingController!.text) ?? 1;
                  for (int i = 0; i < replicationCount; i++) {
                    NodeContents nextNodeContents = NodeContents(
                      index: _indexIndex,
                      kind: currentNodeContents.kind,
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
                    print('(FF747)${rootNodeX}....${rootNodeY},,,,${nextPos}');
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
  }

  bool isIndexEqual(NodeContents? n1, NodeContents? n2) {
    if ((n1 == null) || (n2 == null)) return false;
    if (n1.index == n2.index) return true;
    return false;
  }

  Widget drawNode(NodeContents data) {
    print('(FF430)${data.index}');
    String inputString = data.input ?? '';
    switch (data.kind) {
      case (NodeKind.kindDouble):
        return Text('${inputString}>${getResult(data)}');
      case (NodeKind.kindDateTime):
        return Text('${inputString}>${getResult(data)}');
      case (NodeKind.kindString):
        return Text('${inputString}>${getResult(data)}');
      case (null):
        return Text('ERROR');
    }
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

                onDraggingStart: (data) {
                  setState(() {
                    _draggingData = data;
                  });
                },
                onDraggingEnd: (data) {
                  setState(() {
                    _draggingData = null;
                  });
                },
                onDraggingUpdate: (data) {},
                nodesBuilder: (context, data) {
                  /*               if (edgeStartNodeContents == null) {
                    print('(FF200A)${data.index}....${edgeStartNodeContents}');
                  } else {
                    print(
                      '(FF200B)${data.index}....${edgeStartNodeContents!.index}',
                    );
                  }*/
                  final Color color;
                  // if (_draggingData == data) {
                  //   color = Colors.blue;
                  // } else if (_nodes.contains(data)) {
                  //   color = Colors.green;
                  // } else {
                  //   color = Colors.red;
                  // }
                  switch (data.kind) {
                    case NodeKind.kindDouble:
                      color = Colors.purple;
                      break;
                    case NodeKind.kindDateTime:
                      color = Colors.red;
                      break;
                    case NodeKind.kindString:
                      color = Colors.green;
                      break;
                    case null:
                      color = Colors.black;
                      break;
                  }
                  return GestureDetector(
                    onSecondaryTap: () {
                      print('(FF10)');
                      onNodeTap(data);
                    },

                    child: Container(
                      width: (data.kind == NodeKind.kindDateTime) ? 250 : 110,
                      height: 24,
                      decoration: BoxDecoration(
                        color: setBoxColor(data),
                        borderRadius: BorderRadius.circular(1),
                        border: Border.all(color: color, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: _scale > 0.5
                          ? Row(
                              children: [
                                Container(
                                  width: (data.kind == NodeKind.kindDateTime)
                                      ? 200
                                      : 100,
                                  height: 22,
                                  //     color: Colors.amber,
                                  child: drawNode(data),
                                ),
                              ],
                            )
                          : null,
                    ),
                  );
                },
                edgesBuilder: (context, a, b, distance) {
                  Color color = Colors.black87;

                  if ((isIndexEqual(edgeInputNodeContentsA, a)) &&
                      (isIndexEqual(edgeInputNodeContentsB, b)))
                    color = Colors.red;
                  if ((isIndexEqual(edgeCommonNodeContentsA, a)) &&
                      (isIndexEqual(edgeCommonNodeContentsB, b)))
                    color = Colors.blue;
                  if ((isIndexEqual(edgeOutputNodeContentsA, a)) &&
                      (isIndexEqual(edgeOutputNodeContentsB, b)))
                    color = Colors.green;
                  print(
                    '(FF762)${a.index}....${b.index},,,,${isEdgeActive(indexA: a.index, indexB: b.index)}',
                  );
                  dumpGraph();
                  if (!isEdgeActive(indexA: a.index, indexB: b.index)) {
                    color = Colors.grey;
                  }
                  return GestureDetector(
                    onTap: () {
                      final edge = "$a <-> $b";
                      setState(() {
                        if (_edges.contains(edge)) {
                          _edges.remove(edge);
                        } else {
                          _edges.add(edge);
                        }
                        print("onTap $a <-$distance-> $b");
                      });
                    },
                    child: arrowEdge(
                      distance: distance,
                      a: a,
                      b: b,
                      color: color,
                    ),
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
    print('(FF2)${distance}....${reverse}');

    return Transform.rotate(
      angle: angle,
      child: ClipPath(
        clipper: DrawArrow(a: a, b: b),
        child: GestureDetector(
          onSecondaryTap: () {
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
                              print(
                                '(FF763)${isEdgeActive(indexA: a.index, indexB: b.index)}',
                              );
                              setEdgeExtraIsActive(
                                indexA: a.index,
                                indexB: b.index,
                                isActive: !isEdgeActive(
                                  indexA: a.index,
                                  indexB: b.index,
                                ),
                              );
                              print(
                                '(FF76)${a.index}....${b.index},,,,${isEdgeActive(indexA: a.index, indexB: b.index)}',
                              );
                              dumpGraph();
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

  Widget _buildMenu(BuildContext context) {
    return Wrap(
      children: [
        ElevatedButton(
          onPressed: () {
            NodeContents n = NodeContents(
              index: _indexIndex,
              kind: NodeKind.kindDouble,
            );
            _controller.addNode(n);
            _indexIndex++;
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
            _controller.needUpdate();
            _running = true;
          },
          child: const Text('update'),
        ),
        ElevatedButton(
          onPressed: () {
            _controller.center();
          },
          child: const Text('center'),
        ),
        ElevatedButton(
          onPressed: () {
            dumpGraph();
          },
          child: Text('dump'),
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              if (_json != null) {
                _controller.graph = ForceDirectedGraph.fromJson(
                  _json!,
                  /*deserializeData: NodeContents.fromJson*/
                );
                _clearData();
                _json = null;
              } else {
                _json = _controller.toJson();
                print('(FF710)${_json}');
              }
            });
          },
          child: Text(_json == null ? 'save' : 'load'),
        ),
        ElevatedButton(
          onPressed: () {
            _controller.scale = 1;
            print('(FF741)${_controller.graph.nodes.length}');
            for (int i = 0; i < _controller.graph.nodes.length; i++) {
              NodeContents n = _controller.graph.nodes[i].data;
              print('(FF742)${i}....${n}');
              _controller.deleteNodeByData(n);
              print('(FF749)${i}');
            }
          },
          child: const Text('reset'),
        ),
        ElevatedButton(
          child: const Text('Add edges'),
          onPressed: () {
            for (int i = 0; i < _controller.graph.nodes.length; i++) {
              if (_controller.graph.nodes[i].data.isStartNode ??
                  false)
                for (
                int j = 0;
                j < _controller.graph.nodes.length;
                j++
                ) {
                  if (_controller.graph.nodes[j].data.isEndNode ??
                      false) {
                    addEdgeByData(
                      nodeA: _controller.graph.nodes[i].data,
                      nodeB: _controller.graph.nodes[j].data,
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
            setState(() {

            });
          },
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
    _nodes.clear();
    _edges.clear();
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
  print('(FF9)${index}....${x}');
  return x;
}

class DrawArrow extends CustomClipper<Path> {
  NodeContents? a;
  NodeContents? b;
  DrawArrow({this.a, this.b});
  @override
  Path getClip(Size size) {
    double aX = _controller.graph.nodes.first.position.x;
    print(
      '(FF8)${a!.index}|${getX(index: a!.index)}...${b!.index}|${getX(index: b!.index)}',
    );
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
    print('(FF1)${size}');
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    // print('(FF3)');
    return true; /*throw UnimplementedError();*/
  }
}
