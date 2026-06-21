//
//  StoreMaintenance.swift
//  mcClippy
//
//  Keeps the on-disk SwiftData store compact. A long-running menu-bar app never
//  shuts down cleanly, so SwiftData never gets to fold its write-ahead log back
//  into the main store; the `-wal` file grows toward SQLite's auto-checkpoint
//  threshold and stays there, and VACUUM never runs, so free pages left by
//  pruned/churned items are never reclaimed.
//
//  We fix that at launch, *before* the ModelContainer is created. At that point
//  no other connection has the store open, so a direct SQLite checkpoint +
//  VACUUM is exclusive and safe. Do NOT call this once SwiftData has opened the
//  store — a second writer on the same file is unsafe.
//

import Foundation
import os
import SQLite3

enum StoreMaintenance {
    /// Folds the WAL back into the main store and compacts free pages.
    /// Call exactly once, at launch, before the SwiftData `ModelContainer` opens.
    static func compactAtLaunch(storeURL: URL) {
        let path = storeURL.path
        guard FileManager.default.fileExists(atPath: path) else { return }

        var handle: OpaquePointer?
        guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
              let db = handle else {
            if let handle { sqlite3_close(handle) }
            Log.app.error("Store maintenance: could not open store at launch")
            return
        }
        defer { sqlite3_close(db) }

        let before = fileSize(storeURL)

        // Fold the WAL into the main file and truncate it to zero. A no-op when
        // the store isn't in WAL mode, so it's safe regardless of journal mode.
        exec(db, "PRAGMA wal_checkpoint(TRUNCATE);")
        // Rebuild the file, dropping free pages left by churned/pruned items.
        exec(db, "VACUUM;")

        let after = fileSize(storeURL)
        Log.app.info("Store compacted at launch: \(before, privacy: .public) → \(after, privacy: .public) bytes")
    }

    private static func exec(_ db: OpaquePointer, _ sql: String) {
        var errmsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errmsg) != SQLITE_OK {
            let message = errmsg.map { String(cString: $0) } ?? "unknown error"
            Log.app.error("Store maintenance failed (\(sql, privacy: .public)): \(message, privacy: .public)")
        }
        if let errmsg { sqlite3_free(errmsg) }
    }

    private static func fileSize(_ url: URL) -> Int {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return 0 }
        return (attrs[.size] as? Int) ?? 0
    }
}
