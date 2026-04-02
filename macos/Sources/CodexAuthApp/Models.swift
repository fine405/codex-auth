import Foundation

// MARK: - Registry JSON Schema (matches ~/.codex/accounts/registry.json)

struct RegistryData: Codable {
    var schemaVersion: Int
    var activeAccountKey: String?
    var activeAccountActivatedAtMs: Int64?
    var autoSwitch: AutoSwitchConfig
    var api: ApiConfig
    var accounts: [AccountRecord]

    init() {
        schemaVersion = 3; activeAccountKey = nil; activeAccountActivatedAtMs = nil
        autoSwitch = AutoSwitchConfig(); api = ApiConfig(); accounts = []
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = (try? c.decode(Int.self, forKey: .schemaVersion)) ?? 3
        activeAccountKey = try? c.decode(String.self, forKey: .activeAccountKey)
        activeAccountActivatedAtMs = try? c.decode(Int64.self, forKey: .activeAccountActivatedAtMs)
        autoSwitch = (try? c.decode(AutoSwitchConfig.self, forKey: .autoSwitch)) ?? AutoSwitchConfig()
        api = (try? c.decode(ApiConfig.self, forKey: .api)) ?? ApiConfig()
        accounts = (try? c.decode([AccountRecord].self, forKey: .accounts)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, activeAccountKey, activeAccountActivatedAtMs
        case autoSwitch, api, accounts
    }
}

struct AutoSwitchConfig: Codable {
    var enabled: Bool = false
    var threshold5hPercent: Int = 10
    var thresholdWeeklyPercent: Int = 5

    // CodingKeys needed because "threshold_5h_percent" doesn't round-trip with automatic snake_case
    private enum CodingKeys: String, CodingKey {
        case enabled
        case threshold5hPercent = "threshold_5h_percent"
        case thresholdWeeklyPercent = "threshold_weekly_percent"
    }
}

struct ApiConfig: Codable {
    var usage: Bool = true
    var account: Bool = true
}

struct RateLimitWindow: Codable {
    var usedPercent: Double = 0
    var windowMinutes: Int64?
    var resetsAt: Int64?
}

struct RateLimitSnapshot: Codable {
    var primary: RateLimitWindow?
    var secondary: RateLimitWindow?
    var planType: String?
}

struct RolloutSignature: Codable {
    var path: String
    var eventTimestampMs: Int64
}

struct AccountRecord: Codable {
    var accountKey: String
    var chatgptAccountId: String = ""
    var chatgptUserId: String = ""
    var email: String
    var alias: String = ""
    var accountName: String?
    var plan: String?
    var authMode: String?
    var createdAt: Int64 = 0
    var lastUsedAt: Int64?
    var lastUsage: RateLimitSnapshot?
    var lastUsageAt: Int64?
    var lastLocalRollout: RolloutSignature?
}

// MARK: - View Model Data

struct AccountInfo: Identifiable {
    var id: String { accountKey }
    let accountKey: String
    let email: String
    let alias: String
    let accountName: String?
    let plan: String?
    let isActive: Bool
    let usage5hRemaining: Int?
    let usageWeeklyRemaining: Int?

    var displayName: String {
        if !alias.isEmpty { return "\(email) (\(alias))" }
        if let name = accountName, !name.isEmpty { return "\(email) (\(name))" }
        return email
    }
}

// MARK: - Helpers

func resolveWindow(_ snapshot: RateLimitSnapshot, minutes: Int64, fallbackPrimary: Bool) -> RateLimitWindow? {
    if let p = snapshot.primary, p.windowMinutes == minutes { return p }
    if let s = snapshot.secondary, s.windowMinutes == minutes { return s }
    return fallbackPrimary ? snapshot.primary : snapshot.secondary
}

func remainingPercent(_ window: RateLimitWindow) -> Int {
    let now = Int64(Date().timeIntervalSince1970)
    if let r = window.resetsAt, now >= r { return 100 }
    let rem = 100.0 - window.usedPercent
    return max(0, min(100, Int(rem)))
}

func makeAccountInfo(_ rec: AccountRecord, activeKey: String?) -> AccountInfo {
    let isActive = activeKey == rec.accountKey
    let plan = rec.plan ?? rec.lastUsage?.planType

    let u5h = rec.lastUsage.flatMap { resolveWindow($0, minutes: 300, fallbackPrimary: true) }
    let uwk = rec.lastUsage.flatMap { resolveWindow($0, minutes: 10080, fallbackPrimary: false) }

    return AccountInfo(
        accountKey: rec.accountKey, email: rec.email, alias: rec.alias,
        accountName: rec.accountName, plan: plan, isActive: isActive,
        usage5hRemaining: u5h.map { remainingPercent($0) },
        usageWeeklyRemaining: uwk.map { remainingPercent($0) }
    )
}

// MARK: - File key encoding (matches Zig's accountFileKey logic)

func accountFileKey(_ key: String) -> String {
    func needsEncoding(_ k: String) -> Bool {
        if k.isEmpty || k == "." || k == ".." { return true }
        return k.unicodeScalars.contains { c in
            !(c >= "a" && c <= "z") && !(c >= "A" && c <= "Z") &&
            !(c >= "0" && c <= "9") && c != "-" && c != "_" && c != "."
        }
    }
    if needsEncoding(key) {
        // base64url-no-pad encoding
        return Data(key.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }
    return key
}
