import 'dart:convert';
import 'dart:math';
import '../main.dart';

import 'package:vector_math/vector_math.dart';

import 'config.dart';
import 'edge.dart';
import 'kd_tree.dart';
import 'node.dart';
import 'group.dart';

typedef NodeDataSerializer = dynamic Function(NodeContents data);
typedef NodeDataDeserializer = NodeContents Function(dynamic data);

class ForceDirectedGraph {
  final List<Node> nodes = [];
  final List<Edge> edges = [];
  final List<Group> groups = [];
  final GraphConfig config;

  /// Create an empty graph.
  ForceDirectedGraph({this.config = const GraphConfig()});

  /// Generate a random tree graph.
  /// [nodeCount] is the max node count.
  /// [maxDepth] is the max depth of the tree.
  /// [n] is the max children count of a node.
  /// [generator] is the generator of the node data. Make sure the data is unique.
  ForceDirectedGraph.generateNTree({
    required int nodeCount,
    required int maxDepth,
    required int n,
    required NodeContents Function() generator,
    this.config = const GraphConfig(),
  }) {
    Random random = Random();
    final root = Node(generator());
    nodes.add(root);
    _createNTree(root, nodeCount - 1, maxDepth - 1, n, random, generator);
  }

  /// Generate a graph with n nodes, no edges.
  /// [nodeCount] is the node count.
  /// [generator] is the generator of the node data. Make sure the data is unique.
  ForceDirectedGraph.generateNNodes({
    required int nodeCount,
    required NodeContents Function() generator,
    this.config = const GraphConfig(),
  }) {
    for (int i = 0; i < nodeCount; i++) {
      final node = Node(generator());
      nodes.add(node);
    }
  }

  NodeContents nodeDataFromMap(
    Map<String, dynamic> nd,
    NodeDataDeserializer? deserializeData1,
  ) {
    NodeContents nc = deserializeData1!(nd);
    print('(FF1010)${nc}');
    return nc;
  }

  Node nodeFromMap(
    Map<String, dynamic> nodeComplete,
    NodeDataDeserializer? deserializeData2,
  ) {
    final nd = nodeComplete['data'];
    final pd = nodeComplete['position'];
    print(
      '(FF1002)${nd}....${nodeComplete}>>>>${deserializeData2.runtimeType}',
    );
    Node node = Node(
      nodeDataFromMap(nd, deserializeData2),
      Vector2(pd['x'], pd['y']),
    );
    return node;
  }

  Node? getNodeFromIndexLocal(int? uid) {
    print('(FF4020)${uid}....${nodes.length}');
    for (int i = 0; i < nodes.length; i++) {
      print('(FF4021)${uid}....${nodes[i].data.uid},,,,${nodes[i]}');
      if (uid == nodes[i].data.uid) {
        return nodes[i];
      }
    }
    return null;
  }

  /// Create a graph from json.
  /// [resetPosition] will reset the position of the nodes.
  ForceDirectedGraph.fromJson(
    String json, {
    NodeDataDeserializer? deserializeData3,
    bool resetPosition = false,
    this.config = const GraphConfig(),
  }) {
    final Map<String, dynamic> decodedJson = jsonDecode(json);
    print(
      '(FF1001)${json}....${decodedJson}>>>>${deserializeData3.runtimeType}',
    );

    for (final nodeData in decodedJson['nodes']) {
      Node node = nodeFromMap(nodeData, deserializeData3);
      nodes.add(node);
      // print('(FF1003A)${node}....${node.data!.uid},,,,${node.data.kind}----${node.data.doubleResult}');
      print(
        '(FF1003B)${nodes.length}<<<<${node}....${(node.data as NodeContents).uid},,,,${node.position}',
      );
    }
    //The argument type 'NodeDataDeserializer<T>?' can't be assigned to the parameter type 'NodeDataDeserializer<Node<dynamic>>?'.
    for (final edgeData in decodedJson['edges']) {
      print('(FF1004)${edgeData}>>>>${deserializeData3.runtimeType}');
      Node nodeAFromMap = nodeFromMap(edgeData['a'], deserializeData3);
      Node nodeBFromMap = nodeFromMap(edgeData['b'], deserializeData3);
      EdgeExtra ee = EdgeExtra(isActive: edgeData['edgeExtra']['isActive']);
      Node nodeA = getNodeFromIndexLocal(nodeAFromMap.data.uid)!;
      Node nodeB = getNodeFromIndexLocal(nodeBFromMap.data.uid)!;
      Edge edge = Edge(nodeA, nodeB, ee);
      edges.add(edge);
      print('(FF1005)${nodeA}....${nodeB},,,,${edge}');
    }
    if (decodedJson.keys.contains('groups')) {
      for (final groupData in decodedJson['groups']) {
        Group group = groupFromMap(groupData);
        groups.add(group);
        print(
          '(FH85)${groups.length}<<<<${group}....${group.name},,,,${group.nodeUids}',
        );
      }
    }
  }

