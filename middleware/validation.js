// middleware/validation.js
const Joi = require('joi');

const validate = (schema) => {
  return (req, res, next) => {
    const { error, value } = schema.validate(req.body, {
      abortEarly: false,
      stripUnknown: true
    });
    
    if (error) {
      const errors = error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message
      }));
      
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors
      });
    }
    
    req.body = value;
    next();
  };
};

const schemas = {
  gpsData: Joi.object({
    latitude: Joi.number().min(-90).max(90).required(),
    longitude: Joi.number().min(-180).max(180).required(),
    speed: Joi.number().min(0).optional().allow(null),
    heading: Joi.number().min(0).max(360).optional().allow(null),
    altitude: Joi.number().optional().allow(null),
    accuracy: Joi.number().min(0).optional().allow(null),
    battery_level: Joi.number().integer().min(0).max(100).optional().allow(null),
    signal_strength: Joi.number().integer().min(0).max(100).optional().allow(null)
  }),

  rfidScan: Joi.object({
    rfid_tag: Joi.string().required(),
    scan_timestamp: Joi.date().iso().optional()
  }),

  createShipment: Joi.object({
    company_id: Joi.string().uuid().required(),
    truck_id: Joi.string().uuid().required(),
    destination_id: Joi.string().uuid().required(),
    origin_location: Joi.string().required(),
    destination_location: Joi.string().required(),
    estimated_arrival: Joi.date().iso().optional().allow(null),
    notes: Joi.string().optional().allow('', null),
    items: Joi.array().items(
      Joi.object({
        product_id: Joi.string().uuid().required(),
        quantity: Joi.number().positive().required(),
        unit: Joi.string().default('pieces'),
        rfid_tag: Joi.string().required()
      })
    ).min(1).required()
  }),

  registerDevice: Joi.object({
    company_id: Joi.string().uuid().required(),
    device_id: Joi.string().required(),
    device_name: Joi.string().required(),
    device_type: Joi.string().valid('gps_tracker', 'rfid_reader').required(),
    bound_to_type: Joi.string().valid('truck', 'destination').optional().allow(null),
    bound_to_id: Joi.string().uuid().optional().allow(null)
  }),

  bindDevice: Joi.object({
    bound_to_type: Joi.string().valid('truck', 'destination').required(),
    bound_to_id: Joi.string().uuid().required()
  })
};

module.exports = { validate, schemas };