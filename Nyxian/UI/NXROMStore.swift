/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

import Foundation

struct NXROMEntry {
    let url: URL
    let manifest: ROMManifest?

    var displayTitle: String {
        guard let manifest else { return url.lastPathComponent }
        return "\(manifest.name) \(manifest.version)"
    }
}

enum NXROMStore {
    private static let lock = NSLock()
    private static var didMigrate = false

    private static var bootRootURL: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Boot")
    }

    static var rootURL: URL {
        bootRootURL.appendingPathComponent("ROMs")
    }

    private static var incomingURL: URL {
        bootRootURL.appendingPathComponent("ROMs/.incoming")
    }

    private static var legacySlotURL: URL {
        bootRootURL.appendingPathComponent("Slot/A")
    }

    static func migrateIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !didMigrate else { return }
        didMigrate = true

        let fm = FileManager.default
        let legacy = legacySlotURL
        guard fm.fileExists(atPath: legacy.appendingPathComponent("manifest.plist").path) else {
            try? fm.removeItem(at: bootRootURL.appendingPathComponent("Slot"))
            return
        }

        var identifier = "LegacyROM"
        if let manifest = try? ROMManifest(manifestPlistURL: legacy.appendingPathComponent("manifest.plist")) {
            identifier = manifest.identifier
        }

        try? fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let destination = allocateSlotURL(for: identifier)
        do {
            try fm.moveItem(at: legacy, to: destination)
        } catch {
            return
        }

        try? fm.removeItem(at: bootRootURL.appendingPathComponent("Slot"))
    }

    static func allSlots() -> [NXROMEntry] {
        migrateIfNeeded()

        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var entries: [NXROMEntry] = []
        for child in children {
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: child.path, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  child.lastPathComponent != ".incoming",
                  fm.fileExists(atPath: child.appendingPathComponent("manifest.plist").path) else {
                continue
            }
            entries.append(NXROMEntry(url: child, manifest: try? ROMManifest(manifestPlistURL: child.appendingPathComponent("manifest.plist"))))
        }

        return entries.sorted {
            $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
        }
    }

    static func enumerate() -> [NXROMEntry] {
        allSlots().filter { $0.manifest != nil }
    }

    static func allocateSlotURL(for identifier: String) -> URL {
        let sanitized = identifier.map { character -> Character in
            if character.isLetter || character.isNumber || character == "." || character == "-" || character == "_" {
                return character
            }
            return "_"
        }
        var slug = String(sanitized)
        while slug.isEmpty || slug.allSatisfy({ $0 == "." }) {
            slug = "ROM"
        }
        if slug == ".incoming" {
            slug = "ROM"
        }

        let fm = FileManager.default
        var candidate = rootURL.appendingPathComponent(slug)
        var counter = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = rootURL.appendingPathComponent("\(slug)-\(counter)")
            counter += 1
        }
        return candidate
    }

    static func stagingURL() -> URL {
        let url = incomingURL.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func remove(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}
