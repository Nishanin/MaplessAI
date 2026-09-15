const fs = require('fs');
const path = require('path');

/**
 * Semantic Knowledge Graph Backend Service (Owner: Surabhi)
 *
 * Provides deterministic, read-only, in-memory resolution of natural-language-derived
 * semantic constraints against building datasets.
 *
 * CRITICAL SECURITY INVARIANTS:
 * 1. This service NEVER constructs or executes SQL, shell commands, or dynamic code.
 * 2. It performs strictly deterministic, in-memory lookups on normalized data.
 * 3. Unknown constraint fields are ignored and never interpreted as instructions.
 * 4. Internal graph state is deeply immutable; all returned data are safe clones.
 * 5. Candidate node IDs are never invented or arbitrarily chosen during ambiguity.
 */

const DEFAULT_DATASET_PATH = path.resolve(
  __dirname,
  '../../../../test_data/vit_floor_1.json'
);

const ALLOWED_CONSTRAINTS = Object.freeze([
  'nodeId',
  'name',
  'alias',
  'category',
  'tag',
  'department',
  'accessible',
  'facility',
  'floor',
  'capacityMin'
]);

/**
 * Safely clones a normalized node object to prevent external mutations.
 * @param {object} node
 * @returns {object}
 */
function cloneNode(node) {
  return {
    id: node.id,
    name: node.name,
    category: node.category,
    accessible: node.accessible,
    floorId: node.floorId,
    floorNumber: node.floorNumber,
    floorName: node.floorName,
    buildingId: node.buildingId,
    buildingName: node.buildingName,
    aliases: [...node.aliases],
    tags: [...node.tags],
    department: node.department,
    capacity: node.capacity,
    operationalHours: node.operationalHours,
    description: node.description,
    customAttributes: { ...node.customAttributes },
    semanticMetadata: node.semanticMetadata ? JSON.parse(JSON.stringify(node.semanticMetadata)) : null
  };
}

class SemanticGraphService {
  /**
   * @param {string|object} [source] Filepath string or pre-loaded JSON object.
   */
  constructor(source = DEFAULT_DATASET_PATH) {
    this._nodes = new Map();
    this._nodeList = [];
    this._building = null;
    this._floor = null;

    this.loadDataset(source);
  }

  /**
   * Loads and normalizes a dataset into the in-memory lookup graph.
   * @param {string|object} source
   */
  loadDataset(source) {
    let rawData;
    if (typeof source === 'string') {
      if (!fs.existsSync(source)) {
        throw new Error(`Dataset file not found at path: ${source}`);
      }
      const rawContent = fs.readFileSync(source, 'utf8');
      rawData = JSON.parse(rawContent);
    } else if (typeof source === 'object' && source !== null) {
      rawData = JSON.parse(JSON.stringify(source));
    } else {
      throw new TypeError('Invalid dataset source: must be a file path string or object.');
    }

    this._normalize(rawData);
  }

  /**
   * Normalizes raw building JSON into structured, immutable node records.
   * @private
   */
  _normalize(rawData) {
    this._nodes.clear();
    this._nodeList = [];

    const building = rawData.building || {};
    const floor = rawData.floor || {};
    const rawNodes = Array.isArray(rawData.nodes) ? rawData.nodes : [];
    const semanticMetadataList = Array.isArray(rawData.semanticMetadata)
      ? rawData.semanticMetadata
      : [];

    // Map semantic metadata by entityId for fast, normalized merge
    const semanticMap = new Map();
    for (const sm of semanticMetadataList) {
      if (sm && sm.entityId && sm.entityType === 'node') {
        semanticMap.set(sm.entityId, sm);
      }
    }

    this._building = Object.freeze({
      id: building.id || '',
      name: building.name || '',
      category: building.category || '',
      address: building.address || '',
      departments: building.metadata && Array.isArray(building.metadata.departments)
        ? Object.freeze([...building.metadata.departments])
        : Object.freeze([])
    });

    this._floor = Object.freeze({
      id: floor.id || '',
      buildingId: floor.buildingId || building.id || '',
      floorNumber: typeof floor.floorNumber === 'number' ? floor.floorNumber : null,
      name: floor.name || '',
      elevation: typeof floor.elevation === 'number' ? floor.elevation : null
    });

    for (const node of rawNodes) {
      const sm = semanticMap.get(node.id);

      const mergedCustomAttributes = {
        ...(node.metadata || {}),
        ...(sm && sm.customAttributes ? sm.customAttributes : {})
      };

      const normalizedNode = Object.freeze({
        id: node.id,
        name: node.name || '',
        category: node.category || '',
        accessible: typeof node.accessible === 'boolean' ? node.accessible : false,
        floorId: node.floorId || floor.id || '',
        floorNumber: typeof floor.floorNumber === 'number' ? floor.floorNumber : null,
        floorName: floor.name || '',
        buildingId: floor.buildingId || building.id || '',
        buildingName: building.name || '',
        aliases: Object.freeze(sm && Array.isArray(sm.aliases) ? [...sm.aliases] : []),
        tags: Object.freeze(sm && Array.isArray(sm.tags) ? [...sm.tags] : []),
        department: (sm && sm.department) || (node.metadata && node.metadata.department) || null,
        capacity: (sm && typeof sm.capacity === 'number')
          ? sm.capacity
          : (node.metadata && typeof node.metadata.capacity === 'number')
            ? node.metadata.capacity
            : null,
        operationalHours: (sm && sm.operationalHours) || null,
        description: (sm && sm.description) || null,
        customAttributes: Object.freeze(mergedCustomAttributes),
        semanticMetadata: sm ? Object.freeze(JSON.parse(JSON.stringify(sm))) : null
      });

      this._nodes.set(normalizedNode.id, normalizedNode);
      this._nodeList.push(normalizedNode);
    }
  }

