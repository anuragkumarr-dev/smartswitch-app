import { Router, Request, Response } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { requireHomeRole } from '../middleware/rbac.js';
import { tokenRateLimiter, inviteRateLimiter } from '../middleware/rateLimiter.js';
import { TokenService } from '../services/tokenService.js';
import { RegistryService } from '../services/registryService.js';
import { HomeKeyService } from '../services/homeKeyService.js';
import { InviteService } from '../services/inviteService.js';
import { ShadowService } from '../services/shadowService.js';
import { OtaService } from '../services/otaService.js';
import { FakePushSender } from '../services/pushService.js';
import { AuditService } from '../services/auditService.js';
import { getDatabase } from '../db/database.js';

export const apiRouter = Router();

function paramStr(val: string | string[] | undefined): string {
  if (Array.isArray(val)) return val[0] || '';
  return val || '';
}

// =============================================================================
// Homes & Memberships
// =============================================================================

/**
 * GET /homes - Returns homes for the authenticated user (matches Flutter ApiClient)
 */
apiRouter.get('/homes', authMiddleware, (req: Request, res: Response) => {
  const db = getDatabase();
  const homes = db
    .prepare(`
      SELECT h.home_id, h.name, h.timezone, h.mesh_id, h.mesh_ap_password, h.key_id, m.role
      FROM homes h
      JOIN home_members m ON h.home_id = m.home_id
      WHERE m.user_id = ?
    `)
    .all(req.user!.userId) as any[];

  res.json(
    homes.map((h) => ({
      homeId: h.home_id,
      name: h.name,
      timezone: h.timezone,
      meshId: h.mesh_id,
      meshApPassword: h.mesh_ap_password,
      keyId: h.key_id,
      role: h.role,
    }))
  );
});

/**
 * GET /homes/:homeId/devices - Returns devices snapshot with ver and shadow
 */
apiRouter.get(
  '/homes/:homeId/devices',
  authMiddleware,
  requireHomeRole('guest'),
  (req: Request, res: Response) => {
    const homeId = paramStr(req.params.homeId);
    const devices = ShadowService.getHomeSnapshot(homeId);
    res.json(devices);
  }
);

// =============================================================================
// Activation Tokens (Service 1)
// =============================================================================

/**
 * POST /activation/tokens - Issues a single-use signed activation token
 * Bound to userId, homeId, deviceId. 10m expiry. Admin or Owner role required.
 */
apiRouter.post(
  '/activation/tokens',
  authMiddleware,
  tokenRateLimiter,
  requireHomeRole('admin'),
  (req: Request, res: Response) => {
    try {
      const { deviceId, homeId } = req.body;
      if (!deviceId || !homeId) {
        res.status(400).json({ error: 'deviceId and homeId are required' });
        return;
      }

      const signedToken = TokenService.issueToken(req.user!.userId, homeId, deviceId);
      res.status(201).json(signedToken);
    } catch (err: any) {
      res.status(400).json({ error: err.message });
    }
  }
);

/**
 * POST /activation/consume - Consumes token and binds device (Device cloud onboarding)
 */
