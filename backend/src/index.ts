import { createApp } from './app.js';
import { config } from './config/env.js';
import { getDatabase } from './db/database.js';

const app = createApp();

// Initialize database
getDatabase();

app.listen(config.port, config.host, () => {
  console.log(`[SmartSwitch Backend] Listening on http://${config.host}:${config.port}`);
  console.log(`[SmartSwitch Backend] Environment: ${config.nodeEnv}`);
});
