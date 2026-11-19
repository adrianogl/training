import Foundation

enum ProvisioningProfile {
    private typealias C = InstallExpiryConstants

    static func expiration(bundle: Bundle = .main) -> Date? {
        guard let url = bundle.url(forResource: C.profileName, withExtension: C.profileExtension),
              let data = try? Data(contentsOf: url) else { return nil }
        return expiration(in: data)
    }

    static func expiration(in data: Data) -> Date? {
        guard let start = data.range(of: Data(C.plistStart.utf8)),
              let end = data.range(of: Data(C.plistEnd.utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any]
        else { return nil }
        return plist[C.expirationKey] as? Date
    }
}
