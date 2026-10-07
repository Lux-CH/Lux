//
//  IntelligenceSetupView.swift
//  Lux
//
//  Created by Constantin Clerc on 01.10.2026.
//

import SwiftUI

struct IntelligenceSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var draft: IntelligenceProfile
    @State private var step: Int
    @State private var isForward = true
    @State private var glyphTrigger = 0
    @State private var isEditingFromSummary = false
    @State private var dragOffset: CGFloat = 0
    @State private var answered: Set<String> = []

    private let questions = IntelligenceQuestion.all
    private let introStep = -1

    init() {
        let profile = IntelligenceStore.shared.profile
        _draft = State(initialValue: profile)
        _step = State(initialValue: profile.isConfigured ? IntelligenceQuestion.all.count : -1)
    }

    private var accent: Color { Color.luxAccent }
    private var isIntro: Bool { step == introStep }
    private var isSummary: Bool { step >= questions.count }
    private var isQuestion: Bool { !isIntro && !isSummary }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 16)
                .padding(.top, 14)

            ZStack {
                if isIntro {
                    intro
                        .transition(transition)
                } else if isSummary {
                    summary
                        .transition(transition)
                } else {
                    questionPage(questions[step])
                        .id(step)
                        .transition(transition)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .offset(x: dragOffset)
            .contentShape(Rectangle())
            .simultaneousGesture(swipe)
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .background(background)
    }

    private var background: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
            RadialGradient(
                colors: [accent.opacity(colorScheme == .dark ? 0.28 : 0.18), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 420
            )
            .frame(height: 420)
        }
        .ignoresSafeArea()
    }

    private var transition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: isForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: isForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private var topBar: some View {
        VStack(spacing: 14) {
            HStack {
                circleButton(symbol: isQuestion && step > 0 ? "chevron.left" : "xmark") {
                    if isQuestion && step > 0 {
                        go(to: step - 1)
                    } else {
                        dismiss()
                    }
                }

                Spacer()

                if isQuestion {
                    Text("\(step + 1) sur \(questions.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }

                Spacer()

                Button("Passer") { go(to: nextStep(after: step)) }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .opacity(isQuestion ? 1 : 0)
                    .disabled(!isQuestion)
                    .frame(width: 60, alignment: .trailing)
            }

            if isQuestion {
                HStack(spacing: 5) {
                    ForEach(questions.indices, id: \.self) { index in
                        Capsule()
                            .fill(index <= step ? accent : Color.primary.opacity(0.1))
                            .frame(height: 4)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
    }

    private func circleButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(Color(.tertiarySystemFill), in: Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(ScaleButtonStyle())
        .frame(width: 60, alignment: .leading)
    }

    @ViewBuilder
    private var bottomBar: some View {
        if isIntro {
            VStack(spacing: 10) {
                primaryButton(String(localized: "Commencer")) { go(to: 0) }
                Text("Moins d'une minute")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        } else if isSummary {
            VStack(spacing: 6) {
                primaryButton(String(localized: "Enregistrer")) {
                    draft.isConfigured = true
                    IntelligenceStore.shared.profile = draft
                    dismiss()
                }
                Button {
                    HapticFeedback.lightImpact()
                    draft = IntelligenceProfile()
                    answered = []
                    isEditingFromSummary = false
                    go(to: 0)
                } label: {
                    Text("Recommencer")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(accent)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .background(
                LinearGradient(colors: [Color(.systemGroupedBackground).opacity(0), Color(.systemGroupedBackground)], startPoint: .top, endPoint: .center)
                    .ignoresSafeArea()
            )
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticFeedback.mediumImpact()
            action()
        } label: {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(accent, in: Capsule())
                .shadow(color: accent.opacity(0.35), radius: 14, y: 6)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func glyph(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [accent, accent.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
                .shadow(color: accent.opacity(0.4), radius: size / 5, y: size / 12)
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: glyphTrigger)
        }
        .onAppear { glyphTrigger += 1 }
    }

    private var intro: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 14) {
                    glyph(size: 92)
                        .padding(.top, 24)
                    Text("Magic")
                        .font(.largeTitle.weight(.bold))
                    Text("Le bon trajet, pas seulement le plus rapide. Quelques questions pour qu'il vous ressemble.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 20) {
                    featureRow(symbol: "cloud.sun.rain.fill", title: "Météo", detail: "Moins de marche quand il pleut, fait froid ou trop chaud")
                    featureRow(symbol: "person.3.fill", title: "Affluence", detail: "Évite les véhicules signalés bondés par la communauté")
                    featureRow(symbol: "heart.fill", title: "Habitudes", detail: "Privilégie les lignes que vous prenez déjà")
                    featureRow(symbol: "arrow.triangle.swap", title: "Trajets directs", detail: "Attend un bus direct quand ça vaut le coup")
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func featureRow(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 40, height: 40)
                .background(accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func questionPage(_ question: IntelligenceQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: question.symbol)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 56, height: 56)
                        .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .padding(.bottom, 4)
                    Text(question.label)
                        .font(.system(size: 13, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(accent)
                    Text(question.title)
                        .font(.title.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(question.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if question.options.count == 4 {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(question.options) { option in
                            optionTile(option, in: question)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        ForEach(question.options) { option in
                            optionRow(option, in: question)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
            .padding(.bottom, 32)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func showsSelected(_ option: IntelligenceQuestion.Option, in question: IntelligenceQuestion) -> Bool {
        (draft.isConfigured || answered.contains(question.id)) && option.isSelected(draft)
    }

    private func select(_ option: IntelligenceQuestion.Option, in question: IntelligenceQuestion) {
        HapticFeedback.lightImpact()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            option.apply(&draft)
            answered.insert(question.id)
        }
        let current = step
        Task {
            try? await Task.sleep(for: .milliseconds(320))
            if step == current { go(to: nextStep(after: current)) }
        }
    }

    private func optionBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(isSelected ? accent.opacity(0.12) : Color(.secondarySystemGroupedBackground))
            .stroke(isSelected ? accent : Color.primary.opacity(0.06), lineWidth: isSelected ? 1.5 : 0.5)
    }

    private func optionIcon(_ symbol: String, isSelected: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(isSelected ? .white : accent)
            .frame(width: 44, height: 44)
            .background(isSelected ? accent : accent.opacity(0.12), in: Circle())
    }

    private func optionRow(_ option: IntelligenceQuestion.Option, in question: IntelligenceQuestion) -> some View {
        let isSelected = showsSelected(option, in: question)
        return Button { select(option, in: question) } label: {
            HStack(spacing: 14) {
                optionIcon(option.symbol, isSelected: isSelected)
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(option.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? accent : Color.primary.opacity(0.15))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(16)
            .background(optionBackground(isSelected: isSelected))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func optionTile(_ option: IntelligenceQuestion.Option, in question: IntelligenceQuestion) -> some View {
        let isSelected = showsSelected(option, in: question)
        return Button { select(option, in: question) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    optionIcon(option.symbol, isSelected: isSelected)
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(accent)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(option.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            .background(optionBackground(isSelected: isSelected))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var summary: some View {
        ScrollView {
            VStack(spacing: 26) {
                VStack(spacing: 12) {
                    glyph(size: 68)
                        .padding(.top, 16)
                    Text("Votre Intelligent")
                        .font(.title.weight(.bold))
                    Text("Combiné à la météo, à l'affluence signalée et à vos lignes habituelles. Touchez une carte pour la modifier.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                        summaryTile(question) {
                            HapticFeedback.lightImpact()
                            isEditingFromSummary = true
                            go(to: index)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func summaryTile(_ question: IntelligenceQuestion, action: @escaping () -> Void) -> some View {
        let option = question.options.first { $0.isSelected(draft) }
        return Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: option?.symbol ?? question.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 34, height: 34)
                        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Spacer(minLength: 0)
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(question.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    if let option {
                        Text(option.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var canSwipeForward: Bool { !isSummary }
    private var canSwipeBack: Bool { !isIntro && !(isQuestion && step == 0 && draft.isConfigured) }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                let dx = value.translation.width
                guard abs(dx) > abs(value.translation.height) * 1.2 else { return }
                let allowed = dx < 0 ? canSwipeForward : canSwipeBack
                dragOffset = allowed ? dx * 0.6 : dx * 0.15
            }
            .onEnded { value in
                let dx = value.translation.width
                let projected = value.predictedEndTranslation.width
                let isHorizontal = abs(dx) > abs(value.translation.height) * 1.2
                if isHorizontal, (dx < -70 || projected < -180), canSwipeForward {
                    HapticFeedback.lightImpact()
                    dragOffset = 0
                    go(to: nextStep(after: step))
                } else if isHorizontal, (dx > 70 || projected > 180), canSwipeBack {
                    HapticFeedback.lightImpact()
                    dragOffset = 0
                    goBack()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func goBack() {
        if isSummary {
            isEditingFromSummary = false
            go(to: questions.count - 1)
        } else {
            go(to: step - 1)
        }
    }

    private func nextStep(after current: Int) -> Int {
        isEditingFromSummary ? questions.count : current + 1
    }

    private func go(to target: Int) {
        let clamped = max(introStep, min(target, questions.count))
        guard clamped != step else { return }
        isForward = clamped > step
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            step = clamped
        }
    }
}
