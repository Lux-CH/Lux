//
//  OnboardMotionRecorder.swift
//  Lux
//
//  Created by Constantin Clerc on 26.09.2026.
//

import CoreLocation
import CoreMotion
import Foundation

final class OnboardMotionRecorder: @unchecked Sendable {
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private let writeQueue = DispatchQueue(label: "ch.cclerc.lux.onboard.recorder", qos: .utility)
    private var handle: FileHandle?
    private var buffer = ""
    private var lastContext = ""
    private var isRecording = false

    static var folder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MotionRecordings", isDirectory: true)
    }

    static var recordings: [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.filter { $0.pathExtension == "csv" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    static var totalSize: Int64 {
        recordings.reduce(0) { total, url in
            total + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    static func deleteAll() {
        for url in recordings {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func start(tripName: String) {
        guard !isRecording, motionManager.isDeviceMotionAvailable else { return }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = Self.folder.appendingPathComponent("ride-\(formatter.string(from: Date())).csv")
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        guard FileManager.default.createFile(atPath: url.path, contents: nil),
              let handle = try? FileHandle(forWritingTo: url) else { return }
        isRecording = true
        writeQueue.async { [self] in self.handle = handle }
        write("# \(tripName.replacingOccurrences(of: "\n", with: " "))\n")
        write("# m,t,ax,ay,az,gx,gy,gz,rx,ry,rz | g,t,lat,lon,speed,course,accuracy | c,t,phase,leg,mode,line,trip,nextStop,along,locked\n")

        let offset = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
        queue.maxConcurrentOperationCount = 1
        motionManager.deviceMotionUpdateInterval = 1.0 / 50
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let a = motion.userAcceleration
            let g = motion.gravity
            let r = motion.rotationRate
            let line = String(
                format: "m,%.3f,%.4f,%.4f,%.4f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f\n",
                motion.timestamp + offset, a.x, a.y, a.z, g.x, g.y, g.z, r.x, r.y, r.z
            )
            self.write(line)
        }
    }

    func record(_ location: CLLocation) {
        guard isRecording else { return }
        write(String(
            format: "g,%.3f,%.6f,%.6f,%.2f,%.1f,%.1f\n",
            location.timestamp.timeIntervalSince1970, location.coordinate.latitude, location.coordinate.longitude,
            location.speed, location.course, location.horizontalAccuracy
        ))
    }

    func context(phase: String, leg: Int, mode: String, line: String, trip: String, nextStop: Int, along: Double, locked: Bool) {
        guard isRecording else { return }
        let fields = "\(phase),\(leg),\(mode),\(line.replacingOccurrences(of: ",", with: " ")),\(trip),\(nextStop),\(Int(along)),\(locked ? 1 : 0)"
        guard fields != lastContext else { return }
        lastContext = fields
        write(String(format: "c,%.3f,", Date().timeIntervalSince1970) + fields + "\n")
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        motionManager.stopDeviceMotionUpdates()
        writeQueue.async { [self] in
            flush()
            try? handle?.close()
            handle = nil
        }
    }

    private func write(_ text: String) {
        writeQueue.async { [self] in
            buffer += text
            if buffer.utf8.count > 64_000 { flush() }
        }
    }

    private func flush() {
        guard !buffer.isEmpty, let handle else { return }
        try? handle.write(contentsOf: Data(buffer.utf8))
        buffer = ""
    }
}
