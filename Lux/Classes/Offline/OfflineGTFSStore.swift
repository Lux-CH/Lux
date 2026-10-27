//
//  OfflineGTFSStore.swift
//  Lux
//
//  Created by Constantin Clerc on 13.06.2026.
//

import Foundation
import CoreLocation
import SQLite3

enum OfflineRegion {
    static let minLat = 46.09207
    static let maxLat = 46.31569
    static let minLon = 5.87943
    static let maxLon = 6.32227

    static func contains(lat: Double, lon: Double) -> Bool {
        lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon
    }
}

struct GTFSDeparture {
    let tripId: String
    let stopId: String
    let stopName: String
    let lat: Double
    let lon: Double
    let depSec: Int?
    let arrSec: Int?
    let serviceDay: Date
    let headsign: String?
    let routeShortName: String
    let routeType: Int
    let agencyId: String
}

struct GTFSTripStop {
    let seq: Int
    let stopId: String
    let name: String
    let lat: Double
    let lon: Double
    let arrSec: Int?
    let depSec: Int?
}

struct GTFSTripDetails {
    let stops: [GTFSTripStop]
    let headsign: String?
    let routeShortName: String
    let routeType: Int
    let agencyId: String
    let serviceDay: Date
}

struct GTFSStop {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
}

final class OfflineGTFSStore: @unchecked Sendable {

    let dbQueue: SQLiteConnection
    let fileURL: URL

    init(url: URL) throws {
        self.fileURL = url
        self.dbQueue = try SQLiteConnection(path: url.path)
        try dbQueue.execute(Self.schema)
    }

    private static let schema = """
                CREATE TABLE IF NOT EXISTS stop (
                    id TEXT PRIMARY KEY,
                    norm_id TEXT NOT NULL DEFAULT '',
                    name TEXT NOT NULL,
                    search_name TEXT NOT NULL,
                    lat DOUBLE NOT NULL,
                    lon DOUBLE NOT NULL,
                    parent_station TEXT NOT NULL DEFAULT '',
                    location_type INTEGER NOT NULL DEFAULT 0,
                    level DOUBLE NOT NULL DEFAULT 0
                );
                CREATE INDEX IF NOT EXISTS idx_stop_parent ON stop(parent_station);
                CREATE INDEX IF NOT EXISTS idx_stop_norm ON stop(norm_id);
                CREATE INDEX IF NOT EXISTS idx_stop_search ON stop(search_name);
                CREATE INDEX IF NOT EXISTS idx_stop_latlon ON stop(lat, lon);

                CREATE TABLE IF NOT EXISTS route (
                    id TEXT PRIMARY KEY,
                    short_name TEXT NOT NULL DEFAULT '',
                    route_type INTEGER NOT NULL DEFAULT 3,
                    agency_id TEXT NOT NULL DEFAULT '',
                    color TEXT
                );

                CREATE TABLE IF NOT EXISTS trip (
                    id TEXT PRIMARY KEY,
                    route_id TEXT NOT NULL,
                    service_id TEXT NOT NULL,
                    headsign TEXT
                );
                CREATE INDEX IF NOT EXISTS idx_trip_service ON trip(service_id);

                CREATE TABLE IF NOT EXISTS stop_time (
                    trip_id TEXT NOT NULL,
                    stop_id TEXT NOT NULL,
                    seq INTEGER NOT NULL,
                    arr_sec INTEGER,
                    dep_sec INTEGER,
                    headsign TEXT,
                    pickup INTEGER NOT NULL DEFAULT 0,
                    dropoff INTEGER NOT NULL DEFAULT 0
                );
                CREATE INDEX IF NOT EXISTS idx_st_stop ON stop_time(stop_id, dep_sec);
                CREATE INDEX IF NOT EXISTS idx_st_trip ON stop_time(trip_id, seq);

                CREATE TABLE IF NOT EXISTS calendar (
                    service_id TEXT PRIMARY KEY,
                    mon INTEGER, tue INTEGER, wed INTEGER, thu INTEGER,
                    fri INTEGER, sat INTEGER, sun INTEGER,
                    start_date INTEGER, end_date INTEGER
                );

                CREATE TABLE IF NOT EXISTS calendar_date (
                    service_id TEXT NOT NULL,
                    date INTEGER NOT NULL,
                    exception INTEGER NOT NULL
                );
                CREATE INDEX IF NOT EXISTS idx_caldate ON calendar_date(date);

                CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);
                """

