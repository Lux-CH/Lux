//
//  TrainFormationView.swift
//  Lux
//
//  Created by Constantin Clerc on 24.09.2026.
//

import SwiftUI

struct TrainFormationView: View {
    let formation: TrainFormation
    var platformSectors: [String] = []

    @State private var page = 0
    @State private var availableWidth: CGFloat = 320

    static let secondClass = Color(hex: "2E45A8")
    static let firstClass = Color(red: 0.8, green: 0.12, blue: 0.16)
    static let gap: CGFloat = 3
    static let coachHeight: CGFloat = 30

    private var pages: [FormationPage] {
        var pages: [FormationPage] = [.classes]
        if formation.coaches.contains(where: { !$0.services.isEmpty }) { pages.append(.services) }
        if formation.occupancy?.isKnown == true { pages.append(.occupancy) }
        return pages
    }

    var body: some View {
        let layout = FormationLayout(formation: formation, platformSectors: platformSectors, availableWidth: availableWidth)
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    SectorRuler(sectors: layout.sectors, total: layout.total)
                    TrainRow(blocks: layout.blocks, labels: layout.labels(on: pages[page % pages.count]), total: layout.total)
                    RailTrack()
                        .fill(.secondary.opacity(0.45))
                        .frame(width: layout.total, height: 5)
                }
                .overlay(alignment: .leading) {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .offset(x: layout.trainCenter)
                        .id("train")
                }
                .frame(minWidth: availableWidth, alignment: .leading)
            }
            .scrollDisabled(layout.total <= availableWidth)
            .onAppear { proxy.scrollTo("train", anchor: .center) }
            .onChange(of: layout.trainCenter) { _, _ in proxy.scrollTo("train", anchor: .center) }
        }
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { availableWidth = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .task(id: formation) {
            let count = pages.count
            guard count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                withAnimation(.smooth(duration: 0.6)) { page = (page + 1) % count }
            }
        }
    }

    private var accessibilityText: String {
        let sectors = formation.sectors
        var parts: [String] = []
        if !sectors.first.isEmpty {
            parts.append(String(localized: "1re classe secteur \(TrainFormation.sectorText(sectors.first))"))
        }
        if !sectors.second.isEmpty {
            parts.append(String(localized: "2e classe secteur \(TrainFormation.sectorText(sectors.second))"))
        }
        if !sectors.restaurant.isEmpty {
            parts.append(String(localized: "restaurant secteur \(TrainFormation.sectorText(sectors.restaurant))"))
        }
        if !sectors.bike.isEmpty {
            parts.append(String(localized: "vélos secteur \(TrainFormation.sectorText(sectors.bike))"))
        }
        if !sectors.wheelchair.isEmpty {
            parts.append(String(localized: "fauteuils roulants secteur \(TrainFormation.sectorText(sectors.wheelchair))"))
        }
        if let occupancy = formation.occupancy {
            if let first = occupancy.first { parts.append(String(localized: "1re classe \(FormationOccupancy.text(first))")) }
            if let second = occupancy.second { parts.append(String(localized: "2e classe \(FormationOccupancy.text(second))")) }
        }
        return parts.joined(separator: ", ")
    }
}

enum FormationPage {
    case classes, services, occupancy
}

enum FormationOccupancy {
    static func text(_ level: Int) -> String {
        switch level {
        case 1: return String(localized: "places libres")
        case 2: return String(localized: "peu de places libres")
        default: return String(localized: "places debout uniquement")
        }
    }
}

struct OccupancyForecastRow: View {
    let occupancy: TrainFormation.Occupancy

