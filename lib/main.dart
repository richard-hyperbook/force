// ignore_for_file: avoid_print

import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_force_directed_graph/flutter_force_directed_graph.dart';
import 'package:matrix4_transform/matrix4_transform.dart';

const buildNumber = 3;
const double arrowHeight = 7;
const double arrowWidth = 7;
const double lineWidth = 3;
const double boxHeight = 25;
NodeContents? edgeStarNodeContents;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visual Spreadsheet ${buildNumber}',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(title: 'Visual Spreadsheet ${buildNumber}'),
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
        print('(FF332)${_controller.graph.nodes[i].data.index}++++${_controller.graph.nodes[i].data.doubleResult}....${_controller.graph.nodes[i].data.dateTimeResult},,,,${_controller.graph.nodes[i].data.stringResult}');
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


  dynamic action({dynamic total, Edge? edge, isFirstEdge = false}) {
    dynamic result;
   const Map<NodeKind, NodeOperation> mapADoubleBDouble = {
     NodeKind.kindDouble: NodeOperation.addDouble,
     NodeKind.kindDateTime: NodeOperation.addDayToDate,
     NodeKind.kindString: NodeOperation.addDoubleToString,
   };

    const Map<NodeKind, Map> aMap = {NodeKind.kindDouble: mapADoubleBDouble};
    NodeKind bKind = edge!.b.data.kind;
    NodeKind aKind = edge.a.data.kind;
    NodeOperation op = aMap[aKind]![bKind]!;
    switch(op){
      case(NodeOperation.addDouble):
        double inputValue = 0.0;
        if(isFirstEdge){
          inputValue = double.tryParse(edge.b.data.input)?? 0;
        }
        result = (total?? 0.0) + inputValue + (edge.a.data.doubleResult?? 0);
        //setControllerResult(index: edge.b.data.index, value: result);
        print('(FF330)${edge.b.data.index},,,,${result}....${edge.b.data.doubleResult}');
        break;
      case(NodeOperation.addDayToDate):
        edge.b.data.DateTimeResult = edge.b.data.input + edge.a.data.dateTimeResult;
        break;
      case(NodeOperation.addDoubleToString):
        edge.b.data.stringResult = edge.b.data.input + edge.a.data.stringResult;
        break;
      case(NodeOperation.latestDate):
        edge.b.data.result = edge.b.data.input + edge.a.data.result;
        break;
      case(NodeOperation.illegal):
        edge.b.data.result = edge.b.data.input + edge.a.data.result;
        break;
    }
    print('(FF320)${op}....${edge.b.data.input},,,,${edge.a.data.doubleResult}++++${edge.b.data.doubleResult}????${result}');
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
        total = action(total: total, edge: edge, isFirstEdge: isFirstEdge);
        edgeFound = true;
        isFirstEdge = false;
      }
    }
    if(edgeFound) {
      setControllerResult(index: nodeContents.index, value: total);
    } else {
      setControllerResult(index: nodeContents.index, value: double.tryParse(nodeContents.input!)?? 0.0);
      total = double.tryParse(nodeContents.input!)?? 0.0;
    }
    return total.toString();
  }

  Color setBoxColor(NodeContents node) {
    if (edgeStarNodeContents == null) {
      print('(FF201)${node}');
      return Colors.white;
    }
    print('(FF202)${edgeStarNodeContents!.index}....${node.index}');
    if (node.index == edgeStarNodeContents!.index) {
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
                          input: '',
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
                    child: const Text('Add null number'),
                    onPressed: () {
                      print('(FF13AN)');

                      _controller.addEdgeByData(
                        data,
                        NodeContents(
                          kind: NodeKind.kindDouble,
                          index: _indexIndex,
                          input: null,
                        ),
                      );
                      _indexIndex++;
                      _nodes.clear();
                      _edges.clear();
                      Navigator.of(context).pop();
                    },
                  ),
                  ElevatedButton(
                    child: const Text('Add null date'),
                    onPressed: () async {
                      print('(FF13BN)');

                      _controller.addEdgeByData(
                        data,
                        NodeContents(
                          kind: NodeKind.kindDateTime,
                          index: _indexIndex,
                          input: null,
                        ),
                      );
                      _indexIndex++;
                      _nodes.clear();
                      _edges.clear();
                      Navigator.of(context).pop();
                    },
                  ),
                  ElevatedButton(
                    child: const Text('Add null text'),
                    onPressed: () {
                      print('(FF13CN)');

                      _controller.addEdgeByData(
                        data,
                        NodeContents(
                          kind: NodeKind.kindString,
                          index: _indexIndex,
                          input: null,
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

              ElevatedButton(
                child: const Text('Start edge'),
                onPressed: () {
                  setState(() {
                    print('(FF16)');
                    edgeStarNodeContents = data;
                  });

                  Navigator.of(context).pop();
                },
              ),

              ElevatedButton(
                child: const Text('End edge'),
                onPressed: () {
                  print('(FF17)');
                  if (edgeStarNodeContents != null) {
                    _controller.addEdgeByData(edgeStarNodeContents!, data);
                    edgeStarNodeContents = null;
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

  Widget drawNode(NodeContents data){
    switch(data.kind){
      case(NodeKind.kindDouble):
        return Text('${data.input}>${getResult(data)}');
      case(NodeKind.kindDateTime):
        return Text('${data.input}>${getResult(data)}');
      case(NodeKind.kindString):
        return Text('${data.input}>${getResult(data)}');
      case(null):
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
                if (edgeStarNodeContents == null) {
                  print('(FF200A)${data.index}....${edgeStarNodeContents}');
                } else {
                  print(
                    '(FF200B)${data.index}....${edgeStarNodeContents!.index}',
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
                switch (data.kind){
                  case NodeKind.kindDouble: color = Colors.purple; break;
                  case NodeKind.kindDateTime: color = Colors.red; break;
                  case NodeKind.kindString: color = Colors.green; break;
                  case null: color = Colors.black; break;

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
                                width: 100,
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
                final Color color;
                if (_draggingData == a || _draggingData == b) {
                  color = Colors.purple;
                } else if (_edges.contains("$a <-> $b")) {
                  color = Colors.green;
                } else {
                  color = Colors.blue;
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
                  child: arrowEdge(distance: distance, a: a, b: b),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget arrowEdge({NodeContents? a, NodeContents? b, double distance = 0}) {
    double angle = 0;
    bool reverse = false;
    if (getX(index: a!.index)! > getX(index: b!.index)!) {
      angle = pi;
    }
    print('(FF2)${distance}....${angle}');
    return Transform.rotate(
      angle: angle,
      child: ClipPath(
        clipper: TsClip1(a: a, b: b),
        child: Container(
          width: distance,
          height: boxHeight * 2,
          color: Colors.black87,
        ),
      ),
    );
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

class TsClip1 extends CustomClipper<Path> {
  NodeContents? a;
  NodeContents? b;
  TsClip1({this.a, this.b});
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
