import Foundation
import Security

// MARK: - Firebase configuration

/// Firebase project settings used by the lightweight REST client below.
///
/// `FirebaseAPIKey` is a Firebase client API key (not a database password).
/// Keep Firestore locked down with Security Rules; the API key itself is not a
/// security boundary.
enum FirebaseKeyConfiguration {
    static var projectID: String {
        (Bundle.main.object(forInfoDictionaryKey: "FirebaseProjectID") as? String ?? "quan-li-beu")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var apiKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "FirebaseAPIKey") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var isConfigured: Bool {
        !projectID.isEmpty && !apiKey.isEmpty && apiKey != "PASTE_FIREBASE_WEB_API_KEY_HERE"
    }
}

// MARK: - Keychain storage

private enum LicenseKeychain {
    private static let service = "com.apple.mobile.MobileHouseArrest.license"
    private static let account = "active-key"
    private static let deviceAccount = "installation-id"
    private static let authUIDAccount = "firebase-auth-uid"
    private static let authRefreshTokenAccount = "firebase-refresh-token"

    static func loadActiveKey() -> String? {
        loadString(account: account)
    }

    static func saveActiveKey(_ value: String) throws {
        try saveString(value, account: account)
    }

    static func loadAuthUID() -> String? {
        loadString(account: authUIDAccount)
    }

    static func loadRefreshToken() -> String? {
        loadString(account: authRefreshTokenAccount)
    }

    static func saveAuthSession(uid: String, refreshToken: String) throws {
        try saveString(uid, account: authUIDAccount)
        try saveString(refreshToken, account: authRefreshTokenAccount)
    }

    static func deleteAuthSession() {
        for account in [authUIDAccount, authRefreshTokenAccount] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            SecItemDelete(query as CFDictionary)
        }
    }

    static func deleteActiveKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw LicenseKeyError.keychain(status)
        }
    }

    /// Stable per-installation identifier. It is deliberately kept separate
    /// from AppInfo.machineName, which is a model name rather than a device ID.
    static func installationID() throws -> String {
        if let existing = loadString(account: deviceAccount), !existing.isEmpty {
            return existing
        }

        let value = UUID().uuidString.lowercased()
        try saveString(value, account: deviceAccount)
        return value
    }

    private static func loadString(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func saveString(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw LicenseKeyError.keychain(updateStatus)
        }

        var item = query
        attributes.forEach { item[$0.key] = $0.value }
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
            throw LicenseKeyError.keychain(errSecDuplicateItem)
        }
    }
}

// MARK: - Firebase anonymous auth + Firestore REST

private struct AnonymousAuthResponse: Decodable {
    let idToken: String
    let localId: String
    let refreshToken: String
}

private struct RefreshAuthResponse: Decodable {
    let idToken: String
    let userId: String
    let refreshToken: String
}

private struct FirestoreDocument: Decodable {
    let name: String?
    let fields: [String: FirestoreValue]?
}

private struct FirestoreValue: Decodable {
    let stringValue: String?
    let booleanValue: Bool?
    let integerValue: String?      // Firestore REST returns integers as strings
    let doubleValue: Double?
    let timestampValue: String?
    let nullValue: String?
    let mapValue: FirestoreMapValue?
}

private struct FirestoreMapValue: Decodable {
    let fields: [String: FirestoreValue]?
}

private struct FirestoreErrorResponse: Decodable {
    struct ErrorBody: Decodable {
        let message: String?
    }
    let error: ErrorBody?
}

struct LicenseKeyInfo {
    let key: String
    let allowed: Bool
    let deviceID: String?           // current device (if bound)
    let note: String?
    let boundAt: Date?
    let maxUsers: Int
    let usedUsers: Int
    let expiresAt: Date?
    /// deviceID -> boundAt ISO string (multi-device map)
    let devices: [String: String]
}

