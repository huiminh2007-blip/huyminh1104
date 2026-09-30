import Foundation
import UIKit

struct BundledAimPatch: Identifiable, Hashable {
    let id: String
    let title: String
    let resourceName: String
}

struct BundledChamsPatch: Identifiable, Hashable {
    enum Kind: String {
        case character
        case gun
    }
    let id: String
    let title: String
    let resourceName: String
    let kind: Kind
}

enum FreeFireBundledPatchIO {
    static func packageURL(resourceName: String, subdirectory: String) -> URL? {
        let name = (resourceName as NSString).deletingPathExtension
        let ext = (resourceName as NSString).pathExtension
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
            return url
        }
        return Bundle.main.url(forResource: name, withExtension: ext)
    }

    static func decodeProject(resourceName: String, subdirectory: String) throws -> PatchProject {
        guard let url = packageURL(resourceName: resourceName, subdirectory: subdirectory) else {
            throw PatchPackageError.unsupportedFormat
        }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return try PatchPackageCodec.decode(data, password: nil).project
    }

    static func apply(resourceName: String, subdirectory: String) throws {
        let project = try decodeProject(resourceName: resourceName, subdirectory: subdirectory)
        _ = try DevicePatchService.apply(project: project)
    }

    static func restore(resourceName: String, subdirectory: String) throws {
        let project = try decodeProject(resourceName: resourceName, subdirectory: subdirectory)
        guard let receipt = DevicePatchService.latestReceipt(projectID: project.id) else { return }
        try DevicePatchService.restore(receipt: receipt)
    }

    static func isApplied(resourceName: String, subdirectory: String) -> Bool {
        guard let project = try? decodeProject(resourceName: resourceName, subdirectory: subdirectory) else {
            return false
        }
        return DevicePatchService.latestReceipt(projectID: project.id) != nil
    }
}

enum FreeFireAimToggleService {
    private static let subdirectory = "BundledPatches/FFTHAim"

    static let patches: [BundledAimPatch] = {
        if let url = Bundle.main.url(forResource: "catalog", withExtension: "json", subdirectory: subdirectory)
            ?? Bundle.main.url(forResource: "catalog", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
            let mapped = rows.compactMap { row -> BundledAimPatch? in
                guard let id = row["id"], let title = row["title"], let resource = row["resource"] else { return nil }
                return BundledAimPatch(id: id, title: title, resourceName: resource)
            }
            if !mapped.isEmpty { return mapped }
        }
        return [
            BundledAimPatch(id: "aim_body", title: "Aim Body", resourceName: "Aim_Body.1411"),
            BundledAimPatch(id: "aim_co", title: "Aim Cổ", resourceName: "Aim_Co.1411"),
            BundledAimPatch(id: "aim_keo", title: "Aim Kéo", resourceName: "Aim_Keo.1411"),
            BundledAimPatch(id: "aim_nguc", title: "Aim Ngực", resourceName: "Aim_Nguc.1411"),
            BundledAimPatch(id: "magic_bullet", title: "Magic Bullet", resourceName: "Magic_Bullet.1411"),
        ]
    }()

    static func apply(patch: BundledAimPatch) throws {
        try FreeFireBundledPatchIO.apply(resourceName: patch.resourceName, subdirectory: subdirectory)
    }

    static func restore(patch: BundledAimPatch) throws {
        try FreeFireBundledPatchIO.restore(resourceName: patch.resourceName, subdirectory: subdirectory)
    }

    static func isApplied(patch: BundledAimPatch) -> Bool {
        FreeFireBundledPatchIO.isApplied(resourceName: patch.resourceName, subdirectory: subdirectory)
    }
}

enum FreeFireChamsToggleService {
    private static let subdirectory = "BundledPatches/FFTHLocation"

