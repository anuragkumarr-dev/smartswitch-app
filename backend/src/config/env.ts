import dotenv from 'dotenv';
import path from 'path';

// Load .env
dotenv.config();

function formatPem(raw?: string): string {
  if (!raw) return '';
  return raw.replace(/\\n/g, '\n');
}

export const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  host: process.env.HOST || '0.0.0.0',
  nodeEnv: process.env.NODE_ENV || 'development',
  databasePath: process.env.DATABASE_PATH || ':memory:',
  
  // Ed25519 signing keys
  tokenPrivateKey: formatPem(process.env.TOKEN_SIGNING_PRIVATE_KEY),
  tokenPublicKey: formatPem(process.env.TOKEN_SIGNING_PUBLIC_KEY),

  // Rate limits
  rateLimitLoginMax: parseInt(process.env.RATE_LIMIT_LOGIN_MAX || '10', 10),
  rateLimitTokenMax: parseInt(process.env.RATE_LIMIT_TOKEN_MAX || '30', 10),
  rateLimitWindowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000', 10), // 15 mins

  // MQTT
  mqttBrokerUrl: process.env.MQTT_BROKER_URL || 'mqtt://localhost:1883',
  mqttWsUrl: process.env.MQTT_WS_URL || 'ws://localhost:8083/mqtt',
};
