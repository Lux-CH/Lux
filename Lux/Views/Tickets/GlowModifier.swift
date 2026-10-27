//
//  GlowModifier.swift
//  Lux
//
//  Created by Constantin Clerc on 27.10.2026.
//

import SwiftUI
import Metal
import QuartzCore

extension View {
    func glow(_ intensity: Double = 1.0) -> some View {
        overlay {
            GlowLayerView(intensity: intensity)
                .blendMode(.multiply)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct GlowLayerView: UIViewRepresentable {
    let intensity: Double

    func makeUIView(context: Context) -> GlowView {
        GlowView()
    }

    func updateUIView(_ view: GlowView, context: Context) {
        view.intensity = intensity
    }

    final class GlowView: UIView {
        override class var layerClass: AnyClass { CAMetalLayer.self }
        private var metalLayer: CAMetalLayer { layer as! CAMetalLayer }
        private let commandQueue: MTLCommandQueue?
        private var renderedSize: CGSize = .zero
        private var renderedGain: Double = 0

        var intensity: Double = 1 {
            didSet { if intensity != oldValue { render(force: true) } }
        }

        override init(frame: CGRect) {
            let device = MTLCreateSystemDefaultDevice()
            commandQueue = device?.makeCommandQueue()
            super.init(frame: frame)
            isOpaque = false
            isUserInteractionEnabled = false
            metalLayer.device = device
            metalLayer.pixelFormat = .rgba16Float
            metalLayer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
            metalLayer.wantsExtendedDynamicRangeContent = true
            metalLayer.isOpaque = false
            metalLayer.framebufferOnly = true
            metalLayer.compositingFilter = "multiplyBlendMode"
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            render(force: true)
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            render(force: false)
        }

        private var gain: Double {
            let headroom = Double(window?.screen.potentialEDRHeadroom ?? 1)
            return 1 + (min(headroom, 4) - 1) * max(0, min(intensity, 1))
        }

        private func render(force: Bool) {
            guard window != nil, let commandQueue else { return }
            let scale = window?.screen.scale ?? 2
            let size = CGSize(width: (bounds.width * scale).rounded(), height: (bounds.height * scale).rounded())
            guard size.width >= 1, size.height >= 1 else { return }
            let gain = gain
            guard force || size != renderedSize || gain != renderedGain else { return }

            metalLayer.drawableSize = size
            guard let drawable = metalLayer.nextDrawable(),
                  let buffer = commandQueue.makeCommandBuffer() else { return }

            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = drawable.texture
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor = MTLClearColor(red: gain, green: gain, blue: gain, alpha: 1)
            buffer.makeRenderCommandEncoder(descriptor: pass)?.endEncoding()
            buffer.present(drawable)
            buffer.commit()

            renderedSize = size
            renderedGain = gain
        }
    }
}
