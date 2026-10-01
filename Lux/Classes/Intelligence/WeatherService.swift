//
//  WeatherService.swift
//  Lux
//
//  Created by Constantin Clerc on 01.10.2026.
//

import Foundation

struct WeatherSnapshot: Equatable, Sendable {
    let temperature: Double
    let precipitation: Double
    let code: Int

    var isWet: Bool {
        precipitation >= 0.2 || [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99].contains(code)
    }

    var isCold: Bool { temperature <= 2 }
    var isHot: Bool { temperature >= 30 }
    var isHarsh: Bool { isWet || isCold || isHot }

    var symbol: String {
        switch code {
        case 0: "sun.max.fill"
        case 1, 2: "cloud.sun.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51, 53, 55, 56, 57: "cloud.drizzle.fill"
        case 65, 67, 82: "cloud.heavyrain.fill"
        case 61, 63, 66, 80, 81: "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: "cloud.snow.fill"
        case 95, 96, 99: "cloud.bolt.rain.fill"
        default: isWet ? "cloud.rain.fill" : "cloud.fill"
        }
    }

    var temperatureText: String {
        "\(Int(temperature.rounded()))°"
    }
}

actor WeatherService {
    static let shared = WeatherService()

    private struct Forecast {
        let fetchedAt: Date
        let times: [Date]
        let temperatures: [Double]
        let precipitation: [Double]
        let codes: [Int]
    }

    private struct Response: Decodable {
        struct Hourly: Decodable {
            let time: [TimeInterval]
            let temperature_2m: [Double?]
            let precipitation: [Double?]
            let weather_code: [Int?]
        }
        let hourly: Hourly
    }

    private var cache: [String: Forecast] = [:]
    private let lifetime: TimeInterval = 20 * 60

    func snapshot(latitude: Double, longitude: Double, at date: Date) async -> WeatherSnapshot? {
        guard abs(date.timeIntervalSinceNow) < 2 * 24 * 3600 else { return nil }
        let lat = (latitude * 50).rounded() / 50
        let lon = (longitude * 50).rounded() / 50
        let key = "\(lat),\(lon)"

        let forecast: Forecast
        if let cached = cache[key], Date().timeIntervalSince(cached.fetchedAt) < lifetime {
            forecast = cached
        } else if let fetched = await fetch(latitude: lat, longitude: lon) {
            cache[key] = fetched
            forecast = fetched
        } else {
            return nil
        }

        guard let index = forecast.times.lastIndex(where: { $0 <= date }) ?? forecast.times.indices.first else { return nil }
        return WeatherSnapshot(
            temperature: forecast.temperatures[index],
            precipitation: forecast.precipitation[index],
            code: forecast.codes[index]
        )
    }

    private func fetch(latitude: Double, longitude: Double) async -> Forecast? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: "temperature_2m,precipitation,weather_code"),
            URLQueryItem(name: "past_days", value: "1"),
            URLQueryItem(name: "forecast_days", value: "3"),
            URLQueryItem(name: "timeformat", value: "unixtime")
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 4

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(Response.self, from: data) else { return nil }

        let hourly = decoded.hourly
        let count = min(hourly.time.count, hourly.temperature_2m.count, hourly.precipitation.count, hourly.weather_code.count)
        var times: [Date] = []
        var temperatures: [Double] = []
        var precipitation: [Double] = []
        var codes: [Int] = []
        for index in 0..<count {
            guard let temperature = hourly.temperature_2m[index] else { continue }
            times.append(Date(timeIntervalSince1970: hourly.time[index]))
            temperatures.append(temperature)
            precipitation.append(hourly.precipitation[index] ?? 0)
            codes.append(hourly.weather_code[index] ?? 0)
        }
        guard !times.isEmpty else { return nil }
        return Forecast(fetchedAt: Date(), times: times, temperatures: temperatures, precipitation: precipitation, codes: codes)
    }
}