apiRouter.post('/activation/consume', (req: Request, res: Response) => {
  try {
    const { token, deviceId, homeId, name, roomId, isRoot } = req.body;
    if (!token || !deviceId || !homeId) {
      res.status(400).json({ error: 'token, deviceId, and homeId are required' });
      return;
    }

    // Verify and consume token, bind device in registry
    const device = RegistryService.bindDevice({
      deviceId,
      homeId,
      userId: 'device_activation_service',
      token,
      name,
      roomId,
      isRoot,
    });

    res.status(200).json({
      success: true,
      message: 'Device successfully bound to home',
      device,
    });
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});

// =============================================================================
// Device Registry & Unbind (Service 2)
// =============================================================================

/**
 * DELETE /homes/:homeId/devices/:deviceId - Owner-confirmed unbind and release
 */
apiRouter.delete(
  '/homes/:homeId/devices/:deviceId',
  authMiddleware,
  requireHomeRole('admin'),
  (req: Request, res: Response) => {
    try {
      const deviceId = paramStr(req.params.deviceId);
      const homeId = paramStr(req.params.homeId);

      RegistryService.unbindDevice({
        deviceId,
        homeId,
        requesterUserId: req.user!.userId,
        requesterRole: req.homeRole!,
      });

      res.json({ success: true, message: `Device ${deviceId} released to unclaimed state` });
    } catch (err: any) {
      res.status(400).json({ error: err.message });
    }
  }
);

// =============================================================================
// Home Key Service & Rotation (Service 4)
// =============================================================================

/**
 * POST /homes/:homeId/key/rotate - Rotates home key and increments key_id (Owner only)
 */
apiRouter.post(
  '/homes/:homeId/key/rotate',
  authMiddleware,
  requireHomeRole('owner'),
  (req: Request, res: Response) => {
    try {
      const homeId = paramStr(req.params.homeId);
      const updatedHome = HomeKeyService.rotateHomeKey(
        homeId,
        req.user!.userId,
        req.homeRole!
      );

      res.json({
        success: true,
        homeId: updatedHome.homeId,
        keyId: updatedHome.keyId,
        rotatedAt: Date.now(),
      });
    } catch (err: any) {
      res.status(400).json({ error: err.message });
    }
  }
);

/**
 * POST /homes/:homeId/key/wrapped - Returns wrapped home key for device or app
 */
apiRouter.post(
  '/homes/:homeId/key/wrapped',
  authMiddleware,
  requireHomeRole('member'),
  (req: Request, res: Response) => {
    try {
      const homeId = paramStr(req.params.homeId);
      const { wrappingKeyHex } = req.body;
      if (!wrappingKeyHex) {
        res.status(400).json({ error: 'wrappingKeyHex is required' });
        return;
      }

      const result = HomeKeyService.getWrappedKey(homeId, wrappingKeyHex);
      res.json(result);
    } catch (err: any) {
      res.status(400).json({ error: err.message });
    }
  }
);

// =============================================================================
// Invites (Service 3)
// =============================================================================

/**
 * POST /homes/:homeId/invites - Creates a single-use expiring invite (Admin or Owner)
 */
apiRouter.post(
  '/homes/:homeId/invites',
  authMiddleware,
  inviteRateLimiter,
  requireHomeRole('admin'),
  (req: Request, res: Response) => {
    try {
      const homeId = paramStr(req.params.homeId);
      const { role, durationMs } = req.body;
      const invite = InviteService.createInvite({
        homeId,
        invitedBy: req.user!.userId,
        requesterRole: req.homeRole!,
        role: role ?? 'member',
        durationMs,
      });

      res.status(201).json(invite);
    } catch (err: any) {
      res.status(400).json({ error: err.message });
    }
  }
);

/**
 * POST /invites/:inviteId/accept - Accepts and redeems single-use invite
 */
apiRouter.post('/invites/:inviteId/accept', authMiddleware, (req: Request, res: Response) => {
  try {
    const inviteId = paramStr(req.params.inviteId);
    const result = InviteService.acceptInvite(inviteId, req.user!.userId);
    res.json({
      success: true,
      message: `Accepted invite, joined home ${result.homeId} as ${result.role}`,
      membership: result,
    });
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});

// =============================================================================
// OTA Firmware & Push (Service 7)
// =============================================================================

/**
 * POST /ota/jobs - Creates signed firmware OTA job
 */
apiRouter.post('/ota/jobs', authMiddleware, (req: Request, res: Response) => {
  try {
    const { productId, targetVersion, firmwareUrl, sha256, signature, allowRollback, homeId } = req.body;

    const db = getDatabase();
    const membership = db
      .prepare('SELECT role FROM home_members WHERE home_id = ? AND user_id = ?')
      .get(homeId, req.user!.userId) as { role: string } | undefined;

    const userRole = membership?.role ?? 'member';

    const job = OtaService.createOtaJob({
      productId,
      targetVersion,
      firmwareUrl,
      sha256,
      signature,
      allowRollback,
      creatorUserId: req.user!.userId,
      userRole,
    });

    res.status(201).json(job);
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});

/**
 * GET /ota/jobs/:productId/latest - Returns latest OTA update
 */
apiRouter.get('/ota/jobs/:productId/latest', (req: Request, res: Response) => {
  const productId = paramStr(req.params.productId);
  const job = OtaService.getLatestJob(productId);
  if (!job) {
    res.status(404).json({ error: 'No firmware job found for this product' });
    return;
  }
  res.json(job);
});

/**
 * POST /push/send - Fake push notification sender test endpoint
 */
apiRouter.post('/push/send', authMiddleware, async (req: Request, res: Response) => {
  const { title, body, data } = req.body;
  const pushSender = new FakePushSender();
  const result = await pushSender.send({
    targetUserId: req.user!.userId,
    title,
    body,
    data,
  });
  res.json(result);
});

// =============================================================================
// Audit Logs (Service 8)
// =============================================================================

/**
 * GET /homes/:homeId/audit - View security audit log (Admin or Owner)
 */
apiRouter.get(
  '/homes/:homeId/audit',
  authMiddleware,
  requireHomeRole('admin'),
  (req: Request, res: Response) => {
    const homeId = paramStr(req.params.homeId);
    const logs = AuditService.getLogs(homeId);
    res.json(logs);
  }
);
