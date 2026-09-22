import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/edge_model.dart';
import '../../../../core/models/node_model.dart';

/// Interactive 2D Indoor Graph Canvas with Pan, Pinch-to-Zoom & Hit-Testing
/// Owner: Nishant (Phase 5 — Interactive 2D Indoor Map)
class IndoorCanvas extends StatefulWidget {
  final List<NodeModel> nodes;
  final List<EdgeModel> edges;
  final String? selectedNodeId;
  final String? visitorNodeId;
  final double? visitorHeading;
  final List<String> highlightedPathNodeIds;
  final ValueChanged<NodeModel>? onNodeTapped;
  final TransformationController? transformationController;
  final bool showLabels;
  final bool showAccessibilityBadges;

  // Phase 6 — Creator-side sensor-assisted walkthrough tracking
  final Offset? creatorMappingPosition;
  final double? creatorHeading;
  final List<Offset> creatorWalkedPath;
  final bool isRecordingWalkthrough;

  const IndoorCanvas({
    super.key,
    required this.nodes,
    required this.edges,
    this.selectedNodeId,
    this.visitorNodeId,
    this.visitorHeading,
    this.highlightedPathNodeIds = const [],
    this.onNodeTapped,
    this.transformationController,
    this.showLabels = true,
    this.showAccessibilityBadges = true,
    this.creatorMappingPosition,
    this.creatorHeading,
    this.creatorWalkedPath = const [],
    this.isRecordingWalkthrough = false,
  });

  @override
  State<IndoorCanvas> createState() => _IndoorCanvasState();
}

class _IndoorCanvasState extends State<IndoorCanvas> {
  late TransformationController _transformController;
  bool _isLocalController = false;

  @override
  void initState() {
    super.initState();
    if (widget.transformationController != null) {
      _transformController = widget.transformationController!;
    } else {
      _transformController = TransformationController();
      _isLocalController = true;
    }
  }

