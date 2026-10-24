import rateLimit from 'express-rate-limit';
import { config } from '../config/env.js';

/**
 * Rate limiters to protect authentication, activation token issuance, and invites against brute force.
 */
export const loginRateLimiter = rateLimit({
  windowMs: config.rateLimitWindowMs,
  max: config.rateLimitLoginMax,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many login attempts from this IP, please try again later.' },
});

export const tokenRateLimiter = rateLimit({
  windowMs: config.rateLimitWindowMs,
  max: config.rateLimitTokenMax,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many activation token requests, please try again later.' },
});

export const inviteRateLimiter = rateLimit({
  windowMs: config.rateLimitWindowMs,
  max: config.rateLimitTokenMax,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many invite creations, please try again later.' },
});