  /**
   * Returns building metadata clone.
   */
  getBuildingInfo() {
    return { ...this._building };
  }

  /**
   * Returns floor metadata clone.
   */
  getFloorInfo() {
    return { ...this._floor };
  }

  /**
   * Returns a clone of a node by exact ID, or null if absent.
   * @param {string} nodeId
   * @returns {object|null}
   */
  getNodeById(nodeId) {
    if (typeof nodeId !== 'string') return null;
    const node = this._nodes.get(nodeId.trim());
    return node ? cloneNode(node) : null;
  }

  /**
   * Returns all nodes in the graph as cloned objects.
   * @returns {Array<object>}
   */
  getAllNodes() {
    return this._nodeList.map(cloneNode);
  }

  /**
   * Resolves candidate nodes against a set of controlled semantic constraints.
   *
   * @param {object} constraints
   * @returns {{
   *   status: 'resolved'|'ambiguous'|'not_found',
   *   matchCount: number,
   *   candidateIds: Array<string>,
   *   candidates: Array<object>
   * }}
   */
  resolveCandidates(constraints = {}) {
    if (!constraints || typeof constraints !== 'object') {
      constraints = {};
    }

    // Whitelist check: only accept known constraint keys
    const sanitized = {};
    for (const key of ALLOWED_CONSTRAINTS) {
      if (
        Object.prototype.hasOwnProperty.call(constraints, key) &&
        constraints[key] !== undefined &&
        constraints[key] !== null
      ) {
        sanitized[key] = constraints[key];
      }
    }

    const matchingNodes = [];
    for (const node of this._nodeList) {
      if (this._matchesConstraints(node, sanitized)) {
        matchingNodes.push(cloneNode(node));
      }
    }

    const matchCount = matchingNodes.length;
    let status = 'not_found';
    if (matchCount === 1) {
      status = 'resolved';
    } else if (matchCount > 1) {
      status = 'ambiguous';
    }

    return {
      status,
      matchCount,
      candidateIds: matchingNodes.map(n => n.id),
      candidates: matchingNodes
    };
  }

