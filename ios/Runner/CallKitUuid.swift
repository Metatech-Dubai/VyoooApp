import Foundation
import CommonCrypto

/// Deterministic UUID for CallKit. Must match `lib/core/utils/call_kit_id.dart`.
enum CallKitUuid {
  private static let namespace = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!

  static func forCallId(_ firestoreCallId: String) -> String {
    let trimmed = firestoreCallId.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return trimmed }
    if let existing = UUID(uuidString: trimmed) {
      return existing.uuidString.lowercased()
    }
    return v5(namespace: namespace, name: "vyooo:\(trimmed)").uuidString.lowercased()
  }

  private static func v5(namespace: UUID, name: String) -> UUID {
    var namespaceBytes = withUnsafeBytes(of: namespace.uuid) { Data($0) }
    let nameBytes = Data(name.utf8)
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
    var ctx = CC_SHA1_CTX()
    CC_SHA1_Init(&ctx)
    _ = namespaceBytes.withUnsafeBytes { CC_SHA1_Update(&ctx, $0.baseAddress, CC_LONG(namespaceBytes.count)) }
    _ = nameBytes.withUnsafeBytes { CC_SHA1_Update(&ctx, $0.baseAddress, CC_LONG(nameBytes.count)) }
    CC_SHA1_Final(&digest, &ctx)

    var bytes = Array(digest.prefix(16))
    bytes[6] = (bytes[6] & 0x0F) | 0x50
    bytes[8] = (bytes[8] & 0x3F) | 0x80

    let tuple: uuid_t = (
      bytes[0], bytes[1], bytes[2], bytes[3],
      bytes[4], bytes[5], bytes[6], bytes[7],
      bytes[8], bytes[9], bytes[10], bytes[11],
      bytes[12], bytes[13], bytes[14], bytes[15]
    )
    return UUID(uuid: tuple)
  }
}
