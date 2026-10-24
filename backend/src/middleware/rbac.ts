import { Request, Response, NextFunction } from 'express';
import { getDatabase } from '../db/database.js';

export type Role = 'owner' | 'admin' | 'member' | 'guest';

const ROLE_HIERARCHY: Record<Role, number> = {
  owner: 4,
  admin: 3,
  member: 2,
  guest: 1,
};

declare global {
  namespace Express {
    interface Request {
      homeRole?: Role;
    }
  }
}

/**
 * Server-Side Role-Based Access Control (RBAC) Middleware.
 * Enforces home membership and validates that the authenticated user possesses the minimum required role.
 */
export function requireHomeRole(minRole: Role) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const user = req.user;
    if (!user) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    const homeId = req.params.homeId || req.body.homeId || req.query.homeId;
    if (!homeId) {
      res.status(400).json({ error: 'homeId is required for authorization' });
      return;
    }

    const db = getDatabase();
    const membership = db
      .prepare('SELECT role FROM home_members WHERE home_id = ? AND user_id = ?')
      .get(homeId, user.userId) as { role: Role } | undefined;

    if (!membership) {
      res.status(403).json({ error: `User is not a member of home ${homeId}` });
      return;
    }

    const userLevel = ROLE_HIERARCHY[membership.role] ?? 0;
    const requiredLevel = ROLE_HIERARCHY[minRole] ?? 0;

    if (userLevel < requiredLevel) {
      res.status(403).json({
        error: `Insufficient permissions: action requires role ${minRole}, but user has role ${membership.role}`,
      });
      return;
    }

    req.homeRole = membership.role;
    next();
  };
}
