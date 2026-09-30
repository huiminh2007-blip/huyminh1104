import Foundation

// MARK: - Models

struct RemoteAimItem: Identifiable, Hashable {
    /// Folder name on funcition: BODY, NECK, …
    let id: String
    var title: String { id }
}

struct RemoteModCharacter: Identifiable, Hashable {
    let id: String
    let title: String
    let versions: [RemoteModVersion]
}

struct RemoteModVersion: Identifiable, Hashable {
    let id: String
    let title: String
    /// Path under huyminh/ on the funcition repo, e.g. MODS/FFTH/ALOK/V1
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

// MARK: - Service

enum FreeFireRemoteAssetService {
    /// GitHub repo hosting AIM / MODS
    static let owner = "huiminh2007-blip"
    static let repo = "funcition"
    static let branch = "main"
    static let rootPrefix = "huyminh"

    static let aimItems: [RemoteAimItem] = [
        .init(id: "BODY"),
        .init(id: "BỤNG"),
        .init(id: "CHEST"),
        .init(id: "DRAG"),
        .init(id: "MAGIC"),
        .init(id: "NECK"),
    ]

    /// Relative path inside app container (Documents/…)
    static let aimRelativeDir = "Documents/contentcache/compulsory/ios/gameassetbundles"
    static let modRelativeDir = "Documents/contentcache/optional/ios/optionalavatarres/gameassetbundles"

    // MARK: Catalog mods (FFTH = Free Fire, FFM = Free Fire Max)

    static func modCharacters(forPackage package: String) -> [RemoteModCharacter] {
        if package == "com.dts.freefiremax" {
            return loadModCharacters(kind: "FFM")
        }
        // Free Fire TH
        return loadModCharacters(kind: "FFTH")
    }

    /// Static catalog matching current funcition layout (ALOK / IGNIS under FFTH).
    private static func loadModCharacters(kind: String) -> [RemoteModCharacter] {
        if kind == "FFTH" {
            return [
                RemoteModCharacter(
                    id: "ALOK",
                    title: "ALOK",
                    versions: (1...10).map { v in
                        RemoteModVersion(
                            id: "ALOK-V\(v)",
                            title: "V\(v)",
                            remoteDir: "MODS/FFTH/ALOK/V\(v)"
                        )
                    }
                ),
                RemoteModCharacter(
                    id: "IGNIS",
                    title: "IGNIS",
                    versions: (1...3).map { v in
                        RemoteModVersion(
                            id: "IGNIS-V\(v)",
                            title: "V\(v)",
                            remoteDir: "MODS/FFTH/IGNIS/V\(v)"
                        )
                    }
                ),
            ]
        }
        // FFM: empty until user uploads
        return []
    }

    // MARK: Applied state

    private static func defaultsKey(package: String, feature: String) -> String {
        "ff.remote.\(package).\(feature)"
    }

    static func isAimApplied(package: String, item: RemoteAimItem) -> Bool {
        UserDefaults.standard.string(forKey: defaultsKey(package: package, feature: "aim.\(item.id)")) != nil
    }

    static func appliedAimFileName(package: String, item: RemoteAimItem) -> String? {
        UserDefaults.standard.string(forKey: defaultsKey(package: package, feature: "aim.\(item.id)"))
    }

    static func isModVersionApplied(package: String, version: RemoteModVersion) -> Bool {
        UserDefaults.standard.string(forKey: defaultsKey(package: package, feature: "mod.\(version.id)")) != nil
    }

    // MARK: Aim apply / restore

    static func applyAim(package: String, item: RemoteAimItem) throws {
        let remoteDir = "\(rootPrefix)/AIM/\(item.id)"
        let file = try firstRemoteFile(inRepoPath: remoteDir)
        let data = try download(urlString: file.downloadURL)
        let destDir = try containerDir(bundleID: package, relative: aimRelativeDir)
        let dest = destDir.appendingPathComponent(file.name)
        try writeReplacing(data: data, to: dest)
        UserDefaults.standard.set(file.name, forKey: defaultsKey(package: package, feature: "aim.\(item.id)"))
    }

    static func restoreAim(package: String, item: RemoteAimItem) throws {
        let key = defaultsKey(package: package, feature: "aim.\(item.id)")
        let name = UserDefaults.standard.string(forKey: key)
        let destDir = try containerDir(bundleID: package, relative: aimRelativeDir)
        if let name {
            let dest = destDir.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: dest)
        }
        // Also try remove any cache_res* if name unknown
        if let files = try? FileManager.default.contentsOfDirectory(at: destDir, includingPropertiesForKeys: nil) {
            for u in files where u.lastPathComponent.lowercased().hasPrefix("cache_res") {
                // only remove if this aim slot had placed it
                if name == nil || u.lastPathComponent == name {
                    try? FileManager.default.removeItem(at: u)
                }
            }
        }
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: Mod apply / restore

    static func applyMod(package: String, version: RemoteModVersion) throws {
        let remoteDir = "\(rootPrefix)/\(version.remoteDir)"
        let file = try firstRemoteFile(inRepoPath: remoteDir)
        let data = try download(urlString: file.downloadURL)
        let destDir = try containerDir(bundleID: package, relative: modRelativeDir)
        let dest = destDir.appendingPathComponent(file.name)
        try writeReplacing(data: data, to: dest)
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

    private static func firstRemoteFile(inRepoPath path: String) throws -> RemoteFile {
        // path like huyminh/AIM/BODY
        let api = "https://api.github.com/repos/\(owner)/\(repo)/contents/\(path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path)?ref=\(branch)"
        guard let url = URL(string: api) else { throw FreeFireRemoteAssetError.remoteEmpty(path) }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let sem = DispatchSemaphore(value: 0)
        var resultData: Data?
        var resultErr: Error?
        URLSession.shared.dataTask(with: req) { data, _, err in
            resultData = data
            resultErr = err
            sem.signal()
        }.resume()
        _ = sem.wait(timeout: .now() + 30)
        if let resultErr { throw FreeFireRemoteAssetError.downloadFailed(resultErr.localizedDescription) }
        guard let data = resultData,
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw FreeFireRemoteAssetError.remoteEmpty(path)
        }
        let files = arr.compactMap { row -> RemoteFile? in
            guard let type = row["type"] as? String, type == "file",
                  let name = row["name"] as? String,
                  let dl = row["download_url"] as? String else { return nil }
            return RemoteFile(name: name, downloadURL: dl)
        }
        guard let first = files.first else { throw FreeFireRemoteAssetError.remoteEmpty(path) }
        return first
    }

    private static func download(urlString: String) throws -> Data {
        guard let url = URL(string: urlString) else {
            throw FreeFireRemoteAssetError.downloadFailed(urlString)
        }
        let sem = DispatchSemaphore(value: 0)
        var resultData: Data?
        var resultErr: Error?
        URLSession.shared.dataTask(with: url) { data, _, err in
            resultData = data
            resultErr = err
            sem.signal()
        }.resume()
        _ = sem.wait(timeout: .now() + 60)
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
