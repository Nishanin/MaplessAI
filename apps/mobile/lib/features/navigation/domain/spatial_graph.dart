import '../../../core/models/edge_model.dart';
import '../../../core/models/node_model.dart';

/// Spatial Graph data structure for A* and Dijkstra pathfinding
/// Owner: Pratik (Spatial Intelligence Domain)
class SpatialGraph {
  final Map<String, NodeModel> _nodes = {};
  final Map<String, List<EdgeModel>> _adjacencyList = {};

  SpatialGraph();

  void addNode(NodeModel node) {
    _nodes[node.id] = node;
    _adjacencyList.putIfAbsent(node.id, () => []);
  }

  void addEdge(EdgeModel edge) {
    if (_nodes.containsKey(edge.startNodeId) && _nodes.containsKey(edge.endNodeId)) {
      _adjacencyList.putIfAbsent(edge.startNodeId, () => []).add(edge);
    }
  }

  NodeModel? getNode(String id) => _nodes[id];
  List<EdgeModel> getNeighbors(String nodeId) => _adjacencyList[nodeId] ?? const [];
  List<NodeModel> get allNodes => _nodes.values.toList();
  int get nodeCount => _nodes.length;
  int get edgeCount => _adjacencyList.values.fold(0, (sum, list) => sum + list.length);

  void clear() {
    _nodes.clear;
    _adjacencyList.clear();
  }
}
