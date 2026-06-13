import Foundation
import CoreLocation
import GRDB

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

    let dbQueue: DatabaseQueue
    let fileURL: URL

    init(url: URL) throws {
        self.fileURL = url
        var config = Configuration()
        config.busyMode = .timeout(5)
        self.dbQueue = try DatabaseQueue(path: url.path, configuration: config)
        try migrator.migrate(dbQueue)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
                CREATE TABLE stop (
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
                CREATE INDEX idx_stop_parent ON stop(parent_station);
                CREATE INDEX idx_stop_norm ON stop(norm_id);
                CREATE INDEX idx_stop_search ON stop(search_name);
                CREATE INDEX idx_stop_latlon ON stop(lat, lon);

                CREATE TABLE route (
                    id TEXT PRIMARY KEY,
                    short_name TEXT NOT NULL DEFAULT '',
                    route_type INTEGER NOT NULL DEFAULT 3,
                    agency_id TEXT NOT NULL DEFAULT '',
                    color TEXT
                );

                CREATE TABLE trip (
                    id TEXT PRIMARY KEY,
                    route_id TEXT NOT NULL,
                    service_id TEXT NOT NULL,
                    headsign TEXT
                );
                CREATE INDEX idx_trip_service ON trip(service_id);

                CREATE TABLE stop_time (
                    trip_id TEXT NOT NULL,
                    stop_id TEXT NOT NULL,
                    seq INTEGER NOT NULL,
                    arr_sec INTEGER,
                    dep_sec INTEGER,
                    headsign TEXT,
                    pickup INTEGER NOT NULL DEFAULT 0,
                    dropoff INTEGER NOT NULL DEFAULT 0
                );
                CREATE INDEX idx_st_stop ON stop_time(stop_id, dep_sec);
                CREATE INDEX idx_st_trip ON stop_time(trip_id, seq);

                CREATE TABLE calendar (
                    service_id TEXT PRIMARY KEY,
                    mon INTEGER, tue INTEGER, wed INTEGER, thu INTEGER,
                    fri INTEGER, sat INTEGER, sun INTEGER,
                    start_date INTEGER, end_date INTEGER
                );

                CREATE TABLE calendar_date (
                    service_id TEXT NOT NULL,
                    date INTEGER NOT NULL,
                    exception INTEGER NOT NULL
                );
                CREATE INDEX idx_caldate ON calendar_date(date);

                CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
                """)
        }
        return migrator
    }

    static let zurich: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        return cal
    }()

    func activeServiceIds(on day: Date, db: Database) throws -> Set<String> {
        let cal = OfflineGTFSStore.zurich
        let comps = cal.dateComponents([.year, .month, .day, .weekday], from: day)
        let ymd = (comps.year! * 10000) + (comps.month! * 100) + comps.day!
        let weekdayColumn = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"][comps.weekday! - 1]

        var ids = Set<String>(try String.fetchAll(db, sql: """
            SELECT service_id FROM calendar
            WHERE start_date <= ? AND end_date >= ? AND \(weekdayColumn) = 1
            """, arguments: [ymd, ymd]))

        let added = try String.fetchAll(db, sql:
            "SELECT service_id FROM calendar_date WHERE date = ? AND exception = 1", arguments: [ymd])
        let removed = try String.fetchAll(db, sql:
            "SELECT service_id FROM calendar_date WHERE date = ? AND exception = 2", arguments: [ymd])

        ids.formUnion(added)
        ids.subtract(removed)
        return ids
    }

    func departures(stopId: String, time: Date, limit: Int) throws -> [GTFSDeparture] {
        let cal = OfflineGTFSStore.zurich
        let today = cal.startOfDay(for: time)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let nowSec = Int(time.timeIntervalSince(today))

        return try dbQueue.write { db in
            let stopIds = try self.physicalStopIds(for: stopId, db: db)
            guard !stopIds.isEmpty else { return [] }

            var rows: [GTFSDeparture] = []
            for (serviceDay, minDepSec) in [(today, nowSec), (yesterday, nowSec + 86_400)] {
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

    private func physicalStopIds(for stopId: String, db: Database) throws -> [String] {
        var ids = try String.fetchAll(db, sql:
            "SELECT id FROM stop WHERE id = ? OR parent_station = ?", arguments: [stopId, stopId])
        if ids.isEmpty {
            let norm = OfflineGTFSStore.normalize(id: stopId)
            ids = try String.fetchAll(db, sql: """
                SELECT id FROM stop WHERE norm_id = ?
                   OR parent_station IN (SELECT id FROM stop WHERE norm_id = ?)
                """, arguments: [norm, norm])
        }
        return ids
    }

    private func rawDepartures(db: Database, stopIds: [String], serviceIds: Set<String>,
                               minDepSec: Int, serviceDay: Date, limit: Int) throws -> [GTFSDeparture] {
        try db.execute(sql: "CREATE TEMP TABLE IF NOT EXISTS _svc(service_id TEXT PRIMARY KEY)")
        try db.execute(sql: "DELETE FROM _svc")
        for sid in serviceIds {
            try db.execute(sql: "INSERT OR IGNORE INTO _svc VALUES (?)", arguments: [sid])
        }

        let stopPlaceholders = databaseQuestionMarks(count: stopIds.count)
        let sql = """
            SELECT st.trip_id, st.stop_id, st.dep_sec, st.arr_sec, st.headsign AS st_headsign,
                   s.name AS stop_name, s.lat, s.lon,
                   t.headsign AS trip_headsign,
                   r.short_name, r.route_type, r.agency_id
            FROM stop_time st
            JOIN trip t ON t.id = st.trip_id
            JOIN _svc v ON v.service_id = t.service_id
            JOIN route r ON r.id = t.route_id
            JOIN stop s ON s.id = st.stop_id
            WHERE st.stop_id IN (\(stopPlaceholders)) AND st.dep_sec IS NOT NULL AND st.dep_sec >= ?
            ORDER BY st.dep_sec
            LIMIT ?
            """
        let args = StatementArguments(stopIds) + StatementArguments([minDepSec, limit])
        let rows = try Row.fetchAll(db, sql: sql, arguments: args)
        return rows.map { row in
            GTFSDeparture(
                tripId: row["trip_id"], stopId: row["stop_id"], stopName: row["stop_name"],
                lat: row["lat"], lon: row["lon"], depSec: row["dep_sec"], arrSec: row["arr_sec"],
                serviceDay: serviceDay,
                headsign: (row["st_headsign"] as String?)?.nilIfEmpty ?? row["trip_headsign"],
                routeShortName: row["short_name"], routeType: row["route_type"], agencyId: row["agency_id"]
            )
        }
    }

    func searchStops(text: String, limit: Int) throws -> [GTFSStop] {
        let folded = OfflineGTFSStore.fold(text)
        guard !folded.isEmpty else { return [] }
        return try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT id, name, lat, lon FROM stop
                WHERE parent_station = '' AND search_name LIKE ?
                ORDER BY (CASE WHEN search_name LIKE ? THEN 0 ELSE 1 END), length(name)
                LIMIT ?
                """, arguments: ["%\(folded)%", "\(folded)%", limit])
            return rows.map { GTFSStop(id: $0["id"], name: $0["name"], lat: $0["lat"], lon: $0["lon"]) }
        }
    }

    func nearestStops(lat: Double, lon: Double, limit: Int) throws -> [GTFSStop] {
        let target = CLLocation(latitude: lat, longitude: lon)
        for delta in [0.05, 0.15, 0.5] {
            let rows: [GTFSStop] = try dbQueue.read { db in
                try Row.fetchAll(db, sql: """
                    SELECT id, name, lat, lon FROM stop
                    WHERE parent_station = '' AND lat BETWEEN ? AND ? AND lon BETWEEN ? AND ?
                    """, arguments: [lat - delta, lat + delta, lon - delta, lon + delta])
                .map { GTFSStop(id: $0["id"], name: $0["name"], lat: $0["lat"], lon: $0["lon"]) }
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
            let rows = try Row.fetchAll(db, sql: """
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
                GTFSTripStop(seq: $0["seq"], stopId: $0["stop_id"], name: $0["name"],
                             lat: $0["lat"], lon: $0["lon"], arrSec: $0["arr_sec"], depSec: $0["dep_sec"])
            }
            return GTFSTripDetails(
                stops: stops,
                headsign: first["trip_headsign"],
                routeShortName: first["short_name"],
                routeType: first["route_type"],
                agencyId: first["agency_id"],
                serviceDay: serviceDay
            )
        }
    }

    func importDate() -> Date? {
        let value = try? dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = 'import_date'")
        }
        guard let value, let interval = TimeInterval(value) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    func stopCount() -> Int {
        (try? dbQueue.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM stop") ?? 0 }) ?? 0
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
