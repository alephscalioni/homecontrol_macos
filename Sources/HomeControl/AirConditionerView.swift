import SwiftUI
import HomeCore

private struct DemoReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var demoReduceMotion: Bool {
        get { self[DemoReduceMotionKey.self] }
        set { self[DemoReduceMotionKey.self] = newValue }
    }
}

struct AirConditionerView: View {
    private static let unitImage: NSImage? = {
        Bundle.module.url(forResource: "air-conditioner", withExtension: "png", subdirectory: "Resources")
            .flatMap { NSImage(contentsOf: $0) }
    }()
    let airflow: ClimateAirflow
    let animated: Bool
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.demoReduceMotion) private var demoReduceMotion
    @State private var visible = false
    @State private var phase = 0.0
    @State private var strength = 0.45
    @State private var lastFrame: Date?
    private var reduceMotion: Bool { systemReduceMotion || demoReduceMotion }
    private var moving: Bool { airflow.isRunning && animated && visible && !reduceMotion }

    var body: some View {
        ZStack(alignment: .top) {
            if airflow.isRunning {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !moving)) { timeline in
                    AirflowCanvas(phase: reduceMotion ? 0.38 : phase,
                                  strength: reduceMotion ? airflow.strength : strength,
                                  sweeping: airflow.sweepsHorizontally && !reduceMotion)
                        .onChange(of: timeline.date) { _, date in advance(to: date) }
                }
            }
            if let image = Self.unitImage {
                Image(nsImage: image).resizable().scaledToFit().frame(width: 224, height: 112)
                    .opacity(airflow.isRunning ? 1 : 0.62).offset(y: -9)
            } else {
                Image(systemName: "air.conditioner.horizontal.fill").font(.system(size: 90)).foregroundStyle(Palette.text)
            }
        }.frame(maxWidth: .infinity).clipped().accessibilityHidden(true)
            .onAppear { visible = true; strength = airflow.strength; lastFrame = nil }
            .onDisappear { visible = false; lastFrame = nil }
            .onChange(of: moving) { _, _ in lastFrame = nil }
    }

    private func advance(to date: Date) {
        guard moving else { lastFrame = nil; return }
        let delta = min(0.1, max(0, lastFrame.map { date.timeIntervalSince($0) } ?? 1.0 / 30))
        lastFrame = date
        // Integrating velocity keeps every ribbon continuous when fan speed changes.
        strength += (airflow.strength - strength) * (1 - exp(-delta * 5))
        phase += delta * (0.16 + strength * 0.34)
    }
}

private struct AirflowCanvas: View {
    let phase: Double
    let strength: Double
    let sweeping: Bool

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let outletWidth = min(166.0, size.width * 0.44)
            let originY = 78.0
            let reach = min(size.height - originY - 2, 24 + strength * 20)
            let count = 15
            let sweep = sweeping ? sin(phase * 1.8) * 12 : 0
            for index in 0..<count {
                let lane = Double(index) / Double(count - 1) - 0.5
                let seed = Double(index)
                let edge = 1 - abs(lane) * 0.65
                func point(_ progress: Double) -> CGPoint {
                    let drift = sin(progress * 2.8 - phase * 2.1 + lane * 1.3) * (1.2 + 2.2 * strength) * progress
                    return CGPoint(x: size.width / 2 + lane * outletWidth * (1 + 0.17 * progress)
                                   + drift + sweep * progress * progress,
                                   y: originY + lane * 3 + progress * reach)
                }
                var trail = Path()
                trail.move(to: point(0))
                for sample in 1...24 { trail.addLine(to: point(Double(sample) / 24)) }
                context.stroke(trail, with: .linearGradient(
                    Gradient(colors: [.white.opacity((0.1 + strength * 0.045) * edge), .white.opacity(0.055 * edge), .clear]),
                    startPoint: CGPoint(x: 0, y: originY), endPoint: CGPoint(x: 0, y: originY + reach)),
                    style: StrokeStyle(lineWidth: 1.4 + strength, lineCap: .round))

                // Long, tapered ribbons share one air current, without dotted particles.
                let head = (phase + seed * 0.083).truncatingRemainder(dividingBy: 1.5)
                let start = head - 0.58
                let lower = max(0, start), upper = min(1, head)
                guard upper > lower else { continue }
                var left: [CGPoint] = [], right: [CGPoint] = []
                for sample in 0...20 {
                    let progress = lower + (upper - lower) * Double(sample) / 20
                    let along = (progress - start) / 0.58
                    let fade = sin(min(1, max(0, along)) * .pi) * pow(1 - progress, 0.6)
                    let halfWidth = (1.4 + strength * 1.35) * fade
                    let center = point(progress)
                    left.append(CGPoint(x: center.x - halfWidth, y: center.y))
                    right.append(CGPoint(x: center.x + halfWidth, y: center.y))
                }
                var ribbon = Path()
                if let first = left.first {
                    ribbon.move(to: first)
                    for point in left.dropFirst() { ribbon.addLine(to: point) }
                    for point in right.reversed() { ribbon.addLine(to: point) }
                    ribbon.closeSubpath()
                }
                context.fill(ribbon, with: .linearGradient(
                    Gradient(colors: [.white.opacity((0.24 + strength * 0.1) * edge), .white.opacity(0.13 * edge), .clear]),
                    startPoint: CGPoint(x: 0, y: originY), endPoint: CGPoint(x: 0, y: originY + reach)))
            }
        }.blur(radius: 1.5)
    }
}
