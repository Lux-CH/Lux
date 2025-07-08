//
//  KeyboardToolbarViewModel.swift
//  Lux
//
//  Created by Constantin Clerc on 05.05.2025.
//
//  https://gist.github.com/JamesSedlacek/2d0425319e2a854da8c51f4b05c9842a

import SwiftUI
import Combine

@Observable
final class KeyboardToolbarViewModel {
    var isKeyboardVisible = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    self?.isKeyboardVisible = true
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in
                withAnimation(.easeIn(duration: 0.2)) {
                    self?.isKeyboardVisible = false
                }
            }
            .store(in: &cancellables)
    }
}

struct KeyboardToolbar<V: View>: ViewModifier {
    @State private var viewModel: KeyboardToolbarViewModel = .init()
    private let toolbar: V

    init(@ViewBuilder toolbar: () -> V) {
        self.toolbar = toolbar()
    }

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                toolbar
                    .offset(y: viewModel.isKeyboardVisible ? 0 : 100)
                    .opacity(viewModel.isKeyboardVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: viewModel.isKeyboardVisible)
            }
    }
}

extension View {
    func keyboardToolbar<V: View>(view: @escaping () -> V) -> some View {
        modifier(KeyboardToolbar(toolbar: view))
    }
}
