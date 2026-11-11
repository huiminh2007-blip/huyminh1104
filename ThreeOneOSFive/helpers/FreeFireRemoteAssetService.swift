import Foundation
import CryptoKit

// MARK: - Models

struct RemoteMenuItem: Identifiable, Hashable {
    let id: String
    let title: String
    let remoteDir: String
}

struct RemoteOtherItem: Identifiable, Hashable {
    let id: String
    let title: String
    let remoteDir: String
}

struct RemoteModCharacter: Identifiable, Hashable {
    let id: String
    let title: String
    let versions: [RemoteModVersion]
}

struct RemoteModVersion: Identifiable, Hashable {
    let id: String
    let title: String
    let remoteDir: String
}

enum FreeFireRemoteAssetError: LocalizedError {
    case containerUnavailable(String)
    case remoteEmpty(String)
    case downloadFailed(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .containerUnavailable(let id): return "Không tìm thấy container \(id)"
        case .remoteEmpty(let p): return "Không có file trên repo: \(p)"
        case .downloadFailed(let m): return "Tải file thất bại: \(m)"
        case .writeFailed(let m): return "Ghi file thất bại: \(m)"
        }
    }
}

enum FreeFireRemoteAssetService {
    static let owner = "huiminh2007-blip"
    static let repo = "funcition"
    static let branch = "main"
        static let rootPrefix = ""  // repo root: AIM/, MENU/, MODS/ (no huyminh/ wrapper)

    /// Build GitHub contents path. Repo has AIM/, MENU/, MODS/ at root.
    private static func repoPath(_ relative: String) -> String {
        let rel = relative.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if rootPrefix.isEmpty { return rel }
        return "\(rootPrefix)/\(rel)"
    }


    static let modRelativeDir = "Documents/contentcache/Optional/ios/optionalavatarres/gameassetbundles"
    static let menuRelativeDir = "Documents"
    static let otherRelativeDir = "Documents"
    private static let mizoraFiles = ["Assembly-CSharp-patch.bytes", "localConfig.json"]

    static func menuItems(forPackage package: String) -> [RemoteMenuItem] {
        guard package == "com.dts.freefireth" else { return [] }
        return [RemoteMenuItem(id: "FFTH-MIZORA", title: "Mizora", remoteDir: "MENU/FFTH/Mizora")]
    }

    // MARK: Other

    static func otherItems(forPackage package: String) -> [RemoteOtherItem] {
        let side = (package == "com.dts.freefiremax") ? "FFM" : "FFTH"
        return [
            RemoteOtherItem(
                id: "\(side)-RESET-GUEST",
                title: "Reset tài khoản khách",
                remoteDir: "OTHER/\(side)"
            )
        ]
    }

