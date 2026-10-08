import Foundation

// MARK: - Models

struct RemoteAimItem: Identifiable, Hashable {
    let id: String
    let title: String
    /// Path under funcition repo, e.g. AIM/FFTH/AIM HEAD
    let remoteDir: String
}

struct RemoteChamsItem: Identifiable, Hashable {
    let id: String
    let title: String
    let remoteDir: String
}

struct RemoteMenuItem: Identifiable, Hashable {
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


    /// Aim destination inside game container (FF + Max cùng relative path)
    static let aimRelativeDir = "Documents/contentcache/Compulsory/ios/gameassetbundles/avatar"
    /// Chams shader destination for both Free Fire and Free Fire Max.
    static let chamsRelativeDir = "Documents/contentcache/Optional/ios/gameassetbundles"
    static let modRelativeDir = "Documents/contentcache/optional/ios/optionalavatarres/gameassetbundles"
    static let menuRelativeDir = "Documents"

    private static let aimFolderNames: [String] = [
        "AIM HEAD + ANTENA",
        "AIM BỤNG",
        "AIM NECK",
        "MAGIC",
        "AIM DỊ TẬT",
        "AIM CHEST",
        "AIM DRAG",
        "AIM HEAD",
    ]

    // MARK: Aim — FFTH = Free Fire, FFM = Free Fire Max

    static func aimItems(forPackage package: String) -> [RemoteAimItem] {
        let side = (package == "com.dts.freefiremax") ? "FFM" : "FFTH"
        return aimFolderNames.map { name in
            RemoteAimItem(
                id: "\(side)-\(name)",
                title: name,
                remoteDir: "AIM/\(side)/\(name)"
            )
        }
    }

    // MARK: Chams — one remote shader per game flavor

    static func chamsItems(forPackage package: String) -> [RemoteChamsItem] {
        let side = (package == "com.dts.freefiremax") ? "FFM" : "FFTH"
        return [
            RemoteChamsItem(
                id: "\(side)-CHAMS",
                title: "Chams",
                remoteDir: "CHAMS/\(side)"
            )
        ]
    }

    // MARK: Menu

    static func menuItems(forPackage package: String) -> [RemoteMenuItem] {
        if package == "com.dts.freefiremax" {
            return [
                RemoteMenuItem(id: "FFM-AIMBOT-HIDE", title: "FFM AIMBOT HIDE", remoteDir: "MENU/FFM/FFM AIMBOT HIDE"),
                RemoteMenuItem(id: "FFM-CANCHECK-R8", title: "FFM CANCHECK R8", remoteDir: "MENU/FFM/FFM CANCHECK R8"),
                RemoteMenuItem(id: "FFM-ESP-NO-AIM", title: "FFM ESP NO AIM", remoteDir: "MENU/FFM/FFM ESP NO AIM"),
                RemoteMenuItem(id: "FFM-R8-ESP", title: "FFM R8 + ESP", remoteDir: "MENU/FFM/FFM R8 + ESP"),
            ]
        }
        return [
            RemoteMenuItem(id: "FFTH-AIMBOT-HIDE", title: "FFTH AIMBOT HIDE", remoteDir: "MENU/FFTH/FFTH AIMBOT HIDE"),
            RemoteMenuItem(id: "FFTH-CANCHECK-R8", title: "FFTH CANCHECK R8", remoteDir: "MENU/FFTH/FFTH CANCHECK R8"),
            RemoteMenuItem(id: "FFTH-ESP-NO-AIM", title: "FFTH ESP NO AIM", remoteDir: "MENU/FFTH/FFTH ESP NO AIM"),
            RemoteMenuItem(id: "FFTH-R8-ESP", title: "FFTH R8 + ESP", remoteDir: "MENU/FFTH/FFTH R8 + ESP"),
        ]
    }

    // MARK: Mods

    static func modCharacters(forPackage package: String) -> [RemoteModCharacter] {
        if package == "com.dts.freefiremax" {
            return loadModCharacters(kind: "FFM")
        }
        return loadModCharacters(kind: "FFTH")
    }

