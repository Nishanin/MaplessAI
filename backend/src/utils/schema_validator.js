const Ajv = require('ajv');
const addFormats = require('ajv-formats');
const fs = require('fs');
const path = require('path');

const ajv = new Ajv({ allErrors: true, coerceTypes: true });
addFormats(ajv);

const contractsDir = path.resolve(__dirname, '../../../contracts');

const schemas = {};

/**
 * Loads and compiles a schema from contracts directory if not already cached.
 */
function getValidator(schemaName) {
  if (!schemas[schemaName]) {
    const filePath = path.join(contractsDir, `${schemaName}.schema.json`);
    if (!fs.existsSync(filePath)) {
      throw new Error(`Contract schema not found: ${filePath}`);
    }
    const schemaContent = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    schemas[schemaName] = ajv.compile(schemaContent);
  }
  return schemas[schemaName];
}

/**
 * Validates data against a named contract schema.
 * @param {string} schemaName - Name of schema file without '.schema.json'
 * @param {object} data - Object to validate
 * @returns {{ valid: boolean, errors: Array }}
 */
function validateContract(schemaName, data) {
  const validator = getValidator(schemaName);
  const valid = validator(data);
  return {
    valid,
    errors: validator.errors || []
  };
}

module.exports = {
  validateContract,
  getValidator
};
