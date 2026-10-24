import crypto from 'node:crypto';
import { getDatabase } from '../db/database.js';
import { AuditService } from './auditService.js';

export interface OtaJob {
  jobId: string;
  productId: string;
  targetVersion: string;
  firmwareUrl: string;
  sha256: string;
  signature: string;
  allowRollback: boolean;
  createdAt: number;
}

export class OtaService {
  /**
   * Creates a signed firmware update job with cryptographic metadata and rollback flag.
   */
  public static createOtaJob(params: {
    productId: string;
    targetVersion: string;
    firmwareUrl: string;
    sha256: string;
    signature: string;
    allowRollback?: boolean;
    creatorUserId: string;
    userRole: string;
  }): OtaJob {
    if (params.userRole !== 'owner' && params.userRole !== 'admin') {
      throw new Error('Only owners and admins can initiate firmware OTA jobs');
    }

    const jobId = `ota_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;
    const now = Date.now();

    const db = getDatabase();
    db.prepare(`
      INSERT INTO ota_jobs (job_id, product_id, target_version, firmware_url, sha256, signature, allow_rollback, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      jobId,
      params.productId,
      params.targetVersion,
      params.firmwareUrl,
      params.sha256,
      params.signature,
      params.allowRollback ? 1 : 0,
      now
    );

    AuditService.log('CREATE_OTA_JOB', {
      userId: params.creatorUserId,
      details: { jobId, productId: params.productId, version: params.targetVersion },
    });

    return {
      jobId,
      productId: params.productId,
      targetVersion: params.targetVersion,
      firmwareUrl: params.firmwareUrl,
      sha256: params.sha256,
      signature: params.signature,
      allowRollback: !!params.allowRollback,
      createdAt: now,
    };
  }

  /**
   * Retrieves the latest active OTA firmware job for a given device product ID.
   */
  public static getLatestJob(productId: string): OtaJob | null {
    const db = getDatabase();
    const row = db
      .prepare('SELECT * FROM ota_jobs WHERE product_id = ? ORDER BY created_at DESC LIMIT 1')
      .get(productId) as any;

    if (!row) return null;

    return {
      jobId: row.job_id,
      productId: row.product_id,
      targetVersion: row.target_version,
      firmwareUrl: row.firmware_url,
      sha256: row.sha256,
      signature: row.signature,
      allowRollback: row.allow_rollback === 1,
      createdAt: row.created_at,
    };
  }
}
