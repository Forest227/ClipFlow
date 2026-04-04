import AppKit
import SwiftUI

// MARK: - Generic Interactive Hosting View (NSView)

final class ClipFlowInteractiveHostingView: NSView {
    private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private var onPrimary: () -> Void = {}
    private var onDoubleTap: (() -> Void)?
    private var onSecondary: () -> Void = {}
    private var pendingSingleClickWorkItem: DispatchWorkItem?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        rootView: AnyView,
        onPrimary: @escaping () -> Void,
        onDoubleTap: (() -> Void)? = nil,
        onSecondary: @escaping () -> Void
    ) {
        hostingView.rootView = rootView
        self.onPrimary = onPrimary
        self.onDoubleTap = onDoubleTap
        self.onSecondary = onSecondary
    }

    override func mouseDown(with event: NSEvent) {
        pendingSingleClickWorkItem?.cancel()
        animatePress(true)

        guard let onDoubleTap else {
            onPrimary()
            animatePress(false)
            return
        }

        if event.clickCount >= 2 {
            onDoubleTap()
            animatePress(false)
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.onPrimary()
        }
        pendingSingleClickWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + ClipFlowMotion.doubleClickDelay, execute: workItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in self?.animatePress(false) }
    }

    private func animatePress(_ pressed: Bool) {
        let scale: CGFloat = pressed ? 0.97 : 1.0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onSecondary()
    }

    override func otherMouseDown(with event: NSEvent) {
        if event.buttonNumber == 2 {
            onSecondary()
        } else {
            super.otherMouseDown(with: event)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        onSecondary()
        return nil
    }
}

// MARK: - Generic NSViewRepresentable Wrapper

struct InteractiveCard: NSViewRepresentable {
    let rootView: AnyView
    let onPrimary: () -> Void
    var onDoubleTap: (() -> Void)?
    let onSecondary: () -> Void

    func makeNSView(context: Context) -> ClipFlowInteractiveHostingView {
        let view = ClipFlowInteractiveHostingView()
        view.update(
            rootView: rootView,
            onPrimary: onPrimary,
            onDoubleTap: onDoubleTap,
            onSecondary: onSecondary
        )
        return view
    }

    func updateNSView(_ nsView: ClipFlowInteractiveHostingView, context: Context) {
        nsView.update(
            rootView: rootView,
            onPrimary: onPrimary,
            onDoubleTap: onDoubleTap,
            onSecondary: onSecondary
        )
    }
}