    var body: some View {
        HStack(spacing: 14) {
            Label("Affluence prévue", systemImage: "person.2.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            if let first = occupancy.first { entry("1", level: first, color: TrainFormationView.firstClass) }
            if let second = occupancy.second { entry("2", level: second, color: TrainFormationView.secondClass) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    private func entry(_ travelClass: String, level: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            Text(travelClass)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(color, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            PeopleLevel(level: level, size: 11)
                .foregroundStyle(.primary)
        }
    }

    private var accessibilityText: String {
        var parts = [String(localized: "Affluence prévue")]
        if let first = occupancy.first { parts.append(String(localized: "1re classe \(FormationOccupancy.text(first))")) }
        if let second = occupancy.second { parts.append(String(localized: "2e classe \(FormationOccupancy.text(second))")) }
        return parts.joined(separator: ", ")
    }
}

struct PeopleLevel: View {
    let level: Int
    let size: CGFloat

    var body: some View {
        HStack(spacing: size < 10 ? 0 : 1) {
            ForEach(1...3, id: \.self) { index in
                Image(systemName: "person.fill")
                    .opacity(index <= level ? 1 : 0.3)
            }
        }
        .font(.system(size: size, weight: .bold))
        .fixedSize()
    }
}

private struct FormationLayout {
    struct Span {
        let x: CGFloat
        let width: CGFloat
    }

    struct Block {
        let id: Int
        let coaches: [TrainFormation.Coach]
        let widths: [CGFloat]
        let span: Span
        let isFront: Bool
        let isRear: Bool
    }

    struct Label {
        let id: String
        let span: Span
        let content: RunLabel.Content
    }

    struct Sector {
        let id: Int
        let letter: String?
        let span: Span
        let isCovered: Bool
    }

    let coaches: [TrainFormation.Coach]
    let occupancy: TrainFormation.Occupancy?
    let blocks: [Block]
    let sectors: [Sector]
    let total: CGFloat
    let trainCenter: CGFloat
    private let x: [CGFloat]
    private let widths: [CGFloat]

    init(formation: TrainFormation, platformSectors: [String], availableWidth: CGFloat) {
        let coaches = formation.coaches
        self.coaches = coaches
        self.occupancy = formation.occupancy
        let blockRanges: [ClosedRange<Int>] = Self.runs(of: coaches.map { Optional($0.bodyKind) })

        let units: CGFloat = coaches.reduce(0) { $0 + ($1.isLocomotive ? 0.75 : 1) }
        let gaps = CGFloat(max(0, blockRanges.count - 1)) * TrainFormationView.gap

        let lettered = coaches.compactMap(\.s)
        var axis = Array(Set(platformSectors + lettered)).sorted()
        if let first = lettered.first, let last = lettered.last, first > last { axis.reverse() }
        let firstIndex = lettered.first.flatMap { axis.firstIndex(of: $0) } ?? 0
        let lastIndex = lettered.last.flatMap { axis.firstIndex(of: $0) } ?? max(0, axis.count - 1)
        let spanned = CGFloat(abs(lastIndex - firstIndex) + 1)
        let sectorCount = CGFloat(max(axis.count, 1))

        let minimumCoach: CGFloat = 18
        let sectorWidth = max(availableWidth / sectorCount, (minimumCoach * units + gaps) / spanned)
        var trainStart = CGFloat(min(firstIndex, lastIndex)) * sectorWidth
        var trainLength = spanned * sectorWidth
        var coachWidth = (trainLength - gaps) / max(units, 1)
        if coachWidth > 40 {
            coachWidth = 40
            let length = 40 * units + gaps
            trainStart += (trainLength - length) / 2
            trainLength = length
        }

        var x: [CGFloat] = []
        var widths: [CGFloat] = []
        var cursor: CGFloat = trainStart
        for range in blockRanges {
            for index in range {
                let width: CGFloat = coaches[index].isLocomotive ? (coachWidth * 0.75).rounded() : coachWidth
                x.append(cursor)
                widths.append(width)
                cursor += width
            }
            cursor += TrainFormationView.gap
        }
        self.x = x
        self.widths = widths
        self.total = axis.isEmpty ? max(0, cursor - TrainFormationView.gap) : sectorCount * sectorWidth
        self.trainCenter = trainStart + trainLength / 2

        var blocks: [Block] = []
        for (offset, range) in blockRanges.enumerated() {
            blocks.append(Block(
                id: offset,
                coaches: Array(coaches[range]),
                widths: Array(widths[range]),
                span: Self.span(range, x: x, widths: widths),
                isFront: offset == 0,
                isRear: offset == blockRanges.count - 1
            ))
        }
        self.blocks = blocks

        let covered = formation.coveredSectors
        self.sectors = axis.enumerated().map { index, letter in
            Sector(
                id: index,
                letter: letter,
                span: Span(x: CGFloat(index) * sectorWidth, width: sectorWidth),
                isCovered: covered.contains(letter)
            )
        }
    }

    func labels(on page: FormationPage) -> [Label] {
        let contents: [RunLabel.Content?] = coaches.map { Self.content(of: $0, on: page, occupancy: occupancy) }
        var labels: [Label] = []
        for range in Self.runs(of: contents) {
            guard let content = contents[range.lowerBound] else { continue }
            labels.append(Label(
                id: "\(range.lowerBound)-\(range.upperBound)-\(content.key)",
                span: Self.span(range, x: x, widths: widths),
                content: content
            ))
        }
        return labels
    }

    static func content(of coach: TrainFormation.Coach, on page: FormationPage, occupancy: TrainFormation.Occupancy?) -> RunLabel.Content? {
        if coach.isLocomotive || coach.closed { return nil }
        if page == .services, !coach.services.isEmpty { return .services(coach.services) }
        if page == .occupancy, let level = occupancy?.level(for: coach) { return .occupancy(level) }
        if coach.isRestaurant { return .services(["fork.knife"]) }
        return .text(coach.t == "12" ? "1·2" : coach.t == "FA" ? "2" : coach.t)
    }

    static func runs<Key: Equatable>(of keys: [Key?]) -> [ClosedRange<Int>] {
        var runs: [ClosedRange<Int>] = []
        for (index, key) in keys.enumerated() {
            if let last = runs.last, key != nil, keys[last.upperBound] == key, last.upperBound == index - 1 {
                runs[runs.count - 1] = last.lowerBound...index
            } else {
                runs.append(index...index)
            }
        }
        return runs
    }

    static func span(_ range: ClosedRange<Int>, x: [CGFloat], widths: [CGFloat]) -> Span {
        let start = x[range.lowerBound]
        return Span(x: start, width: x[range.upperBound] + widths[range.upperBound] - start)
    }
}

private struct SectorRuler: View {
    let sectors: [FormationLayout.Sector]
    let total: CGFloat

    private var ticks: [CGFloat] {
        guard let first = sectors.first, let last = sectors.last else { return [] }
        var ticks: [CGFloat] = [first.span.x]
        for (previous, next) in zip(sectors, sectors.dropFirst()) {
            ticks.append((previous.span.x + previous.span.width + next.span.x) / 2)
        }
        ticks.append(last.span.x + last.span.width)
        return ticks
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ZStack(alignment: .topLeading) {
                ForEach(sectors, id: \.id) { sector in
                    if let letter = sector.letter {
                        SectorChipView(letter: letter, covered: sector.isCovered ? nil : false, firstClass: false)
                            .frame(width: sector.span.width)
                            .offset(x: sector.span.x)
                    }
                }
            }
            .frame(width: total, alignment: .topLeading)
            SectorRulerLine(ticks: ticks)
                .stroke(.secondary.opacity(0.7), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                .frame(width: total, height: 7)
        }
    }
}

private struct TrainRow: View {
    let blocks: [FormationLayout.Block]
    let labels: [FormationLayout.Label]
    let total: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(blocks, id: \.id) { block in
                BlockBody(coaches: block.coaches, widths: block.widths, isFront: block.isFront, isRear: block.isRear)
                    .frame(width: block.span.width, height: TrainFormationView.coachHeight)
                    .offset(x: block.span.x)
            }
            ForEach(labels, id: \.id) { label in
                RunLabel(content: label.content)
                    .frame(width: label.span.width, height: TrainFormationView.coachHeight)
                    .offset(x: label.span.x)
                    .transition(.asymmetric(insertion: .move(edge: .top), removal: .move(edge: .bottom)))
            }
        }
        .frame(width: total, height: TrainFormationView.coachHeight, alignment: .topLeading)
        .clipped()
    }
}

private extension TrainFormation.Coach {
    var services: [String] {
        var symbols: [String] = []
        if isRestaurant { symbols.append("fork.knife") }
        if o.contains("wheelchair") { symbols.append("figure.roll") }
        if o.contains("bike") { symbols.append("bicycle") }
        if t == "FA" || o.contains("family") { symbols.append("figure.2.and.child.holdinghands") }
        return symbols
    }

    var bodyKind: String {
        let kind = isLocomotive ? "L" : t == "12" ? "M" : isFirstClass ? "1" : "2"
        return closed ? kind + "-" : kind
    }
}

private struct BlockBody: View {
    let coaches: [TrainFormation.Coach]
    let widths: [CGFloat]
    let isFront: Bool
    let isRear: Bool

    var body: some View {
        let coach = coaches[0]
        Group {
            if coach.isLocomotive {
                Color(white: 0.32)
            } else if coach.closed {
                Color(white: 0.55)
            } else if coach.t == "12" {
                HStack(spacing: 0) {
                    ForEach(widths.indices, id: \.self) { index in
                        HStack(spacing: 0) {
                            TrainFormationView.firstClass
                            TrainFormationView.secondClass
                        }
                        .frame(width: widths[index])
                    }
                }
            } else {
                coach.isFirstClass ? TrainFormationView.firstClass : TrainFormationView.secondClass
            }
        }
        .clipShape(CoachShape(slantsLeading: isFront, slantsTrailing: isRear))
    }
}

private struct RunLabel: View {
    enum Content: Equatable {
        case text(String)
        case services([String])
        case occupancy(Int)

        var key: String {
            switch self {
            case .text(let text): "t" + text
            case .services(let symbols): "s" + symbols.joined(separator: ",")
            case .occupancy(let level): "o\(level)"
            }
        }
    }

    let content: Content

    var body: some View {
        Group {
            switch content {
            case .text(let text):
                Text(text)
                    .font(.system(size: text.count > 1 ? 12 : 15, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.7)
            case .occupancy(let level):
                ViewThatFits(in: .horizontal) {
                    PeopleLevel(level: level, size: 11)
                    PeopleLevel(level: level, size: 8)
                    HStack(spacing: 1) {
                        Image(systemName: "person.fill")
                        Text("\(level)")
                    }
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                }
            case .services(let symbols):
                ViewThatFits(in: .horizontal) {
                    symbolRow(symbols.prefix(3), size: 12)
                    symbolRow(symbols.prefix(3), size: 9)
                    symbolRow(symbols.prefix(2), size: 9)
                    symbolRow(symbols.prefix(1), size: 9)
                    symbolRow(symbols.prefix(1), size: 7)
                }
            }
        }
        .lineLimit(1)
        .foregroundStyle(.white)
        .padding(.horizontal, 2)
    }

    private func symbolRow(_ symbols: ArraySlice<String>, size: CGFloat) -> some View {
        HStack(spacing: size < 10 ? 2 : 3) {
            ForEach(Array(symbols), id: \.self) { symbol in
                Image(systemName: symbol)
            }
        }
        .font(.system(size: size, weight: .bold))
        .fixedSize()
    }
}

private struct CoachShape: Shape {
    let slantsLeading: Bool
    let slantsTrailing: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 4
        let slant: CGFloat = min(8, rect.width * 0.35)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + (slantsLeading ? slant : radius), y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - (slantsTrailing ? slant : radius), y: rect.minY))
        if slantsTrailing {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + slant))
        } else {
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control: CGPoint(x: rect.minX, y: rect.maxY))
        if slantsLeading {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + slant))
        } else {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        }
        path.closeSubpath()
        return path
    }
}

