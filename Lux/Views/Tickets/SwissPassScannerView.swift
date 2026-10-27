//
//  SwissPassScannerView.swift
//  Lux
//
//  Created by Constantin Clerc on 02.06.2025.
//

import SwiftUI
import AVFoundation

struct SwissPassScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let onScanSuccess: (String, String) -> Void

    @State private var authorization = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var isProcessing = false
    @State private var didSucceed = false
    @State private var torchOn = false
    @State private var hasTorch = false
    @State private var hint: LocalizedStringKey?
    @State private var hintTask: Task<Void, Never>?

    private static let swissPassQRPrefix = "HTTP://1SP.CH?S="

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                VStack(spacing: 14) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 56))
                        .foregroundStyle(.red)
                        .symbolEffect(.bounce, value: didSucceed)

                    Text("Scannez votre SwissPass")
                        .font(.title2.weight(.bold))

                    Text("Positionnez l'arrière de votre carte SwissPass dans le cadre pour l'ajouter à LuxPass")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 60)

                scannerFrame
                    .padding(.horizontal, 24)

                hintLabel

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                if hasTorch && authorization == .authorized {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            torchOn.toggle()
                            HapticFeedback.lightImpact()
                        } label: {
                            Image(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .accessibilityLabel(Text("Lampe"))
                    }
                }
            }
        }
        .task {
            hasTorch = AVCaptureDevice.default(for: .video)?.hasTorch ?? false
            if authorization == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .video)
                authorization = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
        .onDisappear {
            hintTask?.cancel()
        }
    }

    @ViewBuilder
    private var scannerFrame: some View {
        ZStack {
            switch authorization {
            case .authorized:
                BarcodeCameraView(
                    types: [.qr, .code128],
                    torchOn: torchOn,
                    isPaused: isProcessing,
                    onCode: handle
                )
            case .notDetermined:
                Color.black
            default:
                deniedView
            }

            if isProcessing {
                Color.black.opacity(0.35)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.white, .green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .aspectRatio(85.6 / 54, contentMode: .fit)
        .frame(maxWidth: 420)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(didSucceed ? Color.green : Color.red, lineWidth: 2.5)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isProcessing)
    }

    private var deniedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Lux n'a pas accès à la caméra")
                .font(.subheadline.weight(.semibold))
            Button("Ouvrir les Réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
    }

    @ViewBuilder
    private var hintLabel: some View {
        if let hint {
            Label(hint, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.orange)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.orange.opacity(0.12)))
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func handle(_ scanned: String) {
        guard !isProcessing else { return }
        guard let (qrCode, barcode) = Self.parse(scanned) else {
            showHint("Ce code n'est pas un SwissPass")
            return
        }
        hintTask?.cancel()
        withAnimation {
            hint = nil
            isProcessing = true
            didSucceed = true
        }
        HapticFeedback.notification(type: .success)
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            onScanSuccess(qrCode, barcode)
            dismiss()
        }
    }

    private func showHint(_ text: LocalizedStringKey) {
        guard hint == nil else { return }
        withAnimation { hint = text }
        hintTask?.cancel()
        hintTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation { hint = nil }
        }
    }

    static func parse(_ scanned: String) -> (qrCode: String, barcode: String)? {
        let trimmed = scanned.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = trimmed.uppercased()
        if upper.hasPrefix(swissPassQRPrefix) {
            let code = String(upper.dropFirst(swissPassQRPrefix.count))
            return isValidCode(code) ? (upper, code) : nil
        }
        return isValidCode(upper) ? (swissPassQRPrefix + upper, upper) : nil
    }

    private static func isValidCode(_ code: String) -> Bool {
        code.count == 12 && code.hasPrefix("S") && code.dropFirst().allSatisfy { ("0"..."9").contains($0) }
    }
}

struct BarcodeCameraView: UIViewRepresentable {
    let types: [AVMetadataObject.ObjectType]
    var torchOn: Bool
    var isPaused: Bool
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode)
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = context.coordinator.session
        context.coordinator.previewLayer = view.previewLayer
        view.onLayout = { [weak coordinator = context.coordinator] in
            coordinator?.updateRegion()
        }
        context.coordinator.start(types: types)
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        context.coordinator.onCode = onCode
        context.coordinator.setTorch(torchOn)
        context.coordinator.setPaused(isPaused)
    }

    static func dismantleUIView(_ view: PreviewView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        var onLayout: (() -> Void)?

        override func layoutSubviews() {
            super.layoutSubviews()
            onLayout?()
        }
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
        let session = AVCaptureSession()
        var onCode: (String) -> Void
        weak var previewLayer: AVCaptureVideoPreviewLayer?
        private let output = AVCaptureMetadataOutput()
        private let queue = DispatchQueue(label: "ch.cclerc.lux.barcode-camera")
        private var device: AVCaptureDevice?
        private var isPaused = false
        private var torchOn = false

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func start(types: [AVMetadataObject.ObjectType]) {
            queue.async { [self] in
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: device) else { return }
                self.device = device
                session.beginConfiguration()
                session.sessionPreset = .high
                if session.canAddInput(input) { session.addInput(input) }
                if session.canAddOutput(output) { session.addOutput(output) }
                output.setMetadataObjectsDelegate(self, queue: .main)
                output.metadataObjectTypes = types.filter(output.availableMetadataObjectTypes.contains)
                session.commitConfiguration()
                configureFocus(device)
                session.startRunning()
                DispatchQueue.main.async { [self] in updateRegion() }
            }
        }

        func stop() {
            queue.async { [self] in
                applyTorch(false)
                session.stopRunning()
            }
        }

        func setPaused(_ paused: Bool) {
            isPaused = paused
        }

        func setTorch(_ on: Bool) {
            guard on != torchOn else { return }
            torchOn = on
            queue.async { [self] in applyTorch(on) }
        }

        func updateRegion() {
            guard let layer = previewLayer, session.isRunning else { return }
            let region = layer.metadataOutputRectConverted(fromLayerRect: layer.bounds)
            guard region.width > 0, region.height > 0 else { return }
            queue.async { [self] in output.rectOfInterest = region }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard !isPaused else { return }
            for case let code as AVMetadataMachineReadableCodeObject in objects {
                if let value = code.stringValue, !value.isEmpty {
                    onCode(value)
                    return
                }
            }
        }

        private func configureFocus(_ device: AVCaptureDevice) {
            guard (try? device.lockForConfiguration()) != nil else { return }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }
            if device.minAvailableVideoZoomFactor <= 1.5, device.maxAvailableVideoZoomFactor >= 1.5,
               device.minimumFocusDistance > 150 {
                device.videoZoomFactor = 1.5
            }
            device.unlockForConfiguration()
        }

        private func applyTorch(_ on: Bool) {
            guard let device, device.hasTorch, (try? device.lockForConfiguration()) != nil else { return }
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        }
    }
}