enum LicenseKeyError: LocalizedError {
    case invalidKey
    case disabled
    case alreadyBound
    case maxUsersReached
    case expired
    case notConfigured
    case authenticationFailed
    case keychain(OSStatus)
    case network(String)
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "Vui lòng nhập mã Key hợp lệ để đăng nhập vào Menu!"
        case .disabled:
            return "Key đang bị tắt."
        case .alreadyBound:
            return "Key này đã được liên kết với thiết bị khác."
        case .maxUsersReached:
            return "Key đã đạt giới hạn số thiết bị được phép."
        case .expired:
            return "Key đã hết hạn sử dụng."
        case .notConfigured:
            return "Firebase chưa được cấu hình API key."
        case .authenticationFailed:
            return "Không thể xác thực Firebase."
        case .keychain(let status):
            return "Không thể lưu key trên thiết bị (\(status))."
        case .network(let message):
            return "Không thể kết nối Firebase: \(message)"
        case .server(let message):
            return message
        case .invalidResponse:
            return "Firebase trả về dữ liệu không hợp lệ."
        }
    }
}

@MainActor
final class LicenseManager: ObservableObject {
    @Published private(set) var isAuthorized = false
    @Published private(set) var isChecking = false
    @Published private(set) var activeKey = ""
    @Published private(set) var keyInfo: LicenseKeyInfo?
    @Published var errorMessage: String?

    private var authToken = ""
    private var authUID = ""

    init() {
        activeKey = LicenseKeychain.loadActiveKey() ?? ""
    }

    func start() async {
        guard !activeKey.isEmpty else { return }
        await validate(activeKey, saveOnSuccess: false)
    }

    func activate(_ rawKey: String) async {
        await validate(rawKey, saveOnSuccess: true)
    }

    func signOutLocal() {
        isAuthorized = false
        keyInfo = nil
        errorMessage = nil
        activeKey = ""
        authToken = ""
        authUID = ""
        LicenseKeychain.deleteAuthSession()
        try? LicenseKeychain.deleteActiveKey()
    }

    /// Public read-only access to the stable installation UUID (for UI).
    var installationIDDisplay: String {
        (try? LicenseKeychain.installationID()) ?? "—"
    }

    private func validate(_ rawKey: String, saveOnSuccess: Bool) async {
        guard !isChecking else { return }
        let key = normalizeKey(rawKey)
        guard isValidKeyFormat(key) else {
            errorMessage = LicenseKeyError.invalidKey.localizedDescription
            isAuthorized = false
            return
        }

        guard FirebaseKeyConfiguration.isConfigured else {
            errorMessage = LicenseKeyError.notConfigured.localizedDescription
            isAuthorized = false
            return
        }

        isChecking = true
        errorMessage = nil
        defer { isChecking = false }

        do {
            let auth = try await authenticatedSession()
            authToken = auth.idToken
            authUID = auth.localId

            let info = try await fetchKey(key)
            guard info.allowed else { throw LicenseKeyError.disabled }

            // Check expiry
            if let expires = info.expiresAt, expires < Date() {
                throw LicenseKeyError.expired
            }

            let installationID = try LicenseKeychain.installationID()

            // Already bound on this device?
            let alreadyBoundHere = info.devices.keys.contains(installationID)
                || (info.deviceID == installationID)

            if alreadyBoundHere {
                // OK – this device is already registered
            } else {
                // Need to register a new device slot
                let currentUsed = max(info.usedUsers, info.devices.count)
                // Legacy single-device fallback
                let legacyUsed = (info.deviceID?.isEmpty == false && info.devices.isEmpty) ? 1 : 0
                let effectiveUsed = max(currentUsed, legacyUsed)

                if effectiveUsed >= info.maxUsers {
                    throw LicenseKeyError.maxUsersReached
                }

                // Bind this device
                try await bindDevice(
                    key,
                    deviceID: installationID,
                    previousUsed: effectiveUsed,
                    previousDevices: info.devices,
                    legacyDeviceID: info.deviceID
                )
            }

            if saveOnSuccess {
                try LicenseKeychain.saveActiveKey(key)
            }

            activeKey = key
            keyInfo = LicenseKeyInfo(
                key: key,
                allowed: true,
                deviceID: installationID,
                note: info.note,
                boundAt: info.boundAt ?? Date(),
                maxUsers: info.maxUsers,
                usedUsers: alreadyBoundHere ? info.usedUsers : (info.usedUsers + 1),
                expiresAt: info.expiresAt,
                devices: info.devices
            )
            isAuthorized = true
            log("license: key \(key) authorized (device \(installationID.prefix(8))…)")
        } catch {
            isAuthorized = false
            let raw = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = friendlyLoginError(raw)
            log("license: validation failed — \(errorMessage ?? "unknown error")")
        }
    }

