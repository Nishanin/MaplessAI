const { validateContract } = require('../../utils/schema_validator');

/**
 * Mapping Feature Controller (Owner: Nishant)
 * Handles indoor map creation, building/floor registration, and graph ingestion.
 */
class MappingController {
  async getBuildings(req, res, next) {
    try {
      res.status(200).json({
        buildings: [
          {
            id: 'vit-ce',
            name: 'VIT Computer Engineering',
            category: 'college'
          }
        ]
      });
    } catch (error) {
      next(error);
    }
  }

  async getFloorGraph(req, res, next) {
    try {
      const { buildingId, floorId } = req.params;
      res.status(200).json({
        buildingId,
        floorId,
        nodes: [],
        edges: [],
        message: 'Floor graph endpoint placeholder (Nishant feature branch)'
      });
    } catch (error) {
      next(error);
    }
  }

  async createNode(req, res, next) {
    try {
      const validation = validateContract('node', req.body);
      if (!validation.valid) {
        return res.status(400).json({
          error: {
            code: 'VALIDATION_FAILED',
            message: 'Invalid Node schema',
            details: validation.errors
          }
        });
      }
      res.status(201).json({
        success: true,
        node: req.body,
        message: 'Node registered successfully'
      });
    } catch (error) {
      next(error);
    }
  }

  async createEdge(req, res, next) {
    try {
      const validation = validateContract('edge', req.body);
      if (!validation.valid) {
        return res.status(400).json({
          error: {
            code: 'VALIDATION_FAILED',
            message: 'Invalid Edge schema',
            details: validation.errors
          }
        });
      }
      res.status(201).json({
        success: true,
        edge: req.body,
        message: 'Edge registered successfully'
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new MappingController();
