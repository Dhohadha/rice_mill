const mongoose = require('mongoose');

const meterDataSchema = new mongoose.Schema({
  meterId: { type: Number, default: 1 },
  kW_Total: Number,
  kW_R: Number,
  kW_Y: Number,
  kW_B: Number,
  kVAR_Total: Number,
  kVAR_R: Number,
  kVAR_Y: Number,
  kVAR_B: Number,
  kVA_Total: Number,
  kVA_R: Number,
  kVA_Y: Number,
  kVA_B: Number,
  PF_Avg: Number,
  PF_R: Number,
  PF_Y: Number,
  PF_B: Number,
  kWh: Number,
  kVAh: Number,
  kVARh_Ind: Number,
  kVARh_Cap: Number,
  timestamp: { type: Date, default: Date.now }
});

// TTL Index to delete data older than 24 hours
meterDataSchema.index({ timestamp: 1 }, { expireAfterSeconds: 86400 });

module.exports = mongoose.model('MeterData', meterDataSchema);