private struct SectorRulerLine: Shape {
    let ticks: [CGFloat]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = ticks.first, let last = ticks.last else { return path }
        let inset: (CGFloat) -> CGFloat = { min(max($0, rect.minX + 1), rect.maxX - 1) }
        path.move(to: CGPoint(x: inset(first), y: rect.midY))
        path.addLine(to: CGPoint(x: inset(last), y: rect.midY))
        for x in ticks {
            path.move(to: CGPoint(x: inset(x), y: rect.minY))
            path.addLine(to: CGPoint(x: inset(x), y: rect.maxY))
        }
        return path
    }
}

private struct RailTrack: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(CGRect(x: rect.minX, y: rect.midY - 0.6, width: rect.width, height: 1.2))
        var x = rect.minX + 2
        while x < rect.maxX - 1 {
            path.addRect(CGRect(x: x, y: rect.minY, width: 1, height: rect.height))
            x += 5
        }
        return path
    }
}

struct SectorChipView: View {
    let letter: String
    let covered: Bool?
    let firstClass: Bool

    var body: some View {
        Text(letter)
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(StationStyle.signBlue)
            .frame(width: 17, height: 17)
            .background(Circle().fill(.white))
            .overlay(alignment: .top) {
                if firstClass {
                    Circle()
                        .trim(from: 0.6, to: 0.9)
                        .stroke(Color(red: 0.99, green: 0.8, blue: 0.1), lineWidth: 3)
                        .frame(width: 17, height: 17)
                }
            }
            .overlay(Circle().stroke(StationStyle.signBlue, lineWidth: 1.2))
            .opacity(covered == false ? 0.4 : 1)
            .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
            .environment(\.colorScheme, .light)
            .accessibilityLabel(Text(String(localized: "Secteur \(letter)")))
    }
}