    static let patches: [BundledChamsPatch] = {
        if let url = Bundle.main.url(forResource: "chams_catalog", withExtension: "json", subdirectory: subdirectory)
            ?? Bundle.main.url(forResource: "chams_catalog", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
            let mapped = rows.compactMap { row -> BundledChamsPatch? in
                guard let id = row["id"], let title = row["title"], let resource = row["resource"] else { return nil }
                let kind = BundledChamsPatch.Kind(rawValue: row["kind"] ?? "") ?? .gun
                return BundledChamsPatch(id: id, title: title, resourceName: resource, kind: kind)
            }
            if !mapped.isEmpty { return mapped }
        }
        return [
            BundledChamsPatch(id: "chams_nhan_vat", title: "Chams Nhân Vật", resourceName: "Chams_Nhan_Vat.1411", kind: .character),
            BundledChamsPatch(id: "chams_sung_den", title: "Chams súng đen trắng", resourceName: "Chams_Sung_Den_Trang.1411", kind: .gun),
            BundledChamsPatch(id: "chams_sung_do", title: "Chams súng đỏ trắng", resourceName: "Chams_Sung_Do_Trang.1411", kind: .gun),
        ]
    }()

    static func apply(patch: BundledChamsPatch) throws {
        try FreeFireBundledPatchIO.apply(resourceName: patch.resourceName, subdirectory: subdirectory)
    }

    static func restore(patch: BundledChamsPatch) throws {
        try FreeFireBundledPatchIO.restore(resourceName: patch.resourceName, subdirectory: subdirectory)
    }

    static func isApplied(patch: BundledChamsPatch) -> Bool {
        FreeFireBundledPatchIO.isApplied(resourceName: patch.resourceName, subdirectory: subdirectory)
    }
}


struct BundledModPatch: Identifiable, Hashable {
    let id: String
    let title: String
    let resourceName: String
    let previewName: String
}

enum FreeFireModsToggleService {
    private static let subdirectory = "BundledPatches/FFTHMods"

    static let patches: [BundledModPatch] = {
        if let url = Bundle.main.url(forResource: "mods_catalog", withExtension: "json", subdirectory: subdirectory)
            ?? Bundle.main.url(forResource: "mods_catalog", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
            let mapped = rows.compactMap { row -> BundledModPatch? in
                guard let id = row["id"], let title = row["title"], let resource = row["resource"] else { return nil }
                let preview = row["preview"] ?? ""
                return BundledModPatch(id: id, title: title, resourceName: resource, previewName: preview)
            }
            if !mapped.isEmpty { return mapped }
        }
        return [
            BundledModPatch(id: "mod_quai_nhan", title: "Quái nhân đen - Nạ cỏ - Alok thức tỉnh", resourceName: "Quai_Nhan_Den.1411", previewName: "Quai_Nhan_Den.png"),
            BundledModPatch(id: "mod_gojo", title: "Gojo - Wolfrahh", resourceName: "Gojo_Wolfrahh.1411", previewName: "Gojo_Wolfrahh.png"),
        ]
    }()

    static func apply(patch: BundledModPatch) throws {
        try FreeFireBundledPatchIO.apply(resourceName: patch.resourceName, subdirectory: subdirectory)
    }

    static func restore(patch: BundledModPatch) throws {
        try FreeFireBundledPatchIO.restore(resourceName: patch.resourceName, subdirectory: subdirectory)
    }

    static func isApplied(patch: BundledModPatch) -> Bool {
        FreeFireBundledPatchIO.isApplied(resourceName: patch.resourceName, subdirectory: subdirectory)
    }

    static func previewImage(for patch: BundledModPatch) -> UIImage? {
        guard !patch.previewName.isEmpty else { return nil }

        let previewName = patch.previewName as NSString
        let name = previewName.deletingPathExtension
        let ext = previewName.pathExtension

        let urls: [URL?] = [
            Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdirectory),
            Bundle.main.url(forResource: name, withExtension: ext),
            Bundle.main.url(forResource: patch.previewName, withExtension: nil, subdirectory: subdirectory),
            Bundle.main.url(forResource: patch.previewName, withExtension: nil)
        ]

        for url in urls.compactMap({ $0 }) {
            if let image = UIImage(contentsOfFile: url.path) {
                return image
            }
            if let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                return image
            }
        }

        return UIImage(named: name)
    }
}
