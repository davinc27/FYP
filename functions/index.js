// Firebase Cloud Functions for Terra Plant Monitoring
const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
admin.initializeApp();

// Alert thresholds (same as in the app)
const THRESHOLDS = {
  lowHumidity: 60.0,
  lowSoilMoisture: 30.0,
  highTemperature: 35.0,
  lowTemperature: 15.0,
};

// Cooldown period in minutes
const ALERT_COOLDOWN_MINUTES = 30;

// Store last alert times
const lastAlertTimes = {};

// Function to monitor sensor data and send alerts
exports.monitorSensorData = functions.database
  .ref("/sensorData/{basketId}/latest")
  .onWrite(async (change, context) => {
    const basketId = context.params.basketId;
    const data = change.after.val();

    if (!data) {
      console.log(`No data for ${basketId}`);
      return null;
    }

    console.log(`Monitoring sensor data for ${basketId}:`, data);

    try {
      // Check for alerts
      await checkBasketAlerts(basketId, data);
    } catch (error) {
      console.error(`Error monitoring ${basketId}:`, error);
    }

    return null;
  });

// Check alerts for a specific basket
async function checkBasketAlerts(basketId, sensorData) {
  const temperature = parseFloat(sensorData.temperature) || 0;
  const humidity = parseFloat(sensorData.humidity) || 0;
  const soilMoisture = parseFloat(sensorData.soilMoisture) || 0;

  console.log(
    `${basketId} - Temp: ${temperature}, Humidity: ${humidity}, Moisture: ${soilMoisture}`
  );

  // Check humidity alert
  if (humidity < THRESHOLDS.lowHumidity && humidity > 0) {
    await triggerAlert(
      basketId,
      "Low Humidity",
      `Humidity is ${humidity.toFixed(
        0
      )}%. Consider increasing ventilation or moisture.`,
      "warning"
    );
  }

  // Check soil moisture alert
  if (soilMoisture < THRESHOLDS.lowSoilMoisture && soilMoisture > 0) {
    await triggerAlert(
      basketId,
      "Water Needed",
      `Soil moisture is low (${soilMoisture.toFixed(0)}%). Water your plants!`,
      "critical"
    );
  }

  // Check high temperature alert
  if (temperature > THRESHOLDS.highTemperature) {
    await triggerAlert(
      basketId,
      "High Temperature",
      `Temperature is ${temperature.toFixed(1)}°C. Provide shade or cooling.`,
      "warning"
    );
  }

  // Check low temperature alert
  if (temperature < THRESHOLDS.lowTemperature && temperature > 0) {
    await triggerAlert(
      basketId,
      "Low Temperature",
      `Temperature is ${temperature.toFixed(1)}°C. Melons need warmth!`,
      "warning"
    );
  }
}

// Trigger an alert if cooldown period has passed
async function triggerAlert(basketId, alertType, message, severity) {
  const alertKey = `${basketId}_${alertType}`;
  const now = new Date();

  // Check cooldown
  if (lastAlertTimes[alertKey]) {
    const timeSinceLastAlert = now - lastAlertTimes[alertKey];
    const minutesSinceLastAlert = timeSinceLastAlert / (1000 * 60);

    if (minutesSinceLastAlert < ALERT_COOLDOWN_MINUTES) {
      console.log(`Alert ${alertKey} is in cooldown period`);
      return;
    }
  }

  // Update last alert time
  lastAlertTimes[alertKey] = now;

  try {
    // Get FCM tokens for all users
    const tokens = await getFCMTokens();

    if (tokens.length === 0) {
      console.log("No FCM tokens available");
      return;
    }

    // Send FCM notification
    const payload = {
      notification: {
        title: `🌱 Terra Alert - ${alertType}`,
        body: `${formatBasketName(basketId)}: ${message}`,
        icon: "ic_launcher",
        color: "#4CAF50",
      },
      data: {
        basketId: basketId,
        alertType: alertType,
        severity: severity,
        timestamp: now.getTime().toString(),
      },
      tokens: tokens,
    };

    const response = await admin.messaging().sendMulticast(payload);
    console.log(
      `FCM notification sent: ${response.successCount} successful, ${response.failureCount} failed`
    );

    // Log the alert in Firebase
    await admin.database().ref("notifications").push().set({
      basketId: basketId,
      alertType: alertType,
      message: message,
      severity: severity,
      timestamp: admin.database.ServerValue.TIMESTAMP,
      fcmSent: true,
      fcmSuccessCount: response.successCount,
      fcmFailureCount: response.failureCount,
    });

    console.log(`🚨 Alert sent: ${alertType} for ${basketId}`);
  } catch (error) {
    console.error(`Error sending alert for ${basketId}:`, error);
  }
}

// Get FCM tokens from user settings
async function getFCMTokens() {
  try {
    const snapshot = await admin
      .database()
      .ref("userSettings/notificationPreferences")
      .once("value");
    const data = snapshot.val();

    if (!data) {
      return [];
    }

    // If it's a single object, return its token
    if (data.fcmToken) {
      return [data.fcmToken];
    }

    // If it's multiple users, collect all tokens
    const tokens = [];
    Object.values(data).forEach((user) => {
      if (user.fcmToken) {
        tokens.push(user.fcmToken);
      }
    });

    return tokens;
  } catch (error) {
    console.error("Error getting FCM tokens:", error);
    return [];
  }
}

// Format basket name for display
function formatBasketName(basketId) {
  if (basketId.startsWith("basket")) {
    const number = basketId.substring(6);
    return `Basket ${number}`;
  }
  return basketId;
}

// HTTP function to manually trigger alerts (for testing)
exports.triggerTestAlert = functions.https.onRequest(async (req, res) => {
  try {
    await triggerAlert(
      "basket1",
      "Test Alert",
      "This is a test alert from Firebase Cloud Functions.",
      "info"
    );

    res.status(200).json({ success: true, message: "Test alert triggered" });
  } catch (error) {
    console.error("Error triggering test alert:", error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// HTTP function to get monitoring status
exports.getMonitoringStatus = functions.https.onRequest(async (req, res) => {
  try {
    const status = {
      thresholds: THRESHOLDS,
      cooldownMinutes: ALERT_COOLDOWN_MINUTES,
      lastAlertTimes: lastAlertTimes,
      timestamp: new Date().toISOString(),
    };

    res.status(200).json(status);
  } catch (error) {
    console.error("Error getting monitoring status:", error);
    res.status(500).json({ success: false, error: error.message });
  }
});
