// ignore_for_file: avoid_print

import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_force_directed_graph/flutter_force_directed_graph.dart';
import 'package:matrix4_transform/matrix4_transform.dart';

const buildNumber = 2;
const double arrowHeight = 7;
const double arrowWidth = 7;
const double lineWidth = 3;
const double boxHeight = 25;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visual Spreadsheet ${buildNumber}',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(title: 'Visual Spreadsheet ${buildNumber}'),
    );
  }
}

class NodeContents {
  int? index;
  double? input;
  double? result;
  TextEditingController? textEditingController = TextEditingController(
    text: '0',
  );
  NodeContents({this.index, this.input, this.result});
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
  int _nodeCount = 0;
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
            nodeCount: 1,
            maxDepth: 20,
            n: 4,
            generator: () {
              _nodeCount++;
              return NodeContents(
                index: _indexIndex++,
                input: _nodeCount.toDouble(),
                result: 0,
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

  void setControllerResult({int? index, double? value}) {
    for (var node in _controller.graph.nodes) {
      if (node.data.index == index) {
        node.data.result = value;
        break;
      }
    }
  }

  void setControllerInput({int? index, double? value}) {
    for (var node in _controller.graph.nodes) {
      if (node.data.index == index) {
        node.data.input = value;
        break;
      }
    }
  }

  String getResult(NodeContents nodeContent) {
    double total = nodeContent.input!;
    for (var edge in _controller.graph.edges) {
      // print('(FF5)${edge.a.data.index}....${edge.b.data.index}');
      if (edge.b.data.index == nodeContent.index) {
        total = total + edge.a.data.result;
        print('(FF6)${edge.a.data.index}....${edge.b.data.index}++++${total}');
      }
    }
    setControllerResult(index: nodeContent.index, value: total);
    return total.toString();
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
                final Color color;
                if (_draggingData == data) {
                  color = Colors.blue;
                } else if (_nodes.contains(data)) {
                  color = Colors.green;
                } else {
                  color = Colors.red;
                }

                return GestureDetector(
                  onSecondaryTap: () {
                    print('(FF10)');

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
                                  String value =
                                      data.textEditingController!.text;
                                  double? doubleValue = double.tryParse(value);
                                  print(
                                    '(FF11)${value}....${doubleValue}++++${data.index}',
                                  );
                                  if (doubleValue != null) {
                                    setState(() {
                                      setControllerInput(
                                        index: data.index,
                                        value: doubleValue,
                                      );
                                    });
                                  }
                                  Navigator.of(context).pop(doubleValue);
                                },
                              ),
                              ElevatedButton(
                                child: const Text('Add node'),
                                onPressed: () {
                                  print('(FF13)');

                                  _nodeCount++;
                                  // _controller.addNode(
                                  //   NodeContents(index: _indexIndex, input: 0, result: 0),
                                  // );

                                  _controller.addEdgeByData(data, NodeContents(index: _indexIndex, input: 0, result: 0));
                                  _indexIndex++;

                                  _nodes.clear();
                                  _edges.clear();


                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  onTap: () {
                    print("onTap $data");
                    setState(() {
                      if (_nodes.contains(data)) {
                        _nodes.remove(data);
                      } else {
                        _nodes.add(
                          NodeContents(
                            index: _indexIndex,
                            input: data.input,
                            result: data.result,
                          ),
                        );
                        _indexIndex++;
                      }
                    });
                  },
                  child: Container(
                    width: 110,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                                child: Text('${data.input}|${getResult(data)}'),
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

                  /*Container(
                    width: distance,
                    height: 2,
                    color: color,
                    alignment: Alignment.center,
                    child: _scale > 0.5 ? Text('$a <-> $b') : null,
                  ),*/
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget arrowEdge({NodeContents? a, NodeContents? b, double distance = 0}) {
    // print('(FF2)${distance}');
    double angle = 0;
    bool reverse = false;
    if (getX(index: a!.index)! > getX(index: b!.index)!) {
      angle = pi;
    }
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
          onPressed: () {
            _nodeCount++;
            _controller.addNode(
              NodeContents(index: _indexIndex, input: 0, result: 0),
            );
            _indexIndex++;
            _nodes.clear();
            _edges.clear();
          },
          child: const Text('add node'),
        ),
        ElevatedButton(
          onPressed: _nodes.isEmpty
              ? null
              : () {
                  for (final node in _nodes) {
                    _controller.deleteNodeByData(node);
                  }
                  _nodes.clear();
                  _edges.clear();
                },
          child: const Text('del node'),
        ),
        const SizedBox(width: 4),
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
        /*        ElevatedButton(
          onPressed: _edges.isEmpty
              ? null
              : () {
            for (final edge in _edges) {
              final a = int.parse(edge.split(' <-> ').first);
              final b = int.parse(edge.split(' <-> ').last);
              _controller.deleteEdgeByData(a, b);
            }
            _nodes.clear();
            _edges.clear();
          },
          child: const Text('del edge'),
        ),*/
        ElevatedButton(
          onPressed: () {
            _controller.needUpdate();
          },
          child: const Text('update'),
        ),
        /* ElevatedButton(
          onPressed: () async {
            final result = await _showTreeDialogWithInput(context);
            if (result == null) return;
            setState(() {
              _clearData();
              _controller.graph = ForceDirectedGraph.generateNTree(
                nodeCount: result['nodeCount'] as int,
                maxDepth: result['maxDepth'] as int,
                n: result['n'] as int,
                generator: () {
                  _nodeCount++;
                  return _nodeCount;
                },
              );
            });
          },
          child: const Text('new tree'),
        ),*/
        ElevatedButton(
          onPressed: () async {
            final result = await _showNodeDialogWithInput(context);
            if (result == null) return;
            setState(() {
              _clearData();
              _controller.graph = ForceDirectedGraph.generateNNodes(
                nodeCount: result['nodeCount'] as int,
                generator: () {
                  _nodeCount++;
                  return NodeContents(
                    index: _indexIndex++,
                    input: 96,
                    result: 95,
                  );
                },
              );
            });
          },
          child: const Text('new nodes'),
        ),
        ElevatedButton(
          onPressed: () {
            _controller.center();
          },
          child: const Text('center'),
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _locatedTo++;
              _locatedTo = _locatedTo % _controller.graph.nodes.length;
              final data = _controller.graph.nodes[_locatedTo].data;
              _controller.locateTo(data);
            });
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
    _nodeCount = 0;
    _locatedTo = 0;
  }

  Future<Map<String, int>?> _showTreeDialogWithInput(BuildContext context) {
    final TextEditingController nodeCountController = TextEditingController(
      text: '50',
    );
    final TextEditingController maxDepthController = TextEditingController(
      text: '3',
    );
    final TextEditingController nController = TextEditingController(text: '3');

    return showDialog<Map<String, int>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Values'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nodeCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Node Count"),
              ),
              TextField(
                controller: maxDepthController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Max Depth"),
              ),
              TextField(
                controller: nController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Max Children"),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(null);
              },
            ),
            TextButton(
              child: const Text('Submit'),
              onPressed: () {
                try {
                  final result = {
                    'nodeCount': int.parse(nodeCountController.text),
                    'maxDepth': int.parse(maxDepthController.text),
                    'n': int.parse(nController.text),
                  };
                  Navigator.of(context).pop(result);
                } catch (e) {
                  Navigator.of(context).pop(null);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, int>?> _showNodeDialogWithInput(BuildContext context) {
    final TextEditingController nodeCountController = TextEditingController(
      text: '50',
    );

    return showDialog<Map<String, int>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Values'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nodeCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Node Count"),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(null);
              },
            ),
            TextButton(
              child: const Text('Submit'),
              onPressed: () {
                try {
                  final result = {
                    'nodeCount': int.parse(nodeCountController.text),
                  };
                  Navigator.of(context).pop(result);
                } catch (e) {
                  Navigator.of(context).pop(null);
                }
              },
            ),
          ],
        );
      },
    );
  }
}

double? getX({int? index}) {
  double? x;
  for (var node in _controller.graph.nodes) {
    if (node.data.index == index) {
      x = node.position.x;
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