    private func friendlyLoginError(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("permission")
            || lower.contains("not found")
            || lower.contains("404")
            || lower.contains("invalid")
            || lower.contains("no document")
            || lower.contains("missing") {
            return LicenseKeyError.invalidKey.localizedDescription
                ?? "Vui lòng nhập mã Key hợp lệ để đăng nhập vào Menu!"
        }
        return raw
    }

    private func normalizeKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private func isValidKeyFormat(_ key: String) -> Bool {
        guard !key.isEmpty, key.count <= 80 else { return false }
        return key.allSatisfy { $0.isNumber || $0.isLetter || $0 == "-" || $0 == "_" }
    }

    private func authenticatedSession() async throws -> AnonymousAuthResponse {
        if let refreshToken = LicenseKeychain.loadRefreshToken(),
           let storedUID = LicenseKeychain.loadAuthUID(),
           !refreshToken.isEmpty,
           !storedUID.isEmpty {
            do {
                let refreshed = try await refreshAnonymousSession(refreshToken: refreshToken)
                try LicenseKeychain.saveAuthSession(uid: refreshed.userId, refreshToken: refreshed.refreshToken)
                return AnonymousAuthResponse(
                    idToken: refreshed.idToken,
                    localId: refreshed.userId,
                    refreshToken: refreshed.refreshToken
                )
            } catch {
                LicenseKeychain.deleteAuthSession()
            }
        }

        guard FirebaseKeyConfiguration.isConfigured,
              let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(FirebaseKeyConfiguration.apiKey)") else {
            throw LicenseKeyError.notConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"returnSecureToken":true}"#.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response, data: data)

