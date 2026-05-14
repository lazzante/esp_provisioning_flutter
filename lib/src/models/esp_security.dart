/// The security protocol used by ESP-IDF's unified provisioning to establish
/// a session between the mobile client and the ESP32 device.
///
/// These values mirror the security levels defined by Espressif's
/// `wifi_provisioning_manager` component. The numeric ordinal (returned by
/// [protocolVersion]) is what the native ESPProvision (iOS) and
/// `esp-idf-provisioning-android` SDKs expect when constructing a session.
///
/// See the Espressif documentation for protocol details:
/// <https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-reference/provisioning/provisioning.html>
enum EspSecurity {
  /// No encryption. Plaintext provisioning messages.
  ///
  /// **Not recommended for production.** Intended for development and
  /// debugging only — anyone within radio range can observe credentials.
  security0,

  /// X25519 key exchange + AES-CTR-256 encryption with a static
  /// Proof-of-Possession (PoP) string acting as a shared secret.
  ///
  /// Widely deployed in fielded ESP32 products but considered legacy; new
  /// designs should prefer [security2].
  security1,

  /// SRP6a-based authenticated key exchange (username + PoP) with AES-GCM
  /// encryption. The current recommended scheme for production deployments.
  security2;

  /// The integer identifier that ESP-IDF and the native SDKs use to select
  /// this security level on the wire.
  int get protocolVersion {
    switch (this) {
      case EspSecurity.security0:
        return 0;
      case EspSecurity.security1:
        return 1;
      case EspSecurity.security2:
        return 2;
    }
  }

  /// Parses a security level from the protocol version integer used by the
  /// native SDKs. Throws [ArgumentError] if [value] is not a recognised
  /// security level.
  static EspSecurity fromProtocolVersion(int value) {
    switch (value) {
      case 0:
        return EspSecurity.security0;
      case 1:
        return EspSecurity.security1;
      case 2:
        return EspSecurity.security2;
      default:
        throw ArgumentError.value(
          value,
          'value',
          'Unknown ESP security protocol version',
        );
    }
  }
}