  @override
  void didUpdateWidget(covariant IndoorCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.transformationController != oldWidget.transformationController) {
      if (_isLocalController) {
        _transformController.dispose();
        _isLocalController = false;
      }
      if (widget.transformationController != null) {
        _transformController = widget.transformationController!;
      } else {
        _transformController = TransformationController();
        _isLocalController = true;
      }
    }
  }

  @override
  void dispose() {
    if (_isLocalController) {
      _transformController.dispose();
    }
    super.dispose();
  }

  void _handleTap(Offset scenePoint, Size canvasSize) {
    if (widget.nodes.isEmpty || widget.onNodeTapped == null) return;

    // Coordinate mapping bounds
    final bounds = _computeBounds(
      widget.nodes,
      widget.creatorMappingPosition,
      widget.creatorWalkedPath,
    );
    final toCanvas = _computeCanvasTransform(bounds, canvasSize);

    // Hit-test radius in scene pixels (~26 logical pixels)
    const hitRadius = 26.0;
    NodeModel? closestNode;
    double minDistance = double.infinity;

    for (final node in widget.nodes) {
      final nodePos = toCanvas(node.x, node.y);
      final dist = (nodePos - scenePoint).distance;
      if (dist < hitRadius && dist < minDistance) {
        minDistance = dist;
        closestNode = node;
      }
    }

    if (closestNode != null) {
      widget.onNodeTapped!(closestNode);
    }
  }

  static _BoundingBox _computeBounds(
    List<NodeModel> nodes, [
    Offset? creatorPos,
    List<Offset>? walkedPath,
  ]) {
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;

    for (final node in nodes) {
      if (node.x < minX) minX = node.x;
      if (node.x > maxX) maxX = node.x;
      if (node.y < minY) minY = node.y;
      if (node.y > maxY) maxY = node.y;
    }

    if (creatorPos != null) {
      if (creatorPos.dx < minX) minX = creatorPos.dx;
      if (creatorPos.dx > maxX) maxX = creatorPos.dx;
      if (creatorPos.dy < minY) minY = creatorPos.dy;
      if (creatorPos.dy > maxY) maxY = creatorPos.dy;
    }

    if (walkedPath != null && walkedPath.isNotEmpty) {
      for (final p in walkedPath) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
    }

    if (minX == double.infinity) {
      minX = -5.0;
      maxX = 5.0;
      minY = -5.0;
      maxY = 5.0;
    }

    final rawSpanX = (maxX - minX).abs();
    final rawSpanY = (maxY - minY).abs();
    final spanX = rawSpanX < 5.0 ? 5.0 : rawSpanX;
    final spanY = rawSpanY < 5.0 ? 5.0 : rawSpanY;

    return _BoundingBox(minX: minX, maxX: maxX, minY: minY, maxY: maxY, spanX: spanX, spanY: spanY);
  }

  static Offset Function(double x, double y) _computeCanvasTransform(
    _BoundingBox bounds,
    Size size,
  ) {
    const padding = 50.0;
    final drawW = (size.width - 2 * padding).clamp(20.0, double.infinity);
    final drawH = (size.height - 2 * padding).clamp(20.0, double.infinity);

    return (double x, double y) {
      final normX = (x - bounds.minX) / bounds.spanX;
      // Invert Y so positive Y is North / Up
      final normY = 1.0 - ((y - bounds.minY) / bounds.spanY);
      return Offset(padding + normX * drawW, padding + normY * drawH);
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = widget.nodes.isNotEmpty ||
        widget.creatorMappingPosition != null ||
        widget.creatorWalkedPath.isNotEmpty;

    if (!hasContent) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 48, color: AppColors.textMuted),
            SizedBox(height: 8),
            Text(
              'No spatial nodes to render on this floor',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

        return InteractiveViewer(
          transformationController: _transformController,
          minScale: 0.5,
          maxScale: 4.0,
          boundaryMargin: const EdgeInsets.all(120),
          clipBehavior: Clip.hardEdge,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _handleTap(details.localPosition, canvasSize),
            child: SizedBox(
              width: canvasSize.width,
              height: canvasSize.height,
              child: CustomPaint(
                size: canvasSize,
                painter: _IndoorMapPainter(
                  nodes: widget.nodes,
                  edges: widget.edges,
                  selectedNodeId: widget.selectedNodeId,
                  visitorNodeId: widget.visitorNodeId,
                  visitorHeading: widget.visitorHeading,
                  highlightedPathNodeIds: widget.highlightedPathNodeIds,
                  showLabels: widget.showLabels,
                  showAccessibilityBadges: widget.showAccessibilityBadges,
                  creatorMappingPosition: widget.creatorMappingPosition,
                  creatorHeading: widget.creatorHeading,
                  creatorWalkedPath: widget.creatorWalkedPath,
                  isRecordingWalkthrough: widget.isRecordingWalkthrough,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BoundingBox {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final double spanX;
  final double spanY;

  const _BoundingBox({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.spanX,
    required this.spanY,
  });
}

/// Custom Canvas Painter rendering nodes, edges, routes, and facility icons
class _IndoorMapPainter extends CustomPainter {
  final List<NodeModel> nodes;
  final List<EdgeModel> edges;
  final String? selectedNodeId;
  final String? visitorNodeId;
  final double? visitorHeading;
  final List<String> highlightedPathNodeIds;
  final bool showLabels;
  final bool showAccessibilityBadges;

  // Phase 6 — Creator mapping position & walked path
  final Offset? creatorMappingPosition;
  final double? creatorHeading;
  final List<Offset> creatorWalkedPath;
  final bool isRecordingWalkthrough;

  _IndoorMapPainter({
    required this.nodes,
    required this.edges,
    this.selectedNodeId,
    this.visitorNodeId,
    this.visitorHeading,
    required this.highlightedPathNodeIds,
    required this.showLabels,
    required this.showAccessibilityBadges,
    this.creatorMappingPosition,
    this.creatorHeading,
    this.creatorWalkedPath = const [],
    this.isRecordingWalkthrough = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = _IndoorCanvasState._computeBounds(
      nodes,
      creatorMappingPosition,
      creatorWalkedPath,
    );
    final toCanvas = _IndoorCanvasState._computeCanvasTransform(bounds, size);
    final nodeMap = {for (final n in nodes) n.id: n};

    // 0. Draw subtle ambient floor background grid
    _drawGridBackground(canvas, size);

    // 0.5. Draw Creator Walked Path (Phase 6)
    if (creatorWalkedPath.isNotEmpty) {
      _drawCreatorWalkedPath(canvas, toCanvas);
    }

    // 1. Draw Edges
    final edgePaint = Paint()
      ..color = AppColors.edgeDefault
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final nonAccessibleEdgePaint = Paint()
      ..color = Colors.amber.shade300
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Glowing active route path paint (ONLY when route data exists)
    final routeGlowPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.3)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final routePaint = Paint()
      ..color = AppColors.edgeActiveRoute
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final start = nodeMap[edge.startNodeId];
      final end = nodeMap[edge.endNodeId];
      if (start == null || end == null) continue;

      final p1 = toCanvas(start.x, start.y);
      final p2 = toCanvas(end.x, end.y);

      final isRouteEdge = highlightedPathNodeIds.isNotEmpty &&
          _isSequentialRouteEdge(edge.startNodeId, edge.endNodeId);

      if (isRouteEdge) {
        // Render route line with glowing effect
        canvas.drawLine(p1, p2, routeGlowPaint);
        canvas.drawLine(p1, p2, routePaint);
      } else {
        // Standard edge
        canvas.drawLine(
          p1,
          p2,
          edge.accessible ? edgePaint : nonAccessibleEdgePaint,
        );
      }
    }

    // 2. Draw Nodes
    final nodePaint = Paint()..style = PaintingStyle.fill;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final node in nodes) {
      final pos = toCanvas(node.x, node.y);
      final isSelected = node.id == selectedNodeId;
      final isVisitor = node.id == visitorNodeId;
      final isRouteNode = highlightedPathNodeIds.contains(node.id);

      // Node Color Scheme based on spatial category
      final (Color baseColor, IconData? iconGlyph) = _getNodeStyle(node);

      // Selection Halo Ring (Active Selection)
      if (isSelected) {
        final haloPaint = Paint()
          ..color = AppColors.primary.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 22.0, haloPaint);

        final selectedRing = Paint()
          ..color = AppColors.primary
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(pos, 16.0, selectedRing);
      }

      // Base Node Outer Ring
      final outerRingPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 12.0, outerRingPaint);

      // Base Node Fill
      nodePaint.color = isSelected ? AppColors.primary : baseColor;
      canvas.drawCircle(pos, 10.0, nodePaint);

      // Draw facility icon inside node if applicable
      if (iconGlyph != null) {
        _drawIconOnCanvas(canvas, pos, iconGlyph, Colors.white, 12.0);
      }

      // Visitor indicator (Current position marker)
      if (isVisitor) {
        final visitorRing = Paint()
          ..color = Colors.greenAccent.shade700
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(pos, 15.0, visitorRing);

        // Visitor Heading Cone / Orientation Indicator
        if (visitorHeading != null) {
          _drawHeadingArrow(canvas, pos, visitorHeading!);
        }
      }

      // Route Start / Destination Markers
      if (isRouteNode && highlightedPathNodeIds.isNotEmpty) {
        if (node.id == highlightedPathNodeIds.first) {
          // Route Start (Green dot)
          final startMarker = Paint()
            ..color = Colors.green.shade600
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke;
          canvas.drawCircle(pos, 18.0, startMarker);
        } else if (node.id == highlightedPathNodeIds.last) {
          // Route Destination (Red dot)
          final endMarker = Paint()
            ..color = Colors.red.shade600
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke;
          canvas.drawCircle(pos, 18.0, endMarker);
        }
      }

      // Node Labels
      if (showLabels) {
        _drawNodeLabel(canvas, pos, node, textPainter, isSelected);
      }
    }

    // 3. Draw Creator Mapping Position (Phase 6)
    if (creatorMappingPosition != null) {
      final pos = toCanvas(creatorMappingPosition!.dx, creatorMappingPosition!.dy);
      _drawCreatorMappingMarker(canvas, pos);
    }
  }

  void _drawCreatorWalkedPath(Canvas canvas, Offset Function(double x, double y) toCanvas) {
    if (creatorWalkedPath.length < 2) {
      if (creatorWalkedPath.isNotEmpty) {
        final pt = toCanvas(creatorWalkedPath.first.dx, creatorWalkedPath.first.dy);
        canvas.drawCircle(pt, 3.0, Paint()..color = Colors.cyan.shade700);
      }
      return;
    }

    // Glowing trail underlay
    final glowPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.3)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final pathPaint = Paint()
      ..color = Colors.cyan.shade700
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final first = toCanvas(creatorWalkedPath.first.dx, creatorWalkedPath.first.dy);
    path.moveTo(first.dx, first.dy);

    for (int i = 1; i < creatorWalkedPath.length; i++) {
      final pt = toCanvas(creatorWalkedPath[i].dx, creatorWalkedPath[i].dy);
      path.lineTo(pt.dx, pt.dy);
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, pathPaint);

    // Draw small dots at sampled vertices along the path
    final dotPaint = Paint()..color = Colors.cyan.shade800;
    for (final pt in creatorWalkedPath) {
      final canvasPt = toCanvas(pt.dx, pt.dy);
      canvas.drawCircle(canvasPt, 2.5, dotPaint);
    }
  }

  void _drawCreatorMappingMarker(Canvas canvas, Offset pos) {
    // Creator Avatar Pulsing Outer Halo
    final haloPaint = Paint()
      ..color = Colors.cyanAccent.shade700.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, 22.0, haloPaint);

    // Creator Outer Ring
    final outerRing = Paint()
      ..color = Colors.cyan.shade700
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(pos, 14.0, outerRing);

    // Inner White Ring
    final whiteRing = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, 11.0, whiteRing);

    // Core Solid Dot
    final corePaint = Paint()
      ..color = Colors.cyan.shade800
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, 7.0, corePaint);

    // Directional Heading Indicator (Cone/Arrow)
    if (creatorHeading != null) {
      _drawCreatorHeadingIndicator(canvas, pos, creatorHeading!);
    }
  }

  void _drawCreatorHeadingIndicator(Canvas canvas, Offset center, double headingDegrees) {
    final headingRad = (headingDegrees - 90) * (math.pi / 180.0);
    final tip = Offset(
      center.dx + 24.0 * math.cos(headingRad),
      center.dy + 24.0 * math.sin(headingRad),
    );

    final arrowPaint = Paint()
      ..color = Colors.cyan.shade900
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(center, tip, arrowPaint);
    canvas.drawCircle(tip, 3.5, Paint()..color = Colors.cyan.shade900);
  }

  bool _isSequentialRouteEdge(String startId, String endId) {
    final idxA = highlightedPathNodeIds.indexOf(startId);
    final idxB = highlightedPathNodeIds.indexOf(endId);
    if (idxA == -1 || idxB == -1) return false;
    return (idxA - idxB).abs() == 1;
  }

  (Color, IconData?) _getNodeStyle(NodeModel node) {
    if (node.category == 'elevator') {
      return (AppColors.nodeElevator, Icons.elevator);
    }
    if (node.category == 'stairs' || !node.accessible) {
      return (AppColors.nodeStairs, Icons.stairs);
    }
    if (node.category == 'emergency_exit') {
      return (AppColors.nodeExit, Icons.exit_to_app);
    }
    if (node.category == 'entrance') {
      return (Colors.teal.shade600, Icons.door_front_door);
    }
    if (node.category == 'room' || node.category == 'laboratory') {
      return (AppColors.primary, Icons.meeting_room);
    }
    // Corridor or regular topological junction
    return (AppColors.nodeDefault, null);
  }

  void _drawIconOnCanvas(
    Canvas canvas,
    Offset center,
    IconData icon,
    Color color,
    double size,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  void _drawHeadingArrow(Canvas canvas, Offset center, double headingDegrees) {
    final headingRad = (headingDegrees - 90) * (math.pi / 180.0);
    final tip = Offset(
      center.dx + 22.0 * math.cos(headingRad),
      center.dy + 22.0 * math.sin(headingRad),
    );

    final arrowPaint = Paint()
      ..color = Colors.greenAccent.shade700
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(center, tip, arrowPaint);
    canvas.drawCircle(tip, 3.0, Paint()..color = Colors.greenAccent.shade700);
  }

  void _drawNodeLabel(
    Canvas canvas,
    Offset pos,
    NodeModel node,
    TextPainter textPainter,
    bool isSelected,
  ) {
    textPainter.text = TextSpan(
      text: node.name,
      style: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textPrimary,
        fontSize: 10,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
      ),
    );
    textPainter.layout();

    final labelOffset = Offset(
      pos.dx - textPainter.width / 2,
      pos.dy + 14,
    );

    // Label background pill for readability
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        labelOffset.dx - 4,
        labelOffset.dy - 1,
        textPainter.width + 8,
        textPainter.height + 2,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(
      bgRect,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
    canvas.drawRRect(
      bgRect,
      Paint()
        ..color = isSelected
            ? AppColors.primary.withValues(alpha: 0.3)
            : AppColors.border.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    textPainter.paint(canvas, labelOffset);
  }

  void _drawGridBackground(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _IndoorMapPainter oldDelegate) => true;
}