    static let zurich: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        return cal
    }()

    static func serviceDayStart(for date: Date) -> Date {
        let noon = zurich.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? zurich.startOfDay(for: date)
        return noon.addingTimeInterval(-12 * 3600)
    }

    func activeServiceIds(on day: Date, db: SQLiteConnection) throws -> Set<String> {
        let cal = OfflineGTFSStore.zurich
        let comps = cal.dateComponents([.year, .month, .day, .weekday], from: day.addingTimeInterval(12 * 3600))
        let ymd = (comps.year! * 10000) + (comps.month! * 100) + comps.day!
        let weekdayColumn = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"][comps.weekday! - 1]

        var ids = Set<String>(try db.strings( """
            SELECT service_id FROM calendar
            WHERE start_date <= ? AND end_date >= ? AND \(weekdayColumn) = 1
            """, arguments: [ymd, ymd]))

        let added = try db.strings(
            "SELECT service_id FROM calendar_date WHERE date = ? AND exception = 1", arguments: [ymd])
        let removed = try db.strings(
            "SELECT service_id FROM calendar_date WHERE date = ? AND exception = 2", arguments: [ymd])

        ids.formUnion(added)
        ids.subtract(removed)
        return ids
    }

    func departures(stopId: String, time: Date, limit: Int) throws -> [GTFSDeparture] {
        let cal = OfflineGTFSStore.zurich
        let today = OfflineGTFSStore.serviceDayStart(for: time)
        let yesterday = OfflineGTFSStore.serviceDayStart(for: cal.date(byAdding: .day, value: -1, to: time)!)
        let nowSec = Int(time.timeIntervalSince(today))
        let yesterdaySec = Int(time.timeIntervalSince(yesterday))

        return try dbQueue.read { db in
            let stopIds = try self.physicalStopIds(for: stopId, db: db)
            guard !stopIds.isEmpty else { return [] }

            var rows: [GTFSDeparture] = []
            for (serviceDay, minDepSec) in [(today, nowSec), (yesterday, yesterdaySec)] {
                let services = try self.activeServiceIds(on: serviceDay, db: db)
                if services.isEmpty { continue }
                rows += try self.rawDepartures(db: db, stopIds: stopIds, serviceIds: services,
                                               minDepSec: minDepSec, serviceDay: serviceDay, limit: limit)
            }

            return rows
                .sorted { ($0.depSec ?? 0) + Int($0.serviceDay.timeIntervalSince1970)
                        < ($1.depSec ?? 0) + Int($1.serviceDay.timeIntervalSince1970) }
                .prefix(limit)
                .map { $0 }
        }
    }

    private func physicalStopIds(for stopId: String, db: SQLiteConnection) throws -> [String] {
        var ids = try db.strings(
            "SELECT id FROM stop WHERE id = ? OR parent_station = ?", arguments: [stopId, stopId])
        if ids.isEmpty {
            let norm = OfflineGTFSStore.normalize(id: stopId)
            ids = try db.strings( """
                SELECT id FROM stop WHERE norm_id = ?
                   OR parent_station IN (SELECT id FROM stop WHERE norm_id = ?)
                """, arguments: [norm, norm])
        }
        return ids
    }

    private func rawDepartures(db: SQLiteConnection, stopIds: [String], serviceIds: Set<String>,
                               minDepSec: Int, serviceDay: Date, limit: Int) throws -> [GTFSDeparture] {
        let serviceIdsArray = Array(serviceIds)
        let servicePlaceholders = databaseQuestionMarks(count: serviceIdsArray.count)
        let stopPlaceholders = databaseQuestionMarks(count: stopIds.count)
        let sql = """
            SELECT st.trip_id, st.stop_id, st.dep_sec, st.arr_sec, st.headsign AS st_headsign,
                   s.name AS stop_name, s.lat, s.lon,
                   t.headsign AS trip_headsign,
                   r.short_name, r.route_type, r.agency_id
            FROM stop_time st
            JOIN trip t ON t.id = st.trip_id
            JOIN route r ON r.id = t.route_id
            JOIN stop s ON s.id = st.stop_id
            WHERE st.stop_id IN (\(stopPlaceholders)) AND st.dep_sec IS NOT NULL AND st.dep_sec >= ?
              AND t.service_id IN (\(servicePlaceholders))
            ORDER BY st.dep_sec
            LIMIT ?
            """
        let args: [any SQLiteBindable] = stopIds + [minDepSec] + serviceIdsArray + [limit]
        let rows = try db.rows(sql, arguments: args)
        return rows.map { row in
            GTFSDeparture(
                tripId: row.string("trip_id"), stopId: row.string("stop_id"), stopName: row.string("stop_name"),
                lat: row.double("lat"), lon: row.double("lon"), depSec: row.optionalInt("dep_sec"), arrSec: row.optionalInt("arr_sec"),
                serviceDay: serviceDay,
                headsign: row.optionalString("st_headsign")?.nilIfEmpty ?? row.optionalString("trip_headsign"),
                routeShortName: row.string("short_name"), routeType: row.int("route_type"), agencyId: row.string("agency_id")
            )
        }
    }

    func searchStops(text: String, limit: Int) throws -> [GTFSStop] {
        let folded = OfflineGTFSStore.fold(text)
        guard !folded.isEmpty else { return [] }
        return try dbQueue.read { db in
            let rows = try db.rows( """
                SELECT id, name, lat, lon FROM stop
                WHERE parent_station = '' AND search_name LIKE ?
                ORDER BY (CASE WHEN search_name LIKE ? THEN 0 ELSE 1 END), length(name)
                LIMIT ?
                """, arguments: ["%\(folded)%", "\(folded)%", limit])
            return rows.map { GTFSStop(id: $0.string("id"), name: $0.string("name"), lat: $0.double("lat"), lon: $0.double("lon")) }
        }
    }

    func nearestStops(lat: Double, lon: Double, limit: Int) throws -> [GTFSStop] {
        let target = CLLocation(latitude: lat, longitude: lon)
        for delta in [0.05, 0.15, 0.5] {
            let rows: [GTFSStop] = try dbQueue.read { db in
                try db.rows( """
                    SELECT id, name, lat, lon FROM stop
                    WHERE parent_station = '' AND lat BETWEEN ? AND ? AND lon BETWEEN ? AND ?
                    """, arguments: [lat - delta, lat + delta, lon - delta, lon + delta])
                .map { GTFSStop(id: $0.string("id"), name: $0.string("name"), lat: $0.double("lat"), lon: $0.double("lon")) }
            }
            if rows.count >= min(limit, 1) || delta == 0.5 {
                return rows
                    .sorted { CLLocation(latitude: $0.lat, longitude: $0.lon).distance(from: target)
                            < CLLocation(latitude: $1.lat, longitude: $1.lon).distance(from: target) }
                    .prefix(limit)
                    .map { $0 }
            }
        }
        return []
    }

    func tripDetails(tripId: String, serviceDay: Date) throws -> GTFSTripDetails? {
        try dbQueue.read { db in
            let rows = try db.rows( """
                SELECT st.seq, st.stop_id, st.arr_sec, st.dep_sec,
                       s.name, s.lat, s.lon,
                       t.headsign AS trip_headsign, r.short_name, r.route_type, r.agency_id
                FROM stop_time st
                JOIN stop s ON s.id = st.stop_id
                JOIN trip t ON t.id = st.trip_id
                JOIN route r ON r.id = t.route_id
                WHERE st.trip_id = ?
                ORDER BY st.seq
                """, arguments: [tripId])
            guard let first = rows.first else { return nil }
            let stops = rows.map {
                GTFSTripStop(seq: $0.int("seq"), stopId: $0.string("stop_id"), name: $0.string("name"),
                             lat: $0.double("lat"), lon: $0.double("lon"), arrSec: $0.optionalInt("arr_sec"), depSec: $0.optionalInt("dep_sec"))
            }
            return GTFSTripDetails(
                stops: stops,
                headsign: first.optionalString("trip_headsign"),
                routeShortName: first.string("short_name"),
                routeType: first.int("route_type"),
                agencyId: first.string("agency_id"),
                serviceDay: serviceDay
            )
        }
    }

    func importDate() -> Date? {
        let value = try? dbQueue.read { db in
            try db.strings("SELECT value FROM meta WHERE key = 'import_date'").first
        }
        guard let value, let interval = TimeInterval(value) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    func stopCount() -> Int {
        (try? dbQueue.read { db in try db.rows("SELECT COUNT(*) AS n FROM stop").first?.int("n") ?? 0 }) ?? 0
    }

    static func normalize(id: String) -> String {
        var s = id
        s = s.replacingOccurrences(of: "ch-opentransportdataswiss26:", with: "")
        s = s.replacingOccurrences(of: "ch-opentransportdataswiss26", with: "")
        if let colon = s.firstIndex(of: ":") { s = String(s[..<colon]) }
        return s
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private func databaseQuestionMarks(count: Int) -> String {
    Array(repeating: "?", count: max(count, 1)).joined(separator: ",")
}

protocol SQLiteBindable {
    func bind(to statement: OpaquePointer?, at position: Int32)
}

extension Int: SQLiteBindable {
    func bind(to statement: OpaquePointer?, at position: Int32) {
        sqlite3_bind_int64(statement, position, Int64(self))
    }
}

extension Double: SQLiteBindable {
    func bind(to statement: OpaquePointer?, at position: Int32) {
        sqlite3_bind_double(statement, position, self)
    }
}

extension String: SQLiteBindable {
    func bind(to statement: OpaquePointer?, at position: Int32) {
        sqlite3_bind_text(statement, position, self, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }
}

struct SQLiteError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct SQLiteRow {
    fileprivate enum Value {
        case int(Int)
        case double(Double)
        case text(String)
        case null
    }

    fileprivate let values: [String: Value]
    fileprivate let first: Value?

    func optionalString(_ column: String) -> String? {
        Self.string(values[column])
    }

    func string(_ column: String) -> String { optionalString(column) ?? "" }

    func optionalInt(_ column: String) -> Int? {
        switch values[column] {
        case .int(let value): return value
        case .double(let value): return Int(value)
        case .text(let value): return Int(value)
        default: return nil
        }
    }

    func int(_ column: String) -> Int { optionalInt(column) ?? 0 }

    func double(_ column: String) -> Double {
        switch values[column] {
        case .double(let value): return value
        case .int(let value): return Double(value)
        case .text(let value): return Double(value) ?? 0
        default: return 0
        }
    }

    fileprivate var firstString: String? { Self.string(first) }

    private static func string(_ value: Value?) -> String? {
        switch value {
        case .text(let value): return value
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        default: return nil
        }
    }
}

final class SQLiteConnection: @unchecked Sendable {
    private var handle: OpaquePointer?
    private let queue = DispatchQueue(label: "ch.cclerc.lux.offline-sqlite")

    init(path: String) throws {
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
            sqlite3_close_v2(handle)
            handle = nil
            throw SQLiteError(message: message)
        }
        sqlite3_busy_timeout(handle, 5000)
    }

    deinit {
        sqlite3_close_v2(handle)
    }

    func read<T>(_ body: (SQLiteConnection) throws -> T) throws -> T {
        try queue.sync { try body(self) }
    }

    func execute(_ sql: String) throws {
        try queue.sync {
            guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else { throw lastError() }
        }
    }

    func strings(_ sql: String, arguments: [any SQLiteBindable] = []) throws -> [String] {
        try rows(sql, arguments: arguments).compactMap(\.firstString)
    }

    func rows(_ sql: String, arguments: [any SQLiteBindable] = []) throws -> [SQLiteRow] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else { throw lastError() }
        defer { sqlite3_finalize(statement) }

        for (index, argument) in arguments.enumerated() {
            argument.bind(to: statement, at: Int32(index + 1))
        }

        let columnCount = sqlite3_column_count(statement)
        let names = (0..<columnCount).map { String(cString: sqlite3_column_name(statement, $0)) }
        var result: [SQLiteRow] = []
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE { break }
            guard step == SQLITE_ROW else { throw lastError() }
            var values: [String: SQLiteRow.Value] = [:]
            var first: SQLiteRow.Value?
            for column in 0..<columnCount {
                let value: SQLiteRow.Value
                switch sqlite3_column_type(statement, column) {
                case SQLITE_INTEGER: value = .int(Int(sqlite3_column_int64(statement, column)))
                case SQLITE_FLOAT: value = .double(sqlite3_column_double(statement, column))
                case SQLITE_NULL: value = .null
                default: value = .text(sqlite3_column_text(statement, column).map { String(cString: $0) } ?? "")
                }
                values[names[Int(column)]] = value
                if column == 0 { first = value }
            }
            result.append(SQLiteRow(values: values, first: first))
        }
        return result
    }

    private func lastError() -> SQLiteError {
        SQLiteError(message: handle.map { String(cString: sqlite3_errmsg($0)) } ?? "sqlite error")
    }
}