    private static func loadModCharacters(kind: String) -> [RemoteModCharacter] {
        if kind == "FFTH" {
            return [
                RemoteModCharacter(
                    id: "ALOK",
                    title: "ALOK",
                    versions: (1...10).map { v in
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

    static func isAimApplied(package: String, item: RemoteAimItem) -> Bool {
        UserDefaults.standard.string(forKey: defaultsKey(package: package, feature: "aim.\(item.id)")) != nil
    }

    static func isChamsApplied(package: String, item: RemoteChamsItem) -> Bool {
        UserDefaults.standard.string(forKey: defaultsKey(package: package, feature: "chams.\(item.id)")) != nil
    }

    static func isModVersionApplied(package: String, version: RemoteModVersion) -> Bool {
        UserDefaults.standard.string(forKey: defaultsKey(package: package, feature: "mod.\(version.id)")) != nil
    }

    // MARK: Menu apply / restore

    static func applyMenu(package: String, item: RemoteMenuItem) throws {
        let remoteDir = repoPath(item.remoteDir)
        let files = try listRemoteFiles(inRepoPath: remoteDir)
        guard !files.isEmpty else { throw FreeFireRemoteAssetError.remoteEmpty(remoteDir) }
        let destDir = try containerDir(bundleID: package, relative: menuRelativeDir)
        var written: [String] = []
        for file in files {
            let data = try download(urlString: file.downloadURL)
            try writeReplacing(data: data, to: destDir.appendingPathComponent(file.name))
            written.append(file.name)
        }
        UserDefaults.standard.set(written, forKey: defaultsKey(package: package, feature: "menu.\(item.id)"))
    }

    static func restoreMenu(package: String, item: RemoteMenuItem) throws {
        let key = defaultsKey(package: package, feature: "menu.\(item.id)")
        let destDir = try containerDir(bundleID: package, relative: menuRelativeDir)
        if let names = UserDefaults.standard.stringArray(forKey: key) {
            for name in names {
                try? FileManager.default.removeItem(at: destDir.appendingPathComponent(name))
            }
        }
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: Aim apply / restore
    // Bật: lấy file cuối cùng trong AIM/<FFM|FFTH>/<tên AIM>
    // Tắt: lấy file cuối cùng trong AIM/<FFM|FFTH>/GOC và ghi đè cùng vị trí đích.
    // Các file ẩn / .gitkeep không được coi là asset.

    static func applyAim(package: String, item: RemoteAimItem) throws {
        let remoteDir = repoPath(item.remoteDir)
        let file = try lastRemoteAssetFile(inRepoPath: remoteDir)
        let data = try download(urlString: file.downloadURL)
        let destDir = try containerDir(bundleID: package, relative: aimRelativeDir)
        try writeReplacing(data: data, to: destDir.appendingPathComponent(file.name))
        UserDefaults.standard.set(file.name, forKey: defaultsKey(package: package, feature: "aim.\(item.id)"))
    }

    static func restoreAim(package: String, item: RemoteAimItem) throws {
        let side = (package == "com.dts.freefiremax") ? "FFM" : "FFTH"
        let gocDir = repoPath("AIM/\(side)/GOC")
        let file = try lastRemoteAssetFile(inRepoPath: gocDir)
        let data = try download(urlString: file.downloadURL)
        let destDir = try containerDir(bundleID: package, relative: aimRelativeDir)

        // Tắt AIM không xóa asset đích. Thay vào đó, ghi file GOC vào đúng vị trí
        // để trả game về trạng thái gốc / trạng thái mặc định.
        try writeReplacing(data: data, to: destDir.appendingPathComponent(file.name))
        UserDefaults.standard.removeObject(forKey: defaultsKey(package: package, feature: "aim.\(item.id)"))
    }

    // MARK: Chams apply / restore
    // Bật: lấy file shader cuối cùng trong CHAMS/<FFM|FFTH>.
    // Tắt: xóa đúng file đã ghi vào gameassetbundles.

    static func applyChams(package: String, item: RemoteChamsItem) throws {
        let remoteDir = repoPath(item.remoteDir)
        let file = try lastRemoteAssetFile(inRepoPath: remoteDir)
        let data = try download(urlString: file.downloadURL)
        let destDir = try containerDir(bundleID: package, relative: chamsRelativeDir)
        try writeReplacing(data: data, to: destDir.appendingPathComponent(file.name))
        UserDefaults.standard.set(file.name, forKey: defaultsKey(package: package, feature: "chams.\(item.id)"))
    }

    static func restoreChams(package: String, item: RemoteChamsItem) throws {
        let key = defaultsKey(package: package, feature: "chams.\(item.id)")
        let destDir = try containerDir(bundleID: package, relative: chamsRelativeDir)
        if let name = UserDefaults.standard.string(forKey: key) {
            try? FileManager.default.removeItem(at: destDir.appendingPathComponent(name))
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
