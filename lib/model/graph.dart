import 'dart:convert';
import 'dart:math';
import '../main.dart';

import 'package:vector_math/vector_math.dart';
import 'package:flutter/material.dart';
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

  Node? getNodeFromUidLocal(int? uid) {
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
      Node nodeAFromMap = nodeFromMap(edgeData['a'], deserializeData3);
      Node nodeBFromMap = nodeFromMap(edgeData['b'], deserializeData3);
      EdgeExtra ee = EdgeExtra(
        isActive: edgeData['edgeExtra']['isActive'],
        label: edgeData['edgeExtra']['label'],
      );
      print('(FF1004)${edgeData}>>>>${deserializeData3.runtimeType}????${ee}');
      Node nodeA = getNodeFromUidLocal(nodeAFromMap.data.uid)!;
      Node nodeB = getNodeFromUidLocal(nodeBFromMap.data.uid)!;
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


  int addToGraphfromJson(
      String json, {
        NodeDataDeserializer? deserializeData3,
        int uidMaster = 0,
      }) {
    final Map<String, dynamic> decodedJson = jsonDecode(json);
    print(
      '(FS1)${json}....${decodedJson}>>>>${deserializeData3.runtimeType}',
    );

    for (final nodeData in decodedJson['nodes']) {
      Node node = nodeFromMap(nodeData, deserializeData3);
      nodes.add(node);
      // print('(FF1003A)${node}....${node.data!.uid},,,,${node.data.kind}----${node.data.doubleResult}');
      print(
        '(FS2)${nodes.length}<<<<${node}....${(node.data as NodeContents).uid},,,,${node.position}',
      );
    }
    //The argument type 'NodeDataDeserializer<T>?' can't be assigned to the parameter type 'NodeDataDeserializer<Node<dynamic>>?'.
    for (final edgeData in decodedJson['edges']) {
      Node nodeAFromMap = nodeFromMap(edgeData['a'], deserializeData3);
      Node nodeBFromMap = nodeFromMap(edgeData['b'], deserializeData3);
      EdgeExtra ee = EdgeExtra(
        isActive: edgeData['edgeExtra']['isActive'],
        label: edgeData['edgeExtra']['label'],
      );
      print('(FS3)${edgeData}>>>>${deserializeData3.runtimeType}????${ee}');
      Node nodeA = getNodeFromUidLocal(nodeAFromMap.data.uid)!;
      Node nodeB = getNodeFromUidLocal(nodeBFromMap.data.uid)!;
      Edge edge = Edge(nodeA, nodeB, ee);
      edges.add(edge);
      print('(FS4)${nodeA}....${nodeB},,,,${edge}');
    }
    if (decodedJson.keys.contains('groups')) {
      for (final groupData in decodedJson['groups']) {
        Group group = groupFromMap(groupData);
        for (int i = 0; i < groups.length; i++){
          if (groups[i].name == group.name){
            group.name = group.name! + '+';
          }
        }
        groups.add(group);
        print(
          '(FS5)${groups.length}<<<<${group}....${group.name},,,,${group.nodeUids}',
        );
      }
    }


    Map<int, int> uidMap = {};
    for (var node in nodes) {
      if (node.data.uid! < 0) {
        int oldUid = node.data.uid!;
        debugPrint('(FT9)${oldUid}');
        uidMap[oldUid] = uidMaster;
        uidMaster++;
      }
    }
    for (var node in nodes) {
      if (node.data.uid! < 0) {
        node.data.uid = uidMap[node.data.uid];
      }
    }
    for (var edge in edges){
      if (edge.a.data.uid! < 0){
        edge.a.data.uid = uidMap[edge.a.data.uid];
      }
      if (edge.b.data.uid! < 0){
        edge.b.data.uid = uidMap[edge.b.data.uid];
      }
    }
    for (var group in groups){
      for (int i = 0; i < group.nodeUids!.length; i++){
        if (group.nodeUids![i] < 0){
          group.nodeUids![i] = uidMap[group.nodeUids![i]]!;
        }
      }
      if (group.groupNodeUid! < 0){
        group.groupNodeUid = uidMap[group.groupNodeUid]!;
      }
    }
    return uidMaster;
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
        print(
          '(FJ71)${repulsionForce}....${node.data.uid},,,,${other.data.uid}',
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

      print(
        '(FJ72)${fa}....${attractionForceDirectionA},,,,${attractionForce}++++${edge.a.data.uid}----${edge.b.data.uid}}',
      );
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

  String groupToJson({
    NodeDataSerializer? serializeData,
    required String groupName,
  }) {
    print('(FF2011)${serializeData}....${nodes},,,,${edges}****${groupName}');
    Group? group = getGroupFromGroupName(groupName);
    List<Node> nodesOfGroup = [];
    for (int i = 0; i < nodes.length; i++) {
      if ((group!.nodeUids)!.contains(nodes[i].data.uid!)) {
        Node negatedNode = cloneNode(nodes[i]);
        negatedNode.data.uid = -negatedNode.data.uid!;
        nodesOfGroup.add(negatedNode);
      }
    }
    int groupNodeUid = getGroupNodeUidFromGroupName(groupName)!;
  //  Node groupNode = getNodeFromUid(groupNodeUid)!;
    // nodesOfGroup.add(groupNode);
    List<Edge> edgesOfGroup = [];
    for (int i = 0; i < edges.length; i++) {
    
      int? uidA = edges[i].a.data.uid;
      int? uidB = edges[i].b.data.uid;
      debugPrint('(FS22A)${i}....${uidA},,,,${uidB}++++${group!.nodeUids}');
      if (((group!.nodeUids)!.contains(uidA)) &&
          ((group.nodeUids)!.contains(uidB))) {
        Edge negatedEdge = cloneEdge(edges[i]);
        negatedEdge.a.data.uid = -negatedEdge.a.data.uid!;
        negatedEdge.b.data.uid = -negatedEdge.b.data.uid!;
            edgesOfGroup.add(negatedEdge);
        debugPrint('(FS22B)${i}....${edgesOfGroup.length},,,,${negatedEdge}++++${group.name}');
      }
    }
    Group negatedGroup = cloneGroup(group!);
    for (int i = 0; i < group!.nodeUids!.length; i++){
      negatedGroup.nodeUids![i] = -negatedGroup.nodeUids![i];
    }
    negatedGroup.groupNodeUid = -negatedGroup.groupNodeUid!;
    return jsonEncode({
      'nodes': nodesOfGroup
          .map(
            (e) => {
              'data': serializeData == null ? e.data : serializeData(e.data),
              'position': {'x': e.position.x, 'y': e.position.y},
            },
          )
          .toList(),
      'edges': edgesOfGroup
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
      'groups': [negatedGroup].map((e) => e!.toJson()).toList(),
    });
  }
/*

  int addGroupToGraph(
    String json, {
    NodeDataDeserializer? deserializeData3,
    bool resetPosition = false,
    // this.config = const GraphConfig(),
    int uidMaster = 0,
  }) {
    final Map<String, dynamic> decodedJson = jsonDecode(json);
    debugPrint('(FR7A)${decodedJson}');
    Map<int, int> uidMap = {};
    var nodeList = decodedJson['nodes'];
    debugPrint('(FR8)$nodeList');
    for (var node in nodeList) {
      int oldUid = node['data']['uid'];
      debugPrint('(FR9)${oldUid}');
      uidMap[oldUid] = uidMaster;
      uidMaster++;
    }
    //Map<String, dynamic> decJson = decodedJson['nodes'];
    debugPrint('(FR10A)${uidMap}');

    for (final nodeData in nodeList) {
      debugPrint('(FR10B)${nodeData}');
      Node node = nodeFromMap(nodeData, deserializeData3);
      debugPrint('(FR10CA)${node}....${node.data.uid}');
      // node.data.uid = uidMap[node.data.uid];
      // debugPrint('(FR10CB)${node}....${node.data.uid}');
      nodes.add(node);
      print('(FR10D)${node}....${node.data!.uid},,,,${node.data.kind}----${node.data.doubleResult}');
      // print(
      //   '(FF1003B)${nodes.length}<<<<${node},,,,${node.position}',
      // );
    }
    //The argument type 'NodeDataDeserializer<T>?' can't be assigned to the parameter type 'NodeDataDeserializer<Node<dynamic>>?'.
    for (final edgeData in decodedJson['edges']) {
      // Node nodeAFromMap = nodeFromMap(edgeData['a'], deserializeData3);
      // Node nodeBFromMap = nodeFromMap(edgeData['b'], deserializeData3);
      EdgeExtra ee = EdgeExtra(
        isActive: edgeData['edgeExtra']['isActive'],
        label: edgeData['edgeExtra']['label'],
      );
      // print('(FF1004A)${edgeData}>>>>${nodeAFromMap}????${ee.label}');
      // print('(FF1004B)${nodeAFromMap.data.uid}');
      // int uidAReMapped = nodeAFromMap.data.uid!;
      // if (uidMap.keys.contains(nodeAFromMap.data.uid)){
      //   uidAReMapped = uidMap[nodeAFromMap.data.uid]!;
      // }
      // Node nodeA = getNodeFromUidLocal(uidAReMapped)!;
      // nodeA.data.uid = uidMap[nodeA.data.uid];
      // int uidBReMapped = nodeBFromMap.data.uid!;
      // if (uidMap.keys.contains(nodeBFromMap.data.uid)){
      //   uidBReMapped = uidMap[nodeBFromMap.data.uid]!;
      // }
      // Node nodeB = getNodeFromUidLocal(uidBReMapped)!;
      // nodeB.data.uid = uidMap[nodeB.data.uid];
      // Edge edge = Edge(nodeA, nodeB, ee);
      edges.add(edge);
      print('(FF1005)${nodeA}....${nodeB},,,,${edge}');
    }
    if (decodedJson.keys.contains('groups')) {
      for (final groupData in decodedJson['groups']) {
        Group group = groupFromMap(groupData);
        debugPrint('(FR99${groupData}....${group.groupNodeUid},,,,${group.nodeUids}');
        for (int i = 0; i < group.nodeUids!.length; i++){
          group.nodeUids![i] = uidMap[group.nodeUids![i]]!;
        }
        group.groupNodeUid = uidMap[group.groupNodeUid];
        groups.add(group);
        print(
          '(FH85)${groups.length}<<<<${group}....${group.name},,,,${group.nodeUids}',
        );
      }
    }
    return uidMaster;
  }
*/
}
