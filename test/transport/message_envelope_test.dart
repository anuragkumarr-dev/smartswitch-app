import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/transport/models/message_envelope.dart';

void main() {
  group('MessageEnvelope serialization and validation', () {
    test('serializes and deserializes command envelope to JSON correctly', () {
      final envelope = MessageEnvelope.cmd(
        deviceId: 'dev_hall',
        commandId: 'cmd_123',
        desired: {'gang1': {'on': true}},
        ts: 1729683920000,
      );

      final json = envelope.toJson();
      expect(json['v'], 1);
      expect(json['type'], 'cmd');
      expect(json['deviceId'], 'dev_hall');
      expect(json['commandId'], 'cmd_123');
      expect(json['desired']['gang1']['on'], isTrue);
      expect(json['ts'], 1729683920000);

      final fromJson = MessageEnvelope.fromJson(json);
      expect(fromJson, equals(envelope));
    });

    test('serializes and deserializes ACK and state envelopes', () {
      final ack = MessageEnvelope.ack(
        deviceId: 'dev_hall',
        commandId: 'cmd_123',
        reported: {'gang1': {'on': true}},
        ver: 42,
        ts: 1729683920050,
      );

      final jsonString = ack.toJsonString();
      final fromString = MessageEnvelope.fromJsonString(jsonString);
      expect(fromString.type, 'ack');
      expect(fromString.ver, 42);
      expect(fromString.reported?['gang1']?['on'], isTrue);
    });

    test('validates 30-second command expiry rule (Blueprint §3.3)', () {
      final now = 1729683950000;

      // Command originated 5 seconds ago -> not expired
      final recentCmd = MessageEnvelope.cmd(
        deviceId: 'dev_1',
        commandId: 'c_recent',
        desired: {'on': true},
        ts: now - 5000,
      );
      expect(recentCmd.isExpired(currentTimestamp: now), isFalse);

      // Command originated 35 seconds ago -> EXPIRED (>30s)
      final staleCmd = MessageEnvelope.cmd(
        deviceId: 'dev_1',
        commandId: 'c_stale',
        desired: {'on': true},
        ts: now - 35000,
      );
      expect(staleCmd.isExpired(currentTimestamp: now), isTrue);
    });
  });
}