        do {
            let auth = try JSONDecoder().decode(AnonymousAuthResponse.self, from: data)
            try LicenseKeychain.saveAuthSession(uid: auth.localId, refreshToken: auth.refreshToken)
            return auth
        } catch {
            throw LicenseKeyError.authenticationFailed
        }
    }

    private func refreshAnonymousSession(refreshToken: String) async throws -> RefreshAuthResponse {
        guard let url = URL(string: "https://securetoken.googleapis.com/v1/token?key=\(FirebaseKeyConfiguration.apiKey)") else {
            throw LicenseKeyError.notConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "grant_type=refresh_token&refresh_token=\(refreshToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? refreshToken)"
        request.httpBody = Data(body.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response, data: data)

        do {
            return try JSONDecoder().decode(RefreshAuthResponse.self, from: data)
        } catch {
            throw LicenseKeyError.authenticationFailed
        }
    }

    private func fetchKey(_ key: String) async throws -> LicenseKeyInfo {
        let document = try await firestoreRequest(
            method: "GET",
            path: "keys/\(escapedDocumentID(key))"
        )

        guard let fields = document.fields else {
            throw LicenseKeyError.invalidKey
        }

        // Parse devices map (preferred multi-device storage)
        var devices: [String: String] = [:]
        if let mapFields = fields["devices"]?.mapValue?.fields {
            for (devId, val) in mapFields {
                if let ts = val.timestampValue {
                    devices[devId] = ts
                } else if let s = val.stringValue {
                    devices[devId] = s
                }
            }
        }

        // Parse numbers (Firestore REST sends integerValue as string)
        func intField(_ name: String, default def: Int) -> Int {
            if let s = fields[name]?.integerValue, let v = Int(s) { return v }
            if let d = fields[name]?.doubleValue { return Int(d) }
            return def
        }

        let maxUsers = max(1, intField("maxUsers", default: 1))
        let usedUsers = max(0, intField("usedUsers", default: 0))

        let expiresAt: Date? = fields["expiresAt"]?.timestampValue.flatMap {
            ISO8601DateFormatter().date(from: $0)
        }

        return LicenseKeyInfo(
            key: key,
            allowed: fields["allowed"]?.booleanValue ?? false,
            deviceID: fields["deviceID"]?.stringValue,
            note: fields["note"]?.stringValue,
            boundAt: fields["boundAt"]?.timestampValue.flatMap { ISO8601DateFormatter().date(from: $0) },
            maxUsers: maxUsers,
            usedUsers: usedUsers,
            expiresAt: expiresAt,
            devices: devices
        )
    }

    /// Register the current device under a multi-user key.
    private func bindDevice(
        _ key: String,
        deviceID: String,
        previousUsed: Int,
        previousDevices: [String: String],
        legacyDeviceID: String?
    ) async throws {
        let documentPath = "keys/\(escapedDocumentID(key))"
        let nowISO = ISO8601DateFormatter().string(from: Date())
        let newUsed = previousUsed + 1

        // Build devices mapValue including all previous + this one
        var deviceFields: [String: Any] = [:]
        for (id, ts) in previousDevices {
            deviceFields[id] = ["timestampValue": ts]
        }
        // Migrate legacy single deviceID if present
        if let legacy = legacyDeviceID, !legacy.isEmpty, previousDevices[legacy] == nil {
            deviceFields[legacy] = ["timestampValue": nowISO]
        }
        deviceFields[deviceID] = ["timestampValue": nowISO]

        var fields: [String: Any] = [
            "devices": [
                "mapValue": [
                    "fields": deviceFields
                ]
            ],
            "usedUsers": ["integerValue": "\(newUsed)"],
            // Keep legacy fields in sync for admin panel compatibility
            "deviceID": ["stringValue": deviceID],
            "boundAt": ["timestampValue": nowISO]
        ]

        let fieldNames = ["devices", "usedUsers", "deviceID", "boundAt"]
        let mask = fieldNames.map {
            "updateMask.fieldPaths=\($0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0)"
        }.joined(separator: "&")

        let body: [String: Any] = [
            "name": "projects/\(FirebaseKeyConfiguration.projectID)/databases/(default)/documents/\(documentPath)",
            "fields": fields
        ]
        _ = try await firestoreRequestRaw(method: "PATCH", path: "\(documentPath)?\(mask)", body: body)
    }

    private func firestoreRequest(method: String, path: String) async throws -> FirestoreDocument {
        let data = try await firestoreRequestRaw(method: method, path: path)
        do {
            return try JSONDecoder().decode(FirestoreDocument.self, from: data)
        } catch {
            throw LicenseKeyError.invalidResponse
        }
    }

    private func firestoreRequestRaw(method: String, path: String, body: [String: Any]? = nil) async throws -> Data {
        guard !authToken.isEmpty,
              let encodedProject = FirebaseKeyConfiguration.projectID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(encodedProject)/databases/(default)/documents/\(path)") else {
            throw LicenseKeyError.notConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response, data: data)
        return data
    }

    private func validateHTTP(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw LicenseKeyError.network("Phản hồi không hợp lệ")
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 404 {
                throw LicenseKeyError.invalidKey
            }
            if let message = try? JSONDecoder().decode(FirestoreErrorResponse.self, from: data).error?.message,
               !message.isEmpty {
                throw LicenseKeyError.server(message)
            }
            throw LicenseKeyError.network("HTTP \(http.statusCode)")
        }
    }

    private func escapedDocumentID(_ key: String) -> String {
        key.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")) ?? key
    }
}
