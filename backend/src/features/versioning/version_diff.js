/**
 * Version Diff Utility for MapLess AI (Owner: Piyush)
 * Computes deterministic structural diffs between two immutable map snapshots.
 *
 * Excludes ephemeral fields (created_at, updated_at, internal DB IDs) to prevent false positives.
 */

function areObjectsEqual(a, b, ignoredKeys = new Set(['created_at', 'updated_at', 'createdAt', 'updatedAt'])) {
  if (a === b) return true;
  if (!a || !b || typeof a !== 'object' || typeof b !== 'object') return false;

  const keysA = Object.keys(a).filter(k => !ignoredKeys.has(k));
  const keysB = Object.keys(b).filter(k => !ignoredKeys.has(k));

  if (keysA.length !== keysB.length) return false;

  for (const key of keysA) {
    if (!Object.prototype.hasOwnProperty.call(b, key)) return false;
    const valA = a[key];
    const valB = b[key];

    if (Array.isArray(valA) && Array.isArray(valB)) {
      if (valA.length !== valB.length) return false;
      const sortedA = [...valA].sort();
      const sortedB = [...valB].sort();
      for (let i = 0; i < sortedA.length; i++) {
        if (typeof sortedA[i] === 'object') {
          if (!areObjectsEqual(sortedA[i], sortedB[i], ignoredKeys)) return false;
        } else if (sortedA[i] !== sortedB[i]) {
          return false;
        }
      }
    } else if (typeof valA === 'object' && typeof valB === 'object') {
      if (!areObjectsEqual(valA, valB, ignoredKeys)) return false;
    } else if (valA !== valB) {
      return false;
    }
  }

  return true;
}

/**
 * Computes deep differences between two snapshots.
 * @param {object} baseSnapshot - Starting snapshot data
 * @param {object} targetSnapshot - Target snapshot data to compare against
 * @returns {object} Categorized diff
 */
function computeSnapshotDiff(baseSnapshot = {}, targetSnapshot = {}) {
  const baseNodes = Array.isArray(baseSnapshot.nodes) ? baseSnapshot.nodes : [];
  const targetNodes = Array.isArray(targetSnapshot.nodes) ? targetSnapshot.nodes : [];

  const baseEdges = Array.isArray(baseSnapshot.edges) ? baseSnapshot.edges : [];
  const targetEdges = Array.isArray(targetSnapshot.edges) ? targetSnapshot.edges : [];

  const baseFloors = Array.isArray(baseSnapshot.floors) 
    ? baseSnapshot.floors 
    : (baseSnapshot.floor ? [baseSnapshot.floor] : []);
  const targetFloors = Array.isArray(targetSnapshot.floors) 
    ? targetSnapshot.floors 
    : (targetSnapshot.floor ? [targetSnapshot.floor] : []);

  const baseMeta = Array.isArray(baseSnapshot.semanticMetadata) ? baseSnapshot.semanticMetadata : [];
  const targetMeta = Array.isArray(targetSnapshot.semanticMetadata) ? targetSnapshot.semanticMetadata : [];

  // 1. Node Diff
  const baseNodeMap = new Map(baseNodes.map(n => [n.id, n]));
  const targetNodeMap = new Map(targetNodes.map(n => [n.id, n]));

  const nodesAdded = [];
  const nodesRemoved = [];
  const nodesModified = [];

  for (const [id, targetNode] of targetNodeMap.entries()) {
    if (!baseNodeMap.has(id)) {
      nodesAdded.push(targetNode);
    } else {
      const baseNode = baseNodeMap.get(id);
      if (!areObjectsEqual(baseNode, targetNode)) {
        nodesModified.push({
          id,
          before: baseNode,
          after: targetNode
        });
      }
    }
  }

  for (const [id, baseNode] of baseNodeMap.entries()) {
    if (!targetNodeMap.has(id)) {
      nodesRemoved.push(baseNode);
    }
  }

  // 2. Edge Diff
  const edgeKey = (e) => e.id || `${e.startNodeId}->${e.endNodeId}`;
  const baseEdgeMap = new Map(baseEdges.map(e => [edgeKey(e), e]));
  const targetEdgeMap = new Map(targetEdges.map(e => [edgeKey(e), e]));

  const edgesAdded = [];
  const edgesRemoved = [];
  const edgesModified = [];

  for (const [key, targetEdge] of targetEdgeMap.entries()) {
    if (!baseEdgeMap.has(key)) {
      edgesAdded.push(targetEdge);
    } else {
      const baseEdge = baseEdgeMap.get(key);
      if (!areObjectsEqual(baseEdge, targetEdge)) {
        edgesModified.push({
          id: targetEdge.id || key,
          before: baseEdge,
          after: targetEdge
        });
      }
    }
  }

  for (const [key, baseEdge] of baseEdgeMap.entries()) {
    if (!targetEdgeMap.has(key)) {
      edgesRemoved.push(baseEdge);
    }
  }

  // 3. Floor Diff
  const baseFloorMap = new Map(baseFloors.map(f => [f.id, f]));
  const targetFloorMap = new Map(targetFloors.map(f => [f.id, f]));

  const floorsAdded = [];
  const floorsRemoved = [];
  const floorsModified = [];

  for (const [id, targetFloor] of targetFloorMap.entries()) {
    if (!baseFloorMap.has(id)) {
      floorsAdded.push(targetFloor);
    } else {
      const baseFloor = baseFloorMap.get(id);
      if (!areObjectsEqual(baseFloor, targetFloor)) {
        floorsModified.push({
          id,
          before: baseFloor,
          after: targetFloor
        });
      }
    }
  }

  for (const [id, baseFloor] of baseFloorMap.entries()) {
    if (!targetFloorMap.has(id)) {
      floorsRemoved.push(baseFloor);
    }
  }

  // 4. Semantic Metadata Diff (Identity: entityId + entityType)
  const metaKey = (m) => `${m.entityId || m.entity_id}:${m.entityType || m.entity_type}`;
  const baseMetaMap = new Map(baseMeta.map(m => [metaKey(m), m]));
  const targetMetaMap = new Map(targetMeta.map(m => [metaKey(m), m]));

  const semanticMetadataAdded = [];
  const semanticMetadataRemoved = [];
  const semanticMetadataModified = [];

  for (const [key, targetM] of targetMetaMap.entries()) {
    if (!baseMetaMap.has(key)) {
      semanticMetadataAdded.push(targetM);
    } else {
      const baseM = baseMetaMap.get(key);
      if (!areObjectsEqual(baseM, targetM)) {
        semanticMetadataModified.push({
          key,
          before: baseM,
          after: targetM
        });
      }
    }
  }

  for (const [key, baseM] of baseMetaMap.entries()) {
    if (!targetMetaMap.has(key)) {
      semanticMetadataRemoved.push(baseM);
    }
  }

  return {
    nodesAdded,
    nodesRemoved,
    nodesModified,
    edgesAdded,
    edgesRemoved,
    edgesModified,
    floorsAdded,
    floorsRemoved,
    floorsModified,
    semanticMetadataAdded,
    semanticMetadataRemoved,
    semanticMetadataModified,
    summary: {
      nodesChanged: nodesAdded.length + nodesRemoved.length + nodesModified.length,
      edgesChanged: edgesAdded.length + edgesRemoved.length + edgesModified.length,
      floorsChanged: floorsAdded.length + floorsRemoved.length + floorsModified.length,
      semanticMetadataChanged: semanticMetadataAdded.length + semanticMetadataRemoved.length + semanticMetadataModified.length
    }
  };
}

module.exports = {
  computeSnapshotDiff,
  areObjectsEqual
};