  void _createNTree(
    Node node,
    int remainingNodes,
    int remainingDepth,
    int n,
    Random random,
    Function() generator,
  ) {
    if (remainingNodes <= 0 || remainingDepth == 0) {
      return;
    }

    int nodesAtThisLevel = min(n, remainingNodes);
    final children = [];
    for (int i = 0; i < nodesAtThisLevel; i++) {
      final newNode = Node(generator());
      children.add(newNode);
      addNode(newNode);
      addEdge(
        Edge(node, newNode, EdgeExtra(isActive: true)),
      ); //TOD handle edgextra
      remainingNodes--;
    }

    for (final childNode in children) {
      if (remainingNodes <= 0) {
        break;
      }
      int childNodeCount = random.nextInt(remainingNodes + 1);
      _createNTree(
        childNode,
        childNodeCount,
        remainingDepth - 1,
        n,
        random,
        generator,
      );
      remainingNodes -= childNodeCount;
    }
  }

  void addNode(Node node) {
    if (nodes.contains(node)) {
      throw Exception('Node already exists');
    }
    nodes.add(node);
  }

  void addEdge(Edge edge) {
    if (edges.contains(edge)) {
      throw Exception('Edge already exists');
    }
    edges.add(edge);
  }

  void deleteNode(Node node) {
    nodes.remove(node);
    edges.removeWhere((edge) => edge.a == node || edge.b == node);
  }

  void deleteEdge(Edge edge) {
    edges.remove(edge);
  }

  bool updateAllNodes() {
    final kdTree = KDTree.fromNode(nodes);
    for (final node in nodes) {
      final others = kdTree.findNeighbors(node.position, config.repulsionRange);
      for (final other in others) {
        if (node == other) continue;
        final repulsionForce = node.calculateRepulsionForce(
          other,
          k: config.repulsion,
        );
        node.applyForce(repulsionForce);
      }
    }
    for (final edge in edges) {
      final attractionForce = edge.calculateAttractionForce(
        k: config.elasticity,
        length: config.length,
      );
      final attractionForceDirectionA = edge
          .calculateAttractionForceDirectionA();
      final fa = attractionForceDirectionA * attractionForce;
      edge.a.applyForce(fa);
      edge.b.applyForce(-fa);
    }
    bool positionUpdated = false;
    for (final node in nodes) {
      positionUpdated |= node.updatePosition(
        scaling: config.scaling,
        minVelocity: config.minVelocity,
        maxStaticFriction: config.maxStaticFriction,
        damping: config.damping,
      );
    }
    return positionUpdated;
  }

  void unStaticAllNodes() {
    for (final node in nodes) {
      node.unStatic();
    }
  }

  @override
  String toString() {
    return "\nnodes:\n$nodes,\nedges:\n$edges";
  }

  String toJson({NodeDataSerializer? serializeData}) {
    print('(FF2001)${serializeData}....${nodes},,,,${edges}');
    return jsonEncode({
      'nodes': nodes
          .map(
            (e) => {
              'data': serializeData == null ? e.data : serializeData(e.data),
              'position': {'x': e.position.x, 'y': e.position.y},
            },
          )
          .toList(),
      'edges': edges
          .map(
            (e) => {
              'a': /*serializeData == null ? e.a.data :*/ /*serializeData(e.a.data)*/
                  {
                    'data': serializeData == null
                        ? e.a.data
                        : serializeData(e.a.data),
                    'position': {'x': e.a.position.x, 'y': e.a.position.y},
                  },
              'b': /*serializeData == null ? e.b.data : */ /*serializeData(e.a.data)*/
                  {
                    'data': serializeData == null
                        ? e.b.data
                        : serializeData(e.b.data),
                    'position': {'x': e.b.position.x, 'y': e.b.position.y},
                  },

              // 'b': serializeData == null ? e.b.data : serializeData(e.b.data),
              'edgeExtra': e.edgeExtra.toJson(),
            },
          )
          .toList(),
      'groups': groups.map((e) => e.toJson()).toList(),
    });
  }
}
