import '../../../core/errors/provisioning_error.dart';

/// Contract for requesting single-use activation tokens from the cloud backend (Blueprint §2.2 step 7).
abstract interface class TokenService {
  Future<String> requestActivationToken({
    required String userId,
    required String homeId,
    required String deviceId,
  });
}

/// In-memory mock TokenService for Phase 1.
class MockTokenService implements TokenService {
  bool shouldFail;
  String? fixedToken;
  final List<Map<String, String>> recordedRequests = [];

  MockTokenService({
    this.shouldFail = false,
    this.fixedToken,
  });

  @override
  Future<String> requestActivationToken({
    required String userId,
    required String homeId,
    required String deviceId,
  }) async {
    recordedRequests.add({
      'userId': userId,
      'homeId': homeId,
      'deviceId': deviceId,
    });

    if (shouldFail) {
      throw ProvisioningException.tokenRequestFailed();
    }

    if (fixedToken != null) {
      return fixedToken!;
    }

    // Mock signed token bound to user, home, and deviceId
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'tok_${userId}_${homeId}_${deviceId}_$timestamp';
  }
}
