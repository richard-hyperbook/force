// ignore_for_file: avoid_print

import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_force_directed_graph/flutter_force_directed_graph.dart';
import 'package:matrix4_transform/matrix4_transform.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';

const buildNumber = 5;
const double arrowHeight = 7;
const double arrowWidth = 7;
const double lineWidth = 3;
const double boxHeight = 25;
NodeContents? edgeStartNodeContents;
NodeContents? edgeInputNodeContents;
NodeContents? edgeCommonNodeContents;
NodeContents? edgeOutputNodeContents;

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
  TextEditingController? textEditingController = TextEditingController(
    text: '',
  );
  NodeContents({
    required this.index,
    required this.kind,
    this.input,
    this.doubleResult,
    this.dateTimeResult,
    this.stringResult,
  });
}

int _indexIndex = 0;

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

late final ForceDirectedGraphController<NodeContents> _controller;

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
      _controller.needUpdate();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  NodeContents? getNodeContentsFromIndex(int index){
    for (int i = 0; i < _controller.graph.nodes.length; i++){
      if(_controller.graph.nodes[i].data.index == index){
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
    for (var node in _controller.graph.nodes) {
      if (node.data.index == index) {
        node.data.input = value;
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
        isFirstEdge = false;
      }
    }
    if (edgeFound) {
      setControllerResult(index: nodeContents.index, value: total);
    } else {
      setControllerResult(
        index: nodeContents.index,
        value: double.tryParse(nodeContents.input!) ?? 0.0,
      );
      total = double.tryParse(nodeContents.input!) ?? 0.0;
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
    if (edgeStartNodeContents == null) {
      print('(FF201)${node}');
      return Colors.white;
    }
    print('(FF202)${edgeStartNodeContents!.index}....${node.index}');
    if (node.index == edgeStartNodeContents!.index) {
      return Colors.amber;
    } else {
      return Colors.white;
    }
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
        return AlertDialog(
          title: const Text('Enter Value'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: data.textEditingController,
                onChanged: (value) {
                  print('(FF12)');
                },
              ),

              ElevatedButton(
                child: const Text('Enter'),
                onPressed: () {
                  String value = data.textEditingController!.text;
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

                      _controller.addEdgeByData(
                        data,
                        NodeContents(
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

                      _controller.addEdgeByData(
                        data,
                        NodeContents(
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

                      _controller.addEdgeByData(
                        data,
                        NodeContents(
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
                              _controller.deleteEdgeByData(
                                _controller.graph.edges[i].a.data,
                                _controller.graph.edges[i].a.data,
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
                    child: const Text('Start edge'),
                    onPressed: () {
                      setState(() {
                        print('(FF16)');
                        edgeStartNodeContents = data;
                      });

                      Navigator.of(context).pop();
                    },
                  ),

                  ElevatedButton(
                    child: const Text('End edge'),
                    onPressed: () {
                      print('(FF17)');
                      if (edgeStartNodeContents != null) {
                        _controller.addEdgeByData(edgeStartNodeContents!, data);
                        edgeStartNodeContents = null;
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              ElevatedButton(
                child: const Text('Replicate node'),
                onPressed: () {
                  int? replicationCount = int.tryParse(
                    data.textEditingController!.text,
                  );
                  print(
                    '(FF444A)${replicationCount}++++${edgeInputNodeContents!.index}....${edgeCommonNodeContents!.index},,,,${edgeOutputNodeContents!.index}',
                  );
                  if (replicationCount == null) {
                     replicationCount = 1;
                     print('(FF444B)${_indexIndex}');
                     Navigator.pop(context);
                  } else {
                    if (edgeInputNodeContents == null) {
                      toastification.show(
                        context: context,
                        title: Text('Set input edge'),
                      );
                      print('(FF444C)${_indexIndex}');
                      Navigator.pop(context);
                    } else {
                      if (edgeCommonNodeContents == null) {
                        toastification.show(
                          context: context,
                          title: Text('Set common edge'),
                        );
                        print('(FF444D)${_indexIndex}');
                        Navigator.pop(context);
                      } else {
                        if (edgeOutputNodeContents == null) {
                          toastification.show(
                            context: context,
                            title: Text('Set output edge'),
                          );
                          print('(FF444E)${_indexIndex}');
                          Navigator.pop(context);
                        }

                        print('(FF441A)${_indexIndex}');
                        dumpGraph();
                        for(int j = 0; j < replicationCount; j++) {
                          _controller.deleteEdgeByData(
                            data,
                            edgeOutputNodeContents!,
                          );
                          print('(FF441B)${_indexIndex}');
                          dumpGraph();
                          // _controller.addNode(
                          //   NodeContents(index: _indexIndex, kind: data.kind),
                          // );
                          // _indexIndex++;
                          print('(FF441C)${_indexIndex}');
                          dumpGraph();
                          _controller.addEdgeByData(
                            data,
                            NodeContents(index: _indexIndex, kind: data.kind),
                          );
                          NodeContents? newNode = getNodeContentsFromIndex(
                              _indexIndex);
                          print('(FF441D)${_indexIndex}');
                          dumpGraph();

                          _controller.addEdgeByData(
                            edgeCommonNodeContents!,
                            newNode!,
                          );
                          print('(FF441E)${newNode.index}');
                          dumpGraph();
                          _controller.addEdgeByData(
                            newNode,
                            edgeOutputNodeContents!,
                          );
                          print('(FF441AF)${_indexIndex}');
                          dumpGraph();

                          edgeInputNodeContents = null;
                          edgeCommonNodeContents = null;
                          edgeOutputNodeContents = null;
                          for (int i = 0; i < _controller.graph.nodes
                              .length; i++) {
                            _controller.graph.nodes[i].static();
                          }
                          print(
                            '(FF440)${j}++++${edgeInputNodeContents!
                                .index}....${edgeCommonNodeContents!
                                .index},,,,${edgeOutputNodeContents!.index}',
                          );
                          edgeInputNodeContents = newNode;
                          _indexIndex++;
                        }
                        edgeInputNodeContents = null;
                        edgeCommonNodeContents = null;
                        edgeOutputNodeContents = null;
                        Navigator.pop(context);
                      }
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget drawNode(NodeContents data) {
    print('(FF430)${data.index}');
    String inputString = data.input?? '';
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
                if (edgeStartNodeContents == null) {
                  print('(FF200A)${data.index}....${edgeStartNodeContents}');
                } else {
                  print(
                    '(FF200B)${data.index}....${edgeStartNodeContents!.index}',
                  );
                }
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
              if(edgeInputNodeContents != null) {
                if (a.index == edgeInputNodeContents!.index) {
                  color = Colors.red;
                }
              }
              if(edgeCommonNodeContents != null) {
                if (a.index == edgeCommonNodeContents!.index) {
                  color = Colors.blue;
                }
              }
              if(edgeOutputNodeContents != null) {
                if (b.index == edgeOutputNodeContents!.index) {
                  color = Colors.green;
                }
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
                  child: arrowEdge(distance: distance, a: a, b: b, color: color),
                );
              },
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

  Widget arrowEdge({NodeContents? a, NodeContents? b, double distance = 0, color = Colors.black87}) {
    double angle = 0;
    bool reverse = false;
    if (getX(index: a!.index)! > getX(index: b!.index)!) {
      angle = pi;
    }
    print('(FF2)${distance}....${angle}');
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
                              _controller.deleteEdgeByData(a, b);
                              _controller.addEdgeByData(b, a);
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
                              edgeInputNodeContents = a;
                              Navigator.of(context).pop();
                            },
                          ),
                          ElevatedButton(
                            child: const Text('Set as common'),
                            onPressed: () {
                              edgeCommonNodeContents = a;
                              Navigator.of(context).pop();
                            },
                          ),
                          ElevatedButton(
                            child: const Text('Set as output'),
                            onPressed: () {
                              edgeOutputNodeContents = b;
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

  void dumpGraph(){
    for (var node in _controller.graph.nodes) {
      print(
        '(FFDN)${node.data.index}<<<<${node.data.input}££££${node.data.kind};;;;${node.data.doubleResult}::::${node.data.dateTimeResult}@@@@${node.data.stringResult}',
      );
    }
    for (var edge in _controller.graph.edges) {
      print(
        '(FFDE)${edge.a.data.index}${edge.a.data.kind}....${edge.b.data.index}${edge.b.data.kind}',
      );
    }
  }

  Widget _buildMenu(BuildContext context) {
    return Wrap(
      children: [
        ElevatedButton(
          onPressed: _nodes.length > 2
              ? null
              : () {
                  if (_nodes.length == 2) {
                    final a = _nodes.first;
                    final b = _nodes.last;
                    _controller.addEdgeByData(a, b);
                  } else if (_nodes.length == 1) {
                    final a = _nodes.first;
                    final l = _controller.graph.nodes.length;
                    final random = Random();
                    final randomB =
                        _controller.graph.nodes[random.nextInt(l)].data;
                    try {
                      if (a != randomB) {
                        _controller.addEdgeByData(a, randomB);
                      }
                    } catch (e) {
                      // ignore
                    }
                  } else if (_nodes.isEmpty) {
                    final l = _controller.graph.nodes.length;
                    final random = Random();
                    final randomA = _controller.graph.nodes[random.nextInt(l)];
                    final randomB = _controller.graph.nodes[random.nextInt(l)];
                    try {
                      if (randomA != randomB) {
                        _controller.addEdgeByNode(randomA, randomB);
                      }
                    } catch (e) {
                      // ignore
                    }
                  }
                  _nodes.clear();
                  _edges.clear();
                },
          child: const Text('add edge'),
        ),
        ElevatedButton(
          onPressed: () {
            _controller.needUpdate();
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
                _controller.graph = ForceDirectedGraph.fromJson(_json!);
                _clearData();
                _json = null;
              } else {
                _json = _controller.toJson();
              }
            });
          },
          child: Text(_json == null ? 'save' : 'load'),
        ),
        ElevatedButton(
          onPressed: () {
            _controller.scale = 1;
            for (int i = 0; i < _controller.graph.nodes.length; i++){
              _controller.deleteNodeByData(getNodeContentsFromIndex(i)!);
            }
          },
          child: const Text('reset'),
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
    // print('(FF1)${size}');
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    // print('(FF3)');
    return true; /*throw UnimplementedError();*/
  }
}
