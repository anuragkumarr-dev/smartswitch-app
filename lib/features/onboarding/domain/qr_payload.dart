import 'package:flutter/foundation.dart';
import '../../../core/errors/provisioning_error.dart';

/// QR payload specification from blueprint §2.1 and §2.2.
/// Format: `SW1:<productId>:<deviceId>:<PoP>`
@immutable
class QrPayload {
  static const String prefix = 'SW1';

  final String productId;
  final String deviceId;
  final String pop;

  const QrPayload({
    required this.productId,
    required this.deviceId,
    required this.pop,
  });

  /// Parses a raw QR code string according to the specification.
  /// Throws [ProvisioningException.invalidQr] if the string is malformed.
  factory QrPayload.parse(String raw) {
    final trimmed = raw.trim();
    final parts = trimmed.split(':');

    if (parts.length != 4) {
      throw ProvisioningException.invalidQr(raw);
    }

    final schema = parts[0];
    final productId = parts[1].trim();
    final deviceId = parts[2].trim();
    final pop = parts[3].trim();

    if (schema != prefix || productId.isEmpty || deviceId.isEmpty || pop.isEmpty) {
      throw ProvisioningException.invalidQr(raw);
    }

    return QrPayload(
      productId: productId,
      deviceId: deviceId,
      pop: pop,
    );
  }

  /// Formats back into the QR string.
  String toQrString() => '$prefix:$productId:$deviceId:$pop';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QrPayload &&
          runtimeType == other.runtimeType &&
          productId == other.productId &&
          deviceId == other.deviceId &&
          pop == other.pop;

  @override
  int get hashCode => Object.hash(productId, deviceId, pop);

  @override
  String toString() => 'QrPayload(productId: $productId, deviceId: $deviceId, pop: [REDACTED])';
}
