const mongoose = require('mongoose');

const dailyUsageSchema = new mongoose.Schema({
  date: { type: Date, required: true, unique: true }, // Set to the start of the day (00:00:00)
  totalKWh: { type: Number, required: true, default: 0 },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('DailyUsage', dailyUsageSchema);
