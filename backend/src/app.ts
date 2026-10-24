import express from 'express';
import cors from 'cors';
import { apiRouter } from './routes/apiRouter.js';

export function createApp(): express.Application {
  const app = express();

  // Basic middleware
  app.use(cors());
  app.use(express.json());

  // Health check endpoint
  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', timestamp: Date.now() });
  });

  // REST API routes
  app.use('/', apiRouter);

  return app;
}
