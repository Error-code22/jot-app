import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import 'app_settings.dart';

/// Wraps biometric / device-credential authentication.
class BiometricService {
  final LocalAuthentication _auth;
  final AppSettings _settings;

  BiometricService({LocalAuthentication? auth, required AppSettings settings})
      : _auth = auth ?? LocalAuthentication(),
        _settings = settings;

  /// True when the platform can authenticate, regardless of the user setting.
  /// Used by Settings before enabling the feature.
  Future<bool> get canUseDeviceAuth async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final biometrics = await _auth.getAvailableBiometrics();
      // Windows Hello can be available without exposing biometric types.
      return biometrics.isNotEmpty || await _auth.canCheckBiometrics;
    } catch (e) {
      debugPrint('Biometric availability check failed: $e');
      return false;
    }
  }

  /// True when the platform can authenticate and the user has not disabled it.
  Future<bool> get isAvailable async {
    if (!_settings.biometricUnlock) return false;
    return canUseDeviceAuth;
  }

  Future<bool> authenticate({String reason = 'Unlock this note'}) async {
    if (!_settings.biometricUnlock) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugPrint('Biometric authentication failed: $e');
      return false;
    }
  }
}
