const { validateContract } = require('../../utils/schema_validator');

/**
 * AI & Semantic Knowledge Graph Controller (Owner: Surabhi)
 * Converts natural-language user requests into validated structured graph queries.
 *
 * CRITICAL SECURITY INVARIANT:
 * This controller never executes arbitrary SQL or raw database mutations.
 * It produces validated structured intents and constraints conforming to
 * contracts/ai-response.schema.json.
 */
class AiController {
  async processQuery(req, res, next) {
    try {
      const validation = validateContract('ai-query', req.body);
      if (!validation.valid) {
        return res.status(400).json({
          error: {
            code: 'VALIDATION_FAILED',
            message: 'Invalid AiQuery schema',
            details: validation.errors
          }
        });
      }

      const { text, buildingId, userContext } = req.body;
      const lower = text.toLowerCase();

      // Simple deterministic intent/entity matching placeholder
      // Full SLM inference pipeline will be developed by Surabhi in feature/surabhi-semantic-ai
      let intent = 'QUERY_INFO';
      let entities = [];
      let constraints = {};
      let targetNodeId = null;
      let confidence = 0.85;
      let responseMessage = `Processed query: "${text}"`;

      if (lower.includes('nearest') || lower.includes('closest')) {
        intent = 'FIND_NEAREST';
        if (lower.includes('lab')) {
          entities.push({ type: 'category', value: 'laboratory' });
          constraints.category = 'laboratory';
          targetNodeId = 'lab-101';
          responseMessage = 'Found Lab 101 on First Floor.';
        }
      } else if (lower.includes('exit') || lower.includes('emergency')) {
        intent = 'EMERGENCY_EXIT';
        entities.push({ type: 'category', value: 'emergency_exit' });
        targetNodeId = 'exit-a';
        responseMessage = 'Routing to Emergency Exit A.';
      } else if (lower.includes('go to') || lower.includes('take me to')) {
        intent = 'NAVIGATE_TO';
      }

      if (userContext && userContext.accessible) {
        constraints.accessible = true;
      }

      const responsePayload = {
        intent,
        entities,
        constraints,
        targetNodeId,
        confidence,
        responseMessage
      };

      res.status(200).json(responsePayload);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new AiController();