  /**
   * Evaluates if a node satisfies ALL active constraints simultaneously (AND logic).
   * @private
   */
  _matchesConstraints(node, constraints) {
    // 1. exact nodeId
    if (constraints.nodeId !== undefined) {
      const targetId = String(constraints.nodeId).trim();
      if (node.id !== targetId) return false;
    }

    // 2. case-insensitive name match (exact or substring)
    if (constraints.name !== undefined) {
      const targetName = String(constraints.name).trim().toLowerCase();
      const nodeNameLower = node.name.toLowerCase();
      if (nodeNameLower !== targetName && !nodeNameLower.includes(targetName)) {
        return false;
      }
    }

    // 3. case-insensitive alias match
    if (constraints.alias !== undefined) {
      const targetAlias = String(constraints.alias).trim().toLowerCase();
      const hasMatchingAlias = node.aliases.some(
        a => a.toLowerCase() === targetAlias || a.toLowerCase().includes(targetAlias)
      );
      if (!hasMatchingAlias) return false;
    }

    // 4. case-insensitive category match
    if (constraints.category !== undefined) {
      const targetCategory = String(constraints.category).trim().toLowerCase();
      if (node.category.toLowerCase() !== targetCategory) {
        return false;
      }
    }

    // 5. case-insensitive exact tag match
    if (constraints.tag !== undefined) {
      const targetTag = String(constraints.tag).trim().toLowerCase();
      const hasMatchingTag = node.tags.some(t => t.toLowerCase() === targetTag);
      if (!hasMatchingTag) return false;
    }

    // 6. case-insensitive department match
    if (constraints.department !== undefined) {
      const targetDept = String(constraints.department).trim().toLowerCase();
      if (!node.department) return false;
      const nodeDeptLower = node.department.toLowerCase();
      if (nodeDeptLower !== targetDept && !nodeDeptLower.includes(targetDept)) {
        return false;
      }
    }

    // 7. accessibility filter
    if (constraints.accessible !== undefined) {
      const targetAccessible = Boolean(constraints.accessible);
      if (node.accessible !== targetAccessible) {
        return false;
      }
    }

    // 8. facility / custom attribute lookup
    if (constraints.facility !== undefined) {
      const targetFacility = String(constraints.facility).trim().toLowerCase();
      const matchesCustomAttribute = Object.keys(node.customAttributes).some(
        k => k.toLowerCase() === targetFacility && Boolean(node.customAttributes[k])
      );
      const matchesTag = node.tags.some(t => t.toLowerCase() === targetFacility);
      const matchesAlias = node.aliases.some(a => a.toLowerCase().includes(targetFacility));
      const matchesName = node.name.toLowerCase().includes(targetFacility);
      const matchesCategory = node.category.toLowerCase() === targetFacility;

      if (!matchesCustomAttribute && !matchesTag && !matchesAlias && !matchesName && !matchesCategory) {
        return false;
      }
    }

    // 9. floor match
    if (constraints.floor !== undefined) {
      const floorNum = Number(constraints.floor);
      const floorMatches =
        (!isNaN(floorNum) && node.floorNumber === floorNum) ||
        node.floorId === String(constraints.floor).trim();
      if (!floorMatches) return false;
    }

    // 10. capacityMin match
    if (constraints.capacityMin !== undefined) {
      const minCap = Number(constraints.capacityMin);
      if (typeof node.capacity !== 'number' || isNaN(minCap) || node.capacity < minCap) {
        return false;
      }
    }

    return true;
  }

  /**
   * Helper: Searches query text for any known alias present in the graph.
   * Returns the matched alias string, or null if none found.
   * Longer alias matches are prioritized.
   * @param {string} text
   * @returns {string|null}
   */
  findAliasInText(text) {
    if (typeof text !== 'string') return null;
    const lower = text.toLowerCase();

    let bestMatch = null;
    for (const node of this._nodeList) {
      for (const alias of node.aliases) {
        const aliasLower = alias.toLowerCase();
        if (lower.includes(aliasLower)) {
          if (!bestMatch || aliasLower.length > bestMatch.length) {
            bestMatch = alias;
          }
        }
      }
    }
    return bestMatch;
  }

  /**
   * Helper: Searches query text for any known node name present in the graph.
   * Returns the matched name string, or null if none found.
   * @param {string} text
   * @returns {string|null}
   */
  findNameInText(text) {
    if (typeof text !== 'string') return null;
    const lower = text.toLowerCase();

    let bestMatch = null;
    for (const node of this._nodeList) {
      const nameLower = node.name.toLowerCase();
      if (lower.includes(nameLower)) {
        if (!bestMatch || nameLower.length > bestMatch.length) {
          bestMatch = node.name;
        }
      }
    }
    return bestMatch;
  }

  /**
   * Helper: Searches query text for any known department present in the graph.
   * @param {string} text
   * @returns {string|null}
   */
  findDepartmentInText(text) {
    if (typeof text !== 'string') return null;
    const lower = text.toLowerCase();

    const depts = new Set();
    for (const node of this._nodeList) {
      if (node.department) depts.add(node.department);
    }
    if (this._building && this._building.departments) {
      for (const d of this._building.departments) depts.add(d);
    }

    for (const dept of depts) {
      if (lower.includes(dept.toLowerCase())) {
        return dept;
      }
    }
    return null;
  }

  /**
   * Total number of normalized nodes stored in the graph.
   */
  get count() {
    return this._nodes.size;
  }
}

// Export singleton instance and class definition
const defaultInstance = new SemanticGraphService();
defaultInstance.SemanticGraphService = SemanticGraphService;
defaultInstance.ALLOWED_CONSTRAINTS = ALLOWED_CONSTRAINTS;

module.exports = defaultInstance;
