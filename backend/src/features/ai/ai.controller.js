const { validateContract } = require('../../utils/schema_validator');
const { getSlmProvider, validateProviderOutput } = require('./slm_provider');
const semanticGraphService = require('./semantic_graph.service');

/**
 * AI & Semantic Knowledge Graph Controller (Owner: Surabhi)
 * Converts natural-language user requests into validated structured graph queries.
 *
 * Architecture:
 *   HTTP Request
 *   → Schema Validation (ai-query)
 *   → SLM Provider abstraction (intent / entity / constraint generation)
 *   → Provider Output Validation & Sanitization (strict whitelist enforcement)
 *   → Semantic Graph Service (deterministic candidate resolution)
 *   → Schema Validation (ai-response)
 *   → HTTP Response
 *
 * CRITICAL SECURITY INVARIANTS:
 * 1. This controller NEVER executes arbitrary SQL or raw database mutations.
 * 2. It coordinates extraction and graph resolution without hardcoded destination IDs.
 * 3. targetNodeId is generated EXCLUSIVELY by the SemanticGraphService, never the provider.
 * 4. All outgoing responses are strictly validated against contracts/ai-response.schema.json.
 */

const CONFIDENCE_THRESHOLD = 0.5;

/**
 * Builds a schema-valid FALLBACK payload.
 *
 * @param {string} [customMessage]
 * @param {number} [customConfidence]
 * @param {object} [constraints]
 * @returns {object}
 */
function buildFallbackPayload(customMessage, customConfidence = 0.0, constraints = {}) {
  return {
    intent: 'FALLBACK',
    entities: [],
    constraints: constraints && typeof constraints === 'object' ? constraints : {},
    targetNodeId: null,
    confidence: customConfidence,
    responseMessage:
      customMessage ||
      'I could not understand that request. Please rephrase — ' +
      'you can ask me to find rooms, labs, elevators, or emergency exits.'
  };
}

class AiController {
  async processQuery(req, res, next) {
    try {
      // ── 1. Input validation ─────────────────────────────────────────────
      const inputValidation = validateContract('ai-query', req.body);
      if (!inputValidation.valid) {
        return res.status(400).json({
          error: {
            code: 'VALIDATION_FAILED',
            message: 'Invalid AiQuery schema',
            details: inputValidation.errors
          }
        });
      }

      const { text, buildingId, userContext } = req.body;

      // ── 2. Query extraction via SLM Provider ────────────────────────────
      const provider = getSlmProvider();
      const rawExtraction = await provider.generateStructuredQuery({ text, userContext });

      // ── 3. Strict Provider Output Validation ────────────────────────────
      const validationResult = validateProviderOutput(rawExtraction);
      if (!validationResult.valid) {
        // Malformed provider output is safely handled via fallback
        const fallback = buildFallbackPayload('Provider extraction output was malformed.', 0.0);
        return res.status(200).json(fallback);
      }

      const extracted = validationResult.normalized;
      let { intent, entities, constraints, confidence, ambiguity } = extracted;
      let targetNodeId = null;
      let responseMessage = null;

      // ── 4. Confidence & Ambiguity Gate ──────────────────────────────────
      if (intent === 'FALLBACK' || confidence < CONFIDENCE_THRESHOLD || ambiguity) {
        let fallbackMsg;
        if (ambiguity) {
          fallbackMsg = 'Your request is ambiguous or conflicting. Please specify a single room, lab, elevator, or emergency exit.';
        }
        const fallback = buildFallbackPayload(fallbackMsg, confidence, constraints);
        const fallbackValidation = validateContract('ai-response', fallback);
        if (!fallbackValidation.valid) {
          return res.status(500).json({
            error: {
              code: 'AI_RESPONSE_VALIDATION_FAILED',
              message: 'Internal error: fallback response failed schema validation.',
              details: fallbackValidation.errors
            }
          });
        }
        return res.status(200).json(fallback);
      }

      // ── 5. Semantic Graph Candidate Resolution ──────────────────────────
      if (Object.keys(constraints).length > 0) {
        const resolution = semanticGraphService.resolveCandidates(constraints);

        if (resolution.status === 'resolved') {
          // Exactly one match found
          targetNodeId = resolution.candidateIds[0];
          const candidate = resolution.candidates[0];

          if (intent === 'EMERGENCY_EXIT') {
            responseMessage = `Emergency exit located (${candidate.name}). Please follow the highlighted route.`;
          } else if (intent === 'FIND_NEAREST') {
            responseMessage = `Nearest ${candidate.category} located (${candidate.name}). Please confirm your current location.`;
          } else if (intent === 'NAVIGATE_TO') {
            responseMessage = `Destination found: ${candidate.name}. Confirm your route on the map.`;
          } else if (intent === 'LOCATE_ROOM') {
            responseMessage = `Located ${candidate.name} on ${candidate.floorName || 'Floor 1'}.`;
          } else if (intent === 'QUERY_INFO') {
            responseMessage = `Facility info for ${candidate.name}: ${candidate.description || 'Information available on map.'}`;
          } else {
            responseMessage = `Found ${candidate.name}.`;
          }
        } else if (resolution.status === 'ambiguous') {
          // Multiple matches: safe ambiguity fallback
          intent = 'FALLBACK';
          targetNodeId = null;
          confidence = 0.50;
          const candidateNames = resolution.candidates.map(c => c.name).join(', ');
          responseMessage = `Multiple matching locations found (${candidateNames}). Please specify which one you are looking for.`;
        } else {
          // Zero matches: safe not_found fallback
          intent = 'FALLBACK';
          targetNodeId = null;
          confidence = 0.0;
          responseMessage = 'No matching location found for the specified criteria. Please rephrase or check the building map.';
        }
      } else {
        // Intent recognized but no specific constraints derived
        if (intent === 'NAVIGATE_TO') {
          responseMessage = 'Navigation requested. Please confirm your destination from the map.';
        } else if (intent === 'LOCATE_ROOM') {
          responseMessage = 'Searching for the location. Please provide more detail if possible.';
        } else if (intent === 'QUERY_INFO') {
          responseMessage = 'Looking up facility information. Please specify a room or area name.';
        }
      }

      // ── 6. Assemble response payload ────────────────────────────────────
      const responsePayload = {
        intent,
        entities,
        constraints,
        targetNodeId,
        confidence,
        responseMessage
      };

      // ── 7. Output validation ────────────────────────────────────────────
      const outputValidation = validateContract('ai-response', responsePayload);
      if (!outputValidation.valid) {
        return res.status(500).json({
          error: {
            code: 'AI_RESPONSE_VALIDATION_FAILED',
            message: 'Internal error: assembled AI response failed schema validation.',
            details: outputValidation.errors
          }
        });
      }

      return res.status(200).json(responsePayload);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new AiController();