    /// Downloads the latest file from OTHER/<FFM|FFTH> into the game's Documents,
    /// opens the game, then removes the temporary file 15 seconds later.
    static func resetGuestAccount(package: String, item: RemoteOtherItem) throws {
        let remoteDir = repoPath(item.remoteDir)
        let file = try lastRemoteAssetFile(inRepoPath: remoteDir)
        let data = try download(urlString: file.downloadURL)
        let destDir = try containerDir(bundleID: package, relative: otherRelativeDir)
        let destination = destDir.appendingPathComponent(file.name)

        try writeReplacing(data: data, to: destination)

        guard openApplicationForBundleID(package) else {
            try? FileManager.default.removeItem(at: destination)
            throw FreeFireRemoteAssetError.writeFailed("Không thể mở ứng dụng \(package)")
        }

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 15) {
            try? FileManager.default.removeItem(at: destination)
        }
    }

    // MARK: Mods

    static func modCharacters(forPackage package: String) -> [RemoteModCharacter] {
        if package == "com.dts.freefiremax" {
            return loadModCharacters(kind: "FFM")
        }
        return loadModCharacters(kind: "FFTH")
    }

    private static func loadModCharacters(kind: String) -> [RemoteModCharacter] {
        if kind == "FFM" {
            return [
                RemoteModCharacter(
                    id: "ALOK",
                    title: "ALOK",
                    versions: (1...6).map { v in
                        RemoteModVersion(
                            id: "FFM-ALOK-V\(v)",
                            title: "V\(v)",
                            remoteDir: "MODS/FFM/ALOK/V\(v)"
                        )
                    }
                ),
            ]
        }
        if kind == "FFTH" {
            return [
                RemoteModCharacter(
                    id: "ALOK",
                    title: "ALOK",
                    versions: (1...15).map { v in
                        RemoteModVersion(id: "ALOK-V\(v)", title: "V\(v)", remoteDir: "MODS/FFTH/ALOK/V\(v)")
                    }
                ),
                RemoteModCharacter(
                    id: "IGNIS",
                    title: "IGNIS",
                    versions: (1...3).map { v in
                        RemoteModVersion(id: "IGNIS-V\(v)", title: "V\(v)", remoteDir: "MODS/FFTH/IGNIS/V\(v)")
                    }
                ),
            ]
        }
        return []
    }

    // MARK: Applied state

    private static func defaultsKey(package: String, feature: String) -> String {
        "ff.remote.\(package).\(feature)"
    }

    static func isMenuApplied(package: String, item: RemoteMenuItem) -> Bool {
        UserDefaults.standard.stringArray(forKey: defaultsKey(package: package, feature: "menu.\(item.id)")) != nil
    }

    static func isModVersionApplied(package: String, version: RemoteModVersion) -> Bool {
        UserDefaults.standard.string(forKey: defaultsKey(package: package, feature: "mod.\(version.id)")) != nil
    }

    // MARK: Menu apply / restore

    static func applyMenu(package: String, item: RemoteMenuItem) throws {
        guard menuItems(forPackage: package).contains(item) else {
            throw FreeFireRemoteAssetError.remoteEmpty("Mizora chưa hỗ trợ bản game này")
        }
        let files = try listRemoteFiles(inRepoPath: repoPath(item.remoteDir))
        guard let manifestFile = files.first(where: { $0.name == "manifest.json" }),
              let manifest = try JSONSerialization.jsonObject(with: download(urlString: manifestFile.downloadURL)) as? [String: Any],
              manifest["targetPackage"] as? String == package,
              let hashes = manifest["files"] as? [String: String],
              Set(hashes.keys) == Set(mizoraFiles) else {
            throw FreeFireRemoteAssetError.downloadFailed("Manifest Mizora không hợp lệ")
        }
        // Fetch and validate the entire pair before touching the destination.
        var payload: [String: Data] = [:]
        for name in mizoraFiles {
            guard let file = files.first(where: { $0.name == name }) else {
                throw FreeFireRemoteAssetError.remoteEmpty(name)
            }
            let data = try download(urlString: file.downloadURL)
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard digest == hashes[name]?.lowercased() else {
                throw FreeFireRemoteAssetError.downloadFailed("Checksum không khớp: \(name)")
            }
            if name == "localConfig.json" {
                guard (try JSONSerialization.jsonObject(with: data)) is [String: Any] else {
                    throw FreeFireRemoteAssetError.downloadFailed("localConfig.json không hợp lệ")
                }
            } else {
                guard Array(data.prefix(8)) == [0xcb, 0xa2, 0xb4, 0x0d, 0xb2, 0x19, 0xa3, 0x66] else {
                    throw FreeFireRemoteAssetError.downloadFailed("Assembly không phải IFix payload hợp lệ")
                }
            }
            payload[name] = data
        }
        let destDir = try containerDir(bundleID: package, relative: menuRelativeDir)
        let stateKey = defaultsKey(package: package, feature: "menu.\(item.id)")
        let fm = FileManager.default
        var originals: [String: Data] = [:]
        for name in mizoraFiles {
            let url = destDir.appendingPathComponent(name)
            if fm.fileExists(atPath: url.path) { originals[name] = try Data(contentsOf: url) }
        }
        // A receipt also makes an interrupted installation removable on restart.
        UserDefaults.standard.set(mizoraFiles, forKey: stateKey)
        do {
            for name in mizoraFiles { try payload[name]!.write(to: destDir.appendingPathComponent(name), options: .atomic) }
        } catch {
            var rollbackFailed = false
            for name in mizoraFiles {
                let url = destDir.appendingPathComponent(name)
                do {
                    if let data = originals[name] { try data.write(to: url, options: .atomic) }
                    else if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
                } catch { rollbackFailed = true }
            }
            if !rollbackFailed { UserDefaults.standard.removeObject(forKey: stateKey) }
            throw FreeFireRemoteAssetError.writeFailed(rollbackFailed ? "Cài chưa hoàn tất. Tắt Mizora để dọn hai file." : error.localizedDescription)
        }
    }

    static func restoreMenu(package: String, item: RemoteMenuItem) throws {
        guard menuItems(forPackage: package).contains(item) else { throw FreeFireRemoteAssetError.writeFailed("Mục menu không hợp lệ") }
        let key = defaultsKey(package: package, feature: "menu.\(item.id)")
        guard let names = UserDefaults.standard.stringArray(forKey: key) else { return }
        guard Set(names) == Set(mizoraFiles) else { throw FreeFireRemoteAssetError.writeFailed("Biên nhận Mizora không hợp lệ") }
        let destDir = try containerDir(bundleID: package, relative: menuRelativeDir)
        // No download or directory-wide deletion when switching off.
        for name in mizoraFiles {
            let url = destDir.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        }
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: Mod apply / restore

    static func applyMod(package: String, version: RemoteModVersion) throws {
        let remoteDir = repoPath(version.remoteDir)
        let file = try firstRemoteFile(inRepoPath: remoteDir)
        let data = try download(urlString: file.downloadURL)
        let destDir = try containerDir(bundleID: package, relative: modRelativeDir)
        try writeReplacing(data: data, to: destDir.appendingPathComponent(file.name))
        UserDefaults.standard.set(file.name, forKey: defaultsKey(package: package, feature: "mod.\(version.id)"))
    }

    static func restoreMod(package: String, version: RemoteModVersion) throws {
        let key = defaultsKey(package: package, feature: "mod.\(version.id)")
        if let name = UserDefaults.standard.string(forKey: key) {
            let destDir = try containerDir(bundleID: package, relative: modRelativeDir)
            try? FileManager.default.removeItem(at: destDir.appendingPathComponent(name))
        }
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: GitHub + IO

    private struct RemoteFile {
        let name: String
        let downloadURL: String
    }

    /// Xóa toàn bộ thư mục mod avatar (giống beu1411): Documents/contentcache/optional|Optional
    @discardableResult
    static func clearAllMods(package: String) throws -> Bool {
        guard let root = ContainerStore.resolveAppContainerPath(bundleID: package),
              ContainerStore.isApplicationContainerPath(root) else {
            throw FreeFireRemoteAssetError.containerUnavailable(package)
        }
        let docs = URL(fileURLWithPath: root, isDirectory: true)
            .appendingPathComponent("Documents", isDirectory: true)
        let fm = FileManager.default
        let relativePaths = ["contentcache/optional", "contentcache/Optional"]
        var anyDeleted = false
        for relative in relativePaths {
            let path = docs.appendingPathComponent(relative, isDirectory: true)
            if fm.fileExists(atPath: path.path) {
                try? fm.removeItem(at: path)
                if !fm.fileExists(atPath: path.path) { anyDeleted = true }
            }
        }
        let prefix = "ff.remote.\(package).mod."
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            UserDefaults.standard.removeObject(forKey: key)
        }
        return anyDeleted
    }

    private static func listRemoteFiles(inRepoPath path: String) throws -> [RemoteFile] {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let api = "https://api.github.com/repos/\(owner)/\(repo)/contents/\(encoded)?ref=\(branch)"
        guard let url = URL(string: api) else { throw FreeFireRemoteAssetError.remoteEmpty(path) }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let data = try syncData(from: req)
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw FreeFireRemoteAssetError.remoteEmpty(path)
        }
        return arr.compactMap { row in
            guard let type = row["type"] as? String, type == "file",
                  let name = row["name"] as? String,
                  let dl = row["download_url"] as? String else { return nil }
            return RemoteFile(name: name, downloadURL: dl)
        }
    }

    private static func lastRemoteAssetFile(inRepoPath path: String) throws -> RemoteFile {
        let files = try listRemoteFiles(inRepoPath: path)
            .filter { file in
                let lowercased = file.name.lowercased()
                return !file.name.hasPrefix(".") && lowercased != ".gitkeep"
            }
        guard let last = files.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }).last else {
            throw FreeFireRemoteAssetError.remoteEmpty(path)
        }
        return last
    }

    private static func firstRemoteFile(inRepoPath path: String) throws -> RemoteFile {
        let files = try listRemoteFiles(inRepoPath: path)
            .filter { file in
                let lowercased = file.name.lowercased()
                return !file.name.hasPrefix(".") && lowercased != ".gitkeep"
            }
        guard let first = files.first else { throw FreeFireRemoteAssetError.remoteEmpty(path) }
        return first
    }

    private static func download(urlString: String) throws -> Data {
        guard let url = URL(string: urlString) else {
            throw FreeFireRemoteAssetError.downloadFailed(urlString)
        }
        return try syncData(from: URLRequest(url: url), timeout: 60)
    }

    private static func syncData(from request: URLRequest, timeout: TimeInterval = 30) throws -> Data {
        let sem = DispatchSemaphore(value: 0)
        var resultData: Data?
        var resultErr: Error?
        URLSession.shared.dataTask(with: request) { data, _, err in
            resultData = data
            resultErr = err
            sem.signal()
        }.resume()
        _ = sem.wait(timeout: .now() + timeout)
        if let resultErr { throw FreeFireRemoteAssetError.downloadFailed(resultErr.localizedDescription) }
        guard let data = resultData, !data.isEmpty else {
            throw FreeFireRemoteAssetError.downloadFailed("empty body")
        }
        return data
    }

    private static func containerDir(bundleID: String, relative: String) throws -> URL {
        guard let root = ContainerStore.resolveAppContainerPath(bundleID: bundleID),
              ContainerStore.isApplicationContainerPath(root) else {
            throw FreeFireRemoteAssetError.containerUnavailable(bundleID)
        }
        let dir = URL(fileURLWithPath: root, isDirectory: true)
            .appendingPathComponent(relative, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func writeReplacing(data: Data, to dest: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        do {
            try data.write(to: dest, options: .atomic)
        } catch {
            throw FreeFireRemoteAssetError.writeFailed(error.localizedDescription)
        }
    }
}
