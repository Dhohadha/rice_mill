const mongoose = require('mongoose');

const userSettingsSchema = new mongoose.Schema({
  singletonId: { type: String, required: true, default: "default", unique: true },
  cmdLimit: { type: Number, default: 150 },
  cmdMaxGauge: { type: Number, default: 250 },
  powerLimit: { type: Number, default: 150 },
  powerMaxGauge: { type: Number, default: 250 },
  pfLimit: { type: Number, default: 0.90 }
});

module.exports = mongoose.model('UserSettings', userSettingsSchema);
