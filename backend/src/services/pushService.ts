export interface PushNotificationPayload {
  targetUserId: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

export interface PushNotificationResult {
  success: boolean;
  messageId: string;
  timestamp: number;
}

export interface PushSender {
  send(payload: PushNotificationPayload): Promise<PushNotificationResult>;
}

/**
 * Fake Push Notification Sender for local development & automated testing.
 * Intercepts notifications without requiring real APNs or Firebase credentials.
 */
export class FakePushSender implements PushSender {
  private static sentMessages: Array<PushNotificationPayload & { timestamp: number; messageId: string }> = [];

  public async send(payload: PushNotificationPayload): Promise<PushNotificationResult> {
    const messageId = `push_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    const timestamp = Date.now();

    FakePushSender.sentMessages.push({
      ...payload,
      timestamp,
      messageId,
    });

    return {
      success: true,
      messageId,
      timestamp,
    };
  }

  public static getSentMessages(): Array<PushNotificationPayload & { timestamp: number; messageId: string }> {
    return [...this.sentMessages];
  }

  public static clearSentMessages(): void {
    this.sentMessages = [];
  }
}
