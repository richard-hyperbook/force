import 'dart:math';

import 'package:vector_math/vector_math.dart';

import 'node.dart';

class EdgeExtra {

  bool? isActive;
  EdgeExtra({this.isActive});

  Map<String, dynamic> toJson() {
    Map<String, dynamic> m = {
      'isActive': isActive,
    };
    print('(FF900)${this.isActive}////${m}');
    return m;
  }

  EdgeExtra.fromJson(Map<String, dynamic> json)
      : isActive = (json['index'] as bool);
}

class Edge {
  final Node a;
  final Node b;
  final EdgeExtra edgeExtra;

  Edge(this.a, this.b, this.edgeExtra) {
    if (a == b) {
      throw Exception("Cannot create edge between the same node");
    }
  }

  double get distance => a.position.distanceTo(b.position);

  double get angle {
    final actualAngle = (a.position - b.position).angleToSigned(Vector2(0, -1));
    if (actualAngle >= 0 && actualAngle <= pi) {
      return actualAngle - pi / 2;
    } else {
      return actualAngle + pi / 2;
    }
  }

  double get rawAngle {
    return (a.position - b.position).angleToSigned(Vector2(1, 0));
  }

  /// Hooke's law calculates the elastic force
  double calculateAttractionForce({required double k, required double length}) {
    final distance = this.distance;
    final deformation = distance - length;
    return k * deformation;
  }

  /// Calculate the elastic force direction of node A
  Vector2 calculateAttractionForceDirectionA() {
    return (b.position - a.position).normalized();
  }

  /// Calculate the elastic force direction of node B
  Vector2 calculateAttractionForceDirectionB() {
    return (a.position - b.position).normalized();
  }

  @override
  String toString() {
    return "Edge{a: ${a.data}, b: ${b.data}, distance: $distance, angle: $angle}";
  }

  @override
  bool operator ==(Object other) {
    if (other is Edge) {
      return (a == other.a && b == other.b) || (a == other.b && b == other.a);
    }
    return false;
  }

  @override
  int get hashCode => a.hashCode ^ b.hashCode;
}
