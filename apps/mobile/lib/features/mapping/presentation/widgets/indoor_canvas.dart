import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/edge_model.dart';
import '../../../../core/models/node_model.dart';

/// Interactive 2D Indoor Graph Canvas
/// Owner: Nishant (Indoor Map Visualization UI)
class IndoorCanvas extends StatelessWidget {
  final List<NodeModel> nodes;
  final List<EdgeModel> edges;
  final String? selectedNodeId;
  final String? visitorNodeId;
  final List<String> highlightedPathNodeIds;
  final ValueChanged<NodeModel>? onNodeTapped;

  const IndoorCanvas({
    super.key,
    required this.nodes,
    required this.edges,
    this.selectedNodeId,
    this.visitorNodeId,
    this.highlightedPathNodeIds = const [],
    this.onNodeTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const Center(child: Text('No spatial nodes to render'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _IndoorMapPainter(
            nodes: nodes,
            edges: edges,
            selectedNodeId: selectedNodeId,
            visitorNodeId: visitorNodeId,
            highlightedPathNodeIds: highlightedPathNodeIds,
          ),
        );
      },
    );
  }
}

class _IndoorMapPainter extends CustomPainter {
  final List<NodeModel> nodes;
  final List<EdgeModel> edges;
  final String? selectedNodeId;
  final String? visitorNodeId;
  final List<String> highlightedPathNodeIds;

  _IndoorMapPainter({
    required this.nodes,
    required this.edges,
    this.selectedNodeId,
    this.visitorNodeId,
    required this.highlightedPathNodeIds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;

    // Determine bounding box for normalization
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;

    for (final node in nodes) {
      if (node.x < minX) minX = node.x;
      if (node.x > maxX) maxX = node.x;
      if (node.y < minY) minY = node.y;
      if (node.y > maxY) maxY = node.y;
    }

    final spanX = (maxX - minX).abs() < 0.1 ? 1.0 : (maxX - minX);
    final spanY = (maxY - minY).abs() < 0.1 ? 1.0 : (maxY - minY);

    final padding = 40.0;
    final drawW = size.width - 2 * padding;
    final drawH = size.height - 2 * padding;

    Offset toCanvas(double x, double y) {
      final normX = (x - minX) / spanX;
      // Invert Y so North is Up
      final normY = 1.0 - ((y - minY) / spanY);
      return Offset(padding + normX * drawW, padding + normY * drawH);
    }

    final nodeMap = {for (final n in nodes) n.id: n};

    // 1. Draw Edges
    final edgePaint = Paint()
      ..color = AppColors.edgeDefault
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final routePaint = Paint()
      ..color = AppColors.edgeActiveRoute
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final start = nodeMap[edge.startNodeId];
      final end = nodeMap[edge.endNodeId];
      if (start == null || end == null) continue;

      final p1 = toCanvas(start.x, start.y);
      final p2 = toCanvas(end.x, end.y);

      final isRoute = highlightedPathNodeIds.contains(edge.startNodeId) &&
          highlightedPathNodeIds.contains(edge.endNodeId);

      canvas.drawLine(p1, p2, isRoute ? routePaint : edgePaint);
    }

    // 2. Draw Nodes
    final nodePaint = Paint()..style = PaintingStyle.fill;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final node in nodes) {
      final pos = toCanvas(node.x, node.y);

      // Color coding based on category
      Color color = AppColors.nodeDefault;
      if (!node.accessible) {
        color = AppColors.nodeStairs;
      } else if (node.category == 'emergency_exit') {
        color = AppColors.nodeExit;
      } else if (node.category == 'elevator') {
        color = AppColors.nodeElevator;
      }

      if (node.id == selectedNodeId) {
        color = AppColors.nodeSelected;
      }

      nodePaint.color = color;
      canvas.drawCircle(pos, 10.0, nodePaint);

      // Visitor indicator (Manual position V1)
      if (node.id == visitorNodeId) {
        final visitorRing = Paint()
          ..color = Colors.greenAccent
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(pos, 16.0, visitorRing);
      }

      // Node label
      textPainter.text = TextSpan(
        text: node.name,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(pos.dx - textPainter.width / 2, pos.dy + 12));
    }
  }

  @override
  bool shouldRepaint(covariant _IndoorMapPainter oldDelegate) => true;
}
