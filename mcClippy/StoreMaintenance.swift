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
//  Separately, Core Data (under SwiftData) keeps a *persistent history* log —
//  the ATRANSACTION / ACHANGE tables — appending a row for every insert and
//  every delete. That log exists so CloudKit-synced or multi-process readers can
//  catch up on changes. mcClippy is a single process with no sync, so nothing
//  ever consumes it; it just grows with use (thousands of rows for a handful of
//  visible items). We clear it here.
//
//  All of this runs at launch, *before* the ModelContainer is created. At that
//  point no other connection has the store open, so a direct SQLite checkpoint,
//  history purge, and VACUUM are exclusive and safe. Do NOT call this once
//  SwiftData has opened the store — a second writer on the same file is unsafe.
//

import Foundation
import os
import SQLite3

enum StoreMaintenance {
    /// Core Data's persistent-history tables, child-before-parent so the deletes
    /// don't trip a foreign-key check if one is enabled.
    private static let changeLogTables = ["ACHANGE", "ATRANSACTIONSTRING", "ATRANSACTION"]

    /// Purges the persistent-history log, folds the WAL back into the main store,
    /// and compacts free pages. Call exactly once, at launch, before the
    /// SwiftData `ModelContainer` opens.
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

        purgeChangeLog(db)
        // Fold the WAL into the main file and truncate it to zero. A no-op when
        // the store isn't in WAL mode, so it's safe regardless of journal mode.
        exec(db, "PRAGMA wal_checkpoint(TRUNCATE);")
        // Rebuild the file, dropping free pages left by the purge and by
        // churned/pruned items. Must run outside any open transaction.
        exec(db, "VACUUM;")

        let after = fileSize(storeURL)
        Log.app.info("Store compacted at launch: \(before, privacy: .public) → \(after, privacy: .public) bytes")
    }

    /// Deletes every persistent-history transaction. Safe here because mcClippy
    /// is a single process with no CloudKit / cross-process readers, so no
    /// transaction is ever unconsumed — this is the SQL equivalent of Core
    /// Data's `deleteHistory(before: .now)`. Defensive: no-ops cleanly if the
    /// internal tables aren't present (history tracking off, or SwiftData
    /// internals changed shape), and rolls back if any delete fails.
    private static func purgeChangeLog(_ db: OpaquePointer) {
        guard tableExists(db, "ATRANSACTION") else { return }
        let txBefore = scalar(db, "SELECT COUNT(*) FROM ATRANSACTION;")
        guard txBefore > 0 else { return }

        guard exec(db, "BEGIN IMMEDIATE;") else { return }
        var ok = true
        for table in changeLogTables where tableExists(db, table) {
            if !exec(db, "DELETE FROM \(table);") {
                ok = false
                break
            }
        }
        exec(db, ok ? "COMMIT;" : "ROLLBACK;")
        if ok {
            Log.app.info("Purged change log: \(txBefore, privacy: .public) stale transactions cleared")
        }
    }

    // MARK: - SQLite helpers

    @discardableResult
    private static func exec(_ db: OpaquePointer, _ sql: String) -> Bool {
        var errmsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errmsg)
        if rc != SQLITE_OK {
            let message = errmsg.map { String(cString: $0) } ?? "unknown error"
            Log.app.error("Store maintenance failed (\(sql, privacy: .public)): \(message, privacy: .public)")
        }
        if let errmsg { sqlite3_free(errmsg) }
        return rc == SQLITE_OK
    }

    private static func scalar(_ db: OpaquePointer, _ sql: String) -> Int64 {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? sqlite3_column_int64(stmt, 0) : 0
    }

    /// Table names here are fixed internal constants, never user input, so the
    /// interpolation is injection-safe.
    private static func tableExists(_ db: OpaquePointer, _ name: String) -> Bool {
        scalar(db, "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='\(name)';") > 0
    }

    private static func fileSize(_ url: URL) -> Int {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return 0 }
        return (attrs[.size] as? Int) ?? 0
    }
}
