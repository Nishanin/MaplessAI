const path = require('path');
const semanticGraphService = require('../src/features/ai/semantic_graph.service');
const { SemanticGraphService } = semanticGraphService;

/**
 * Semantic Knowledge Graph Backend Service Unit Tests (Owner: Surabhi)
 *
 * Tests cover:
 *   1.  Dataset loads successfully.
 *   2.  Exact node ID lookup works.
 *   3.  Name lookup is case-insensitive.
 *   4.  Alias lookup works.
 *   5.  Category lookup works.
 *   6.  Tag lookup works.
 *   7.  Department lookup works.
 *   8.  Accessibility filtering works.
 *   9.  Facility/custom-attribute lookup works where supported.
 *   10. Exactly one candidate produces a resolved result.
 *   11. Multiple candidates produce an ambiguity result.
 *   12. Zero candidates produce not_found.
 *   13. No candidate ID is invented.
 *   14. Input constraints cannot trigger SQL or arbitrary command execution.
 *   15. Internal graph state cannot be mutated by caller (immutability).
 *   16. Normalized preservation of building and floor metadata.
 */

describe('SemanticGraphService — Unit & Resolution Tests', () => {
  // ── 1. Dataset loads successfully ─────────────────────────────────────────
  it('1. should load the building dataset successfully into normalized structures', () => {
    expect(semanticGraphService.count).toBeGreaterThan(0);
    expect(semanticGraphService.count).toBe(8); // 8 nodes in vit_floor_1.json

    const building = semanticGraphService.getBuildingInfo();
    expect(building.id).toBe('vit-ce');
    expect(building.name).toBe('VIT Computer Engineering');
    expect(Array.isArray(building.departments)).toBe(true);

    const floor = semanticGraphService.getFloorInfo();
    expect(floor.id).toBe('floor-1');
    expect(floor.floorNumber).toBe(1);
  });

  // ── 2. Exact node ID lookup ───────────────────────────────────────────────
  it('2. should find a node by exact node ID', () => {
    const node = semanticGraphService.getNodeById('lab-101');
    expect(node).not.toBeNull();
    expect(node.id).toBe('lab-101');
    expect(node.name).toBe('Lab 101');
    expect(node.category).toBe('laboratory');
    expect(node.accessible).toBe(true);
    expect(node.floorId).toBe('floor-1');

    const nonExistent = semanticGraphService.getNodeById('non-existent-node');
    expect(nonExistent).toBeNull();
  });

  // ── 3. Name lookup is case-insensitive ────────────────────────────────────
  it('3. should lookup nodes by name case-insensitively', () => {
    const resExactLower = semanticGraphService.resolveCandidates({ name: 'lab 101' });
    expect(resExactLower.status).toBe('resolved');
    expect(resExactLower.candidateIds).toEqual(['lab-101']);

    const resUpper = semanticGraphService.resolveCandidates({ name: 'DEPARTMENT LIBRARY' });
    expect(resUpper.status).toBe('resolved');
    expect(resUpper.candidateIds).toEqual(['library']);

    const resMixed = semanticGraphService.resolveCandidates({ name: 'mAiN eNtRaNcE' });
    expect(resMixed.status).toBe('resolved');
    expect(resMixed.candidateIds).toEqual(['entrance']);
  });

  // ── 4. Alias lookup ───────────────────────────────────────────────────────
  it('4. should resolve candidate by case-insensitive alias', () => {
    // "Software Lab 1" is an alias of lab-101
    const res1 = semanticGraphService.resolveCandidates({ alias: 'software lab 1' });
    expect(res1.status).toBe('resolved');
    expect(res1.candidateIds).toContain('lab-101');

    // "Help Desk" is an alias of reception
    const res2 = semanticGraphService.resolveCandidates({ alias: 'help desk' });
    expect(res2.status).toBe('resolved');
    expect(res2.candidateIds).toContain('reception');

    // Substring alias match: "Fire Exit" should match "Fire Exit 1" -> exit-a
    const res3 = semanticGraphService.resolveCandidates({ alias: 'fire exit' });
    expect(res3.status).toBe('resolved');
    expect(res3.candidateIds).toContain('exit-a');
  });

  // ── 5. Category lookup ────────────────────────────────────────────────────
  it('5. should resolve candidates by category case-insensitively', () => {
    const resLab = semanticGraphService.resolveCandidates({ category: 'laboratory' });
    expect(resLab.status).toBe('resolved');
    expect(resLab.candidateIds).toEqual(['lab-101']);

    const resElevator = semanticGraphService.resolveCandidates({ category: 'ELEVATOR' });
    expect(resElevator.status).toBe('resolved');
    expect(resElevator.candidateIds).toEqual(['lift']);

    const resExit = semanticGraphService.resolveCandidates({ category: 'emergency_exit' });
    expect(resExit.status).toBe('resolved');
    expect(resExit.candidateIds).toEqual(['exit-a']);
  });

  // ── 6. Tag lookup ─────────────────────────────────────────────────────────
  it('6. should resolve candidate nodes matching semantic tags', () => {
    // "computers" tag is attached to lab-101
    const res1 = semanticGraphService.resolveCandidates({ tag: 'computers' });
    expect(res1.status).toBe('resolved');
    expect(res1.candidateIds).toEqual(['lab-101']);

    // "books" tag is attached to library
    const res2 = semanticGraphService.resolveCandidates({ tag: 'books' });
    expect(res2.status).toBe('resolved');
    expect(res2.candidateIds).toEqual(['library']);

    // Case-insensitivity check: "EMERGENCY" tag matches exit-a
    const res3 = semanticGraphService.resolveCandidates({ tag: 'EMERGENCY' });
    expect(res3.status).toBe('resolved');
    expect(res3.candidateIds).toEqual(['exit-a']);
  });

  // ── 7. Department lookup ──────────────────────────────────────────────────
  it('7. should resolve candidates by department', () => {
    // "Administration" department is attached only to reception
    const resAdmin = semanticGraphService.resolveCandidates({ department: 'Administration' });
    expect(resAdmin.status).toBe('resolved');
    expect(resAdmin.candidateIds).toEqual(['reception']);

    // "Computer Engineering" is attached to lab-101 and library -> multiple candidates
    const resCompEng = semanticGraphService.resolveCandidates({ department: 'Computer Engineering' });
    expect(resCompEng.status).toBe('ambiguous');
    expect(resCompEng.matchCount).toBe(2);
    expect(resCompEng.candidateIds).toEqual(expect.arrayContaining(['lab-101', 'library']));
  });

  // ── 8. Accessibility filtering ────────────────────────────────────────────
  it('8. should filter candidates by accessibility flag', () => {
    // staircase is the only node with accessible === false in vit_floor_1.json
    const resInaccessible = semanticGraphService.resolveCandidates({
      category: 'stairs',
      accessible: true
    });
    expect(resInaccessible.status).toBe('not_found');
    expect(resInaccessible.matchCount).toBe(0);
    expect(resInaccessible.candidateIds).toEqual([]);

    const resInaccessibleCorrect = semanticGraphService.resolveCandidates({
      category: 'stairs',
      accessible: false
    });
    expect(resInaccessibleCorrect.status).toBe('resolved');
    expect(resInaccessibleCorrect.candidateIds).toEqual(['staircase']);

    // laboratory is accessible
    const resLabAccessible = semanticGraphService.resolveCandidates({
      category: 'laboratory',
      accessible: true
    });
    expect(resLabAccessible.status).toBe('resolved');
    expect(resLabAccessible.candidateIds).toEqual(['lab-101']);
  });

  // ── 9. Facility / custom-attribute lookup ─────────────────────────────────
  it('9. should resolve nodes by facility and custom attributes', () => {
    // wifiZone is true for library
    const resWifi = semanticGraphService.resolveCandidates({ facility: 'wifiZone' });
    expect(resWifi.status).toBe('resolved');
    expect(resWifi.candidateIds).toEqual(['library']);

    // airConditioned is true for lab-101
    const resAC = semanticGraphService.resolveCandidates({ facility: 'airConditioned' });
    expect(resAC.status).toBe('resolved');
    expect(resAC.candidateIds).toEqual(['lab-101']);

    // brailleButtons is true in elevator metadata
    const resBraille = semanticGraphService.resolveCandidates({ facility: 'brailleButtons' });
    expect(resBraille.status).toBe('resolved');
    expect(resBraille.candidateIds).toEqual(['lift']);
  });

  // ── 10. Exactly one candidate -> resolved ─────────────────────────────────
  it('10. should return resolved status when exactly one candidate matches', () => {
    const result = semanticGraphService.resolveCandidates({
      category: 'laboratory',
      department: 'Computer Engineering'
    });

    expect(result.status).toBe('resolved');
    expect(result.matchCount).toBe(1);
    expect(result.candidateIds).toHaveLength(1);
    expect(result.candidateIds[0]).toBe('lab-101');
    expect(result.candidates[0].id).toBe('lab-101');
    expect(result.candidates[0].name).toBe('Lab 101');
  });

  // ── 11. Multiple candidates -> ambiguous ──────────────────────────────────
  it('11. should return ambiguous status when multiple candidates match', () => {
    const result = semanticGraphService.resolveCandidates({
      department: 'Computer Engineering'
    });

    expect(result.status).toBe('ambiguous');
    expect(result.matchCount).toBe(2);
    expect(result.candidateIds).toEqual(expect.arrayContaining(['lab-101', 'library']));
    expect(result.candidates).toHaveLength(2);
  });

  // ── 12. Zero candidates -> not_found ──────────────────────────────────────
  it('12. should return not_found status when zero candidates match', () => {
    const result = semanticGraphService.resolveCandidates({
      category: 'cafeteria' // does not exist in vit_floor_1.json
    });

    expect(result.status).toBe('not_found');
    expect(result.matchCount).toBe(0);
    expect(result.candidateIds).toEqual([]);
    expect(result.candidates).toEqual([]);
  });

  // ── 13. No candidate ID is invented ───────────────────────────────────────
  it('13. should never invent candidate IDs not present in the dataset', () => {
    const allKnownIds = new Set([
      'entrance',
      'reception',
      'corridor',
      'lab-101',
      'library',
      'staircase',
      'lift',
      'exit-a'
    ]);

    const queries = [
      { category: 'laboratory' },
      { category: 'emergency_exit' },
      { tag: 'help' },
      { alias: 'Computer Lab 101' },
      { department: 'Computer Engineering' },
      { category: 'non_existent_category' },
      { nodeId: 'fake-id-999' }
    ];

    for (const q of queries) {
      const result = semanticGraphService.resolveCandidates(q);
      for (const id of result.candidateIds) {
        expect(allKnownIds.has(id)).toBe(true);
      }
    }
  });

  // ── 14. Security: input constraints cannot execute SQL or arbitrary code ─
  it('14. should treat SQL keywords and script injections as literal string filters', () => {
    const maliciousInputs = [
      { category: "laboratory' OR '1'='1" },
      { name: "'; DROP TABLE nodes; --" },
      { tag: '<script>alert(1)</script>' },
      { __proto__: { evil: true } },
      { arbitraryUnknownCommand: 'DELETE FROM buildings' }
    ];

    for (const input of maliciousInputs) {
      // Must not throw, must not execute SQL, must safely resolve or return not_found
      expect(() => {
        const res = semanticGraphService.resolveCandidates(input);
        expect(['resolved', 'ambiguous', 'not_found']).toContain(res.status);
        expect(Array.isArray(res.candidateIds)).toBe(true);
      }).not.toThrow();
    }
  });

  // ── 15. Immutability: caller cannot mutate internal graph state ───────────
  it('15. should prevent external mutations of internal graph data', () => {
    const node1 = semanticGraphService.getNodeById('lab-101');
    expect(node1).not.toBeNull();

    // Attempt mutation on returned copy
    node1.name = 'Hacked Lab';
    node1.aliases.push('Evil Alias');
    node1.customAttributes.hacked = true;

    // Subsequent retrieval must be completely unaffected
    const node2 = semanticGraphService.getNodeById('lab-101');
    expect(node2.name).toBe('Lab 101');
    expect(node2.aliases).not.toContain('Evil Alias');
    expect(node2.customAttributes.hacked).toBeUndefined();
  });

  // ── 16. Text search helpers (aliases, names, departments) ──────────────────
  it('16. should find known aliases, names, and departments within natural language text', () => {
    expect(semanticGraphService.findAliasInText('Where is Software Lab 1 on this floor?')).toBe('Software Lab 1');
    expect(semanticGraphService.findAliasInText('Take me to the Front Desk please')).toBe('Front Desk');
    expect(semanticGraphService.findAliasInText('Show me the weather')).toBeNull();

    expect(semanticGraphService.findNameInText('Where is Reception located?')).toBe('Reception');
    expect(semanticGraphService.findNameInText('Navigate to Department Library')).toBe('Department Library');

    expect(semanticGraphService.findDepartmentInText('Show me rooms in Computer Engineering')).toBe('Computer Engineering');
  });
});
