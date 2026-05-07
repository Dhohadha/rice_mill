require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const mqtt = require('mqtt');
const cors = require('cors');
const cron = require('node-cron');

const MeterData = require('./models/MeterData');
const DailyUsage = require('./models/DailyUsage');
const UserSettings = require('./models/UserSettings');
const Notification = require('./models/Notification');
const DeviceToken = require('./models/DeviceToken');
const admin = require('firebase-admin');

// Initialize Firebase Admin
try {
  const serviceAccount = require('./service_account_key.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
  console.log('🔥 Firebase Admin initialized');
} catch (err) {
  console.error('❌ Firebase Admin initialization error:', err.message);
}

const app = express();
app.use(cors());
app.use(express.json());

// MongoDB Connection
// Defaulting to a local MongoDB instance for development
const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/ricemill';
mongoose.connect(MONGO_URI)
  .then(() => console.log('MongoDB connected'))
  .catch(err => console.error('MongoDB connection error:', err));

// MQTT Setup
const MQTT_BROKER = 'mqtt://broker.emqx.io:1883';
const MQTT_TOPIC = 'EMS1/data';
const mqttClient = mqtt.connect(MQTT_BROKER);

mqttClient.on('connect', () => {
  console.log('✅ Connected to MQTT Broker:', MQTT_BROKER);
  mqttClient.subscribe(MQTT_TOPIC, (err) => {
    if (err) console.error('❌ MQTT Subscribe error:', err);
    else console.log('📁 Subscribed to topic:', MQTT_TOPIC);
  });
});

// Throttle control for saving data
let lastSaveTime = 0;
const SAVE_INTERVAL = 60 * 1000; // 1 minute

// Process incoming MQTT messages
mqttClient.on('message', async (topic, message) => {
  console.log(`📩 Received message on [${topic}]:`, message.toString());
  if (topic === MQTT_TOPIC) {
    try {
      const payload = JSON.parse(message.toString());
      if (payload.status === "no_data") return; 

      const now = Date.now();
      if (now - lastSaveTime >= SAVE_INTERVAL) {
        const newData = new MeterData(payload);
        await newData.save();
        lastSaveTime = now;
        console.log(`💾 Data saved to MongoDB (Meter: ${payload.meterId || 1}, KW: ${payload.KW})`);
      }

      // Check limits
      let settings = await UserSettings.findOne();
      if (!settings) {
        settings = new UserSettings();
        await settings.save();
      }

      const alerts = [];
      if (payload.KVA && payload.KVA > settings.cmdLimit) {
        alerts.push({ type: 'CMD', msg: `CMD Alert: Current kVA (${payload.KVA}) exceeded limit (${settings.cmdLimit})!`});
      }
      if (payload.KW && payload.KW > settings.powerLimit) {
        alerts.push({ type: 'POWER', msg: `POWER Alert: Current kW (${payload.KW}) exceeded limit (${settings.powerLimit})!`});
      }
      if (payload.PF && payload.PF < settings.pfLimit) {
        alerts.push({ type: 'PF', msg: `PF Alert: Current PF (${payload.PF}) fell below limit (${settings.pfLimit})!`});
      }

      for (let alert of alerts) {
        // Prevent spamming the same alert within 5 minutes
        const recentAlert = await Notification.findOne({
          type: alert.type,
          timestamp: { $gte: new Date(Date.now() - 5 * 60 * 1000) }
        });
        if (!recentAlert) {
          await new Notification({ title: `Limit Exceeded`, message: alert.msg, type: alert.type }).save();
          
          // Send FCM push notifications
          try {
            const tokens = await DeviceToken.find();
            const registrationTokens = tokens.map(t => t.token);

            if (registrationTokens.length > 0) {
              const message = {
                data: {
                  title: '⚠️ Rice Mill Alert',
                  body: alert.msg,
                },
                tokens: registrationTokens,
                android: {
                  priority: 'high',
                },
              };

              const response = await admin.messaging().sendEachForMulticast(message);
              console.log(`📲 Successfully sent ${response.successCount} push notifications`);
              
              // Optional: Cleanup invalid tokens
              if (response.failureCount > 0) {
                const failedTokens = [];
                response.responses.forEach((resp, idx) => {
                  if (!resp.success) {
                    failedTokens.push(registrationTokens[idx]);
                  }
                });
                if (failedTokens.length > 0) {
                  await DeviceToken.deleteMany({ token: { $in: failedTokens } });
                }
              }
            }
          } catch (fcmErr) {
            console.error('❌ FCM Send Error:', fcmErr.message);
          }
        }
      }

    } catch (err) {
      console.error("❌ Error processing MQTT message:", err.message);
    }
  }
});

// Daily Cron Job (Midnight) to calculate total kWh consumed
cron.schedule('0 0 * * *', async () => {
  try {
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayEnd = new Date(todayStart);
    todayEnd.setDate(todayStart.getDate() + 1);

    // Find min and max KWH for the day
    const minRec = await MeterData.findOne({ timestamp: { $gte: todayStart, $lt: todayEnd } }).sort({ KWH: 1 });
    const maxRec = await MeterData.findOne({ timestamp: { $gte: todayStart, $lt: todayEnd } }).sort({ KWH: -1 });

    if (minRec && maxRec) {
      const consumedKWh = maxRec.KWH - minRec.KWH;
      // Save for yesterday
      const yesterday = new Date(todayStart);
      yesterday.setDate(yesterday.getDate() - 1);
      
      await DailyUsage.updateOne(
        { date: yesterday },
        { totalKWh: consumedKWh },
        { upsert: true }
      );
      console.log(`Calculated daily usage for ${yesterday.toDateString()}: ${consumedKWh} kWh`);
    }

  } catch (err) {
    console.error('Error in cron job:', err);
  }
});


// ================= APIs =================

// History Data for Graph (Hour/Day breakdown)
app.get('/api/history', async (req, res) => {
  try {
    const { range } = req.query; // 'hour' or 'day'
    const now = new Date();
    const startDate = new Date();
    
    if (range === 'hour') {
      startDate.setHours(now.getHours() - 1);
    } else {
      // Default to day (last 24 hours)
      startDate.setHours(now.getHours() - 24);
    }

    console.log(`📊 Fetching history for range: ${range}`);
    const data = await MeterData.find({ timestamp: { $gte: startDate } }).sort({ timestamp: 1 });
    console.log(`📈 Found ${data.length} history records`);
    // In production, we might want to group this data instead of returning all raw points.
    // However, since readings are every 10s, an hour is ~360 points (fine for chart).
    // A day is ~8640 points (might need downsampling, doing simple skip for now)
    
    let chartData = data;
    if (range !== 'hour' && data.length > 200) {
      const step = Math.floor(data.length / 200);
      chartData = data.filter((_, i) => i % step === 0);
    }

    res.json(chartData.map(d => ({ 
      timestamp: d.timestamp, 
      KWH: d.KWH, 
      KVA: d.KVA, 
      KW: d.KW 
    })));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get User Settings
app.get('/api/settings', async (req, res) => {
  try {
    let settings = await UserSettings.findOne();
    if (!settings) settings = await new UserSettings().save();
    console.log('⚙️ Settings fetched');
    res.json(settings);
  } catch(err) { res.status(500).json({ error: err.message }); }
});

// Update User Settings
app.post('/api/settings', async (req, res) => {
  try {
    const { cmdLimit, cmdMaxGauge, powerLimit, powerMaxGauge, pfLimit } = req.body;
    const updates = {};
    if (cmdLimit !== undefined) updates.cmdLimit = cmdLimit;
    if (cmdMaxGauge !== undefined) updates.cmdMaxGauge = cmdMaxGauge;
    if (powerLimit !== undefined) updates.powerLimit = powerLimit;
    if (powerMaxGauge !== undefined) updates.powerMaxGauge = powerMaxGauge;
    if (pfLimit !== undefined) updates.pfLimit = pfLimit;

    const settings = await UserSettings.findOneAndUpdate(
      { singletonId: "default" },
      { $set: updates },
      { returnDocument: 'after', upsert: true }
    );
    console.log('✅ Settings updated in DB:', updates);
    res.json(settings);
  } catch(err) { res.status(500).json({ error: err.message }); }
});

// Get Notification History
app.get('/api/notifications', async (req, res) => {
  try {
    const latest = await Notification.find().sort({ timestamp: -1 }).limit(100);
    res.json(latest);
  } catch(err) { res.status(500).json({ error: err.message }); }
});

// Clear Notifications
app.delete('/api/notifications', async (req, res) => {
  try {
    await Notification.deleteMany({});
    res.json({ success: true });
  } catch(err) { res.status(500).json({ error: err.message }); }
});

// Delete Single Notification
app.delete('/api/notifications/:id', async (req, res) => {
  try {
    await Notification.findByIdAndDelete(req.params.id);
    res.json({ success: true });
  } catch(err) { res.status(500).json({ error: err.message }); }
});

// Register FCM Token
app.post('/api/fcm-token', async (req, res) => {
  try {
    const { token } = req.body;
    if (!token) return res.status(400).json({ error: 'Token is required' });

    await DeviceToken.findOneAndUpdate(
      { token },
      { lastUpdated: Date.now() },
      { upsert: true }
    );
    console.log('✅ FCM Token registered/updated');
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Test Notification Route
app.post('/api/test-notification', async (req, res) => {
  try {
    const { token, title, message } = req.body;
    if (!token) return res.status(400).json({ error: 'Token is required' });

    const payload = {
      data: {
        title: title || 'Test Notification',
        body: message || 'This is a test notification from the server',
      },
      token: token,
      android: {
        priority: 'high',
      },
    };

    const response = await admin.messaging().send(payload);
    console.log('✅ Test notification sent successfully:', response);
    res.json({ success: true, messageId: response });
  } catch (err) {
    console.error('❌ Test notification error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// Get Daily Usage for total calculation
app.get('/api/daily-usage', async (req, res) => {
  try {
    const { fromDate } = req.query; 
    // fromDate format: YYYY-MM-DD
    if (!fromDate) return res.status(400).json({ error: 'fromDate is required' });

    const start = new Date(fromDate);
    const usages = await DailyUsage.find({ date: { $gte: start } });
    
    const totalConsumption = usages.reduce((sum, u) => sum + u.totalKWh, 0);

    // Also factor in "today's" consumption since midnight
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const minToday = await MeterData.findOne({ timestamp: { $gte: todayStart } }).sort({ KWH: 1 });
    const maxToday = await MeterData.findOne({ timestamp: { $gte: todayStart } }).sort({ KWH: -1 });

    let todayConsumption = 0;
    if (minToday && maxToday && maxToday.KWH >= minToday.KWH) {
       todayConsumption = maxToday.KWH - minToday.KWH;
    } else if (minToday && maxToday && maxToday.KWH < minToday.KWH) {
       // Rollover case: assumes reset to 0
       todayConsumption = maxToday.KWH;
    }

    res.json({ totalKWhConsumed: totalConsumption + todayConsumption });
  } catch(err) { res.status(500).json({ error: err.message }); }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Rice Mill Server v2.1 (EMS1) listening on port ${PORT}`);
});
