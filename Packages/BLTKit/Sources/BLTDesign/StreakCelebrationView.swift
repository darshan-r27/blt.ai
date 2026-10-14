import SwiftUI

/// The end-of-session streak moment: a big flame, the new count, and a burst.
///
/// - `StreakCelebrationStyle` decides how big it is: no burst when the streak did not grow, a keyframe burst
///   and a success haptic when it did, and a bigger burst plus a "7 day milestone" badge at 7, 30, 50 and 100.
/// - Reduce Motion: nothing bounces, tilts or bursts. The number simply fades in (and the badge with it);
///   the haptic still plays, because it is not motion.
/// - VoiceOver reads one element ("8 day streak, 1 freeze left") with the milestone as its value. The flame,
///   the burst and the badge graphic are hidden.
/// - Callers add their own accessibility identifier (`AccessibilityID.sessionStreak`).
public struct StreakCelebrationView: View {
    private let previousCount: Int
    private let count: Int
    private let freezesLeft: Int?
    private let style: StreakCelebrationStyle

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var flameSide: Double = 96
    @ScaledMetric(relativeTo: .largeTitle) private var burstRadius: Double = 84

    /// Bumped once when the view appears (never for a quiet celebration); drives the keyframes and the haptic.
    @State private var playCount = 0
    /// False until the count has rolled (or faded) in.
    @State private var revealed = false

    /// - Parameters:
    ///   - previousCount: the streak before this session; with `count` it picks the style.
    ///   - count: the streak now.
    ///   - freezesLeft: when given, VoiceOver adds "1 freeze left".
    public init(previousCount: Int, count: Int, freezesLeft: Int? = nil) {
        self.previousCount = max(previousCount, 0)
        self.count = max(count, 0)
        self.freezesLeft = freezesLeft
        self.style = StreakCelebrationStyle(previousCount: max(previousCount, 0), count: max(count, 0))
    }

    public var body: some View {
        let palette = Palette(colorScheme)
        VStack(spacing: 12) {
            flame(palette: palette)
            Text("\(displayedCount)")
                .font(.largeTitle.bold().monospacedDigit())
                .foregroundStyle(palette.textPrimaryColor)
                .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(displayedCount)))
                .opacity(reduceMotion && !revealed ? 0 : 1)
            Text("day streak")
                .font(.subheadline)
                .foregroundStyle(palette.textSecondaryColor)
                .multilineTextAlignment(.center)
            if let days = style.milestoneDays {
                milestoneBadge(days: days, palette: palette)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StreakLabels.streak(count: count, freezesLeft: freezesLeft))
        .accessibilityValue(style.milestoneDays.map { "\(StreakLabels.milestone(days: $0)) reached" } ?? "")
        .sensoryFeedback(trigger: playCount) { _, _ in style == .quiet ? nil : .success }
        .task { await play() }
    }

    /// The number rolls from the old count to the new one; with Reduce Motion it shows the new count and fades in.
    private var displayedCount: Int {
        revealed || reduceMotion || style == .quiet ? count : previousCount
    }

    private var isMilestone: Bool { style.milestoneDays != nil }

    private func play() async {
        if style != .quiet {
            playCount += 1
        }
        if reduceMotion {
            withAnimation(.easeIn(duration: 0.5)) { revealed = true }
        } else {
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.snappy) { revealed = true }
        }
    }

    // MARK: Flame and burst

    @ViewBuilder
    private func flame(palette: Palette) -> some View {
        let symbol = Image(systemName: "flame.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(palette.flame.glyphColor)
            .frame(width: flameSide, height: flameSide)
        Group {
            if reduceMotion || style == .quiet {
                symbol
            } else {
                symbol.keyframeAnimator(initialValue: FlameFrame(), trigger: playCount) { content, value in
                    content
                        .scaleEffect(value.scale)
                        .rotationEffect(.degrees(value.tilt))
                } keyframes: { _ in
                    flameKeyframes
                }
            }
        }
        .overlay { burst(palette: palette) }
        .accessibilityHidden(true)
    }

    @KeyframesBuilder<FlameFrame>
    private var flameKeyframes: some Keyframes<FlameFrame> {
        KeyframeTrack(\.scale) {
            SpringKeyframe(isMilestone ? 1.6 : 1.35, duration: 0.25, spring: .bouncy)
            SpringKeyframe(1.0, duration: 0.55, spring: .bouncy)
        }
        KeyframeTrack(\.tilt) {
            CubicKeyframe(-8, duration: 0.15)
            CubicKeyframe(8, duration: 0.2)
            CubicKeyframe(0, duration: 0.3)
        }
    }

    /// Small dots flying outwards and fading. Absent for a quiet celebration and with Reduce Motion.
    @ViewBuilder
    private func burst(palette: Palette) -> some View {
        if style != .quiet, !reduceMotion {
            // Read the main-actor values here: the animator's content closure is Sendable.
            let particleCount = isMilestone ? 16 : 8
            let radius = burstRadius * (isMilestone ? 1.5 : 1.0)
            Color.clear
                .keyframeAnimator(initialValue: 0.0, trigger: playCount) { _, progress in
                    BurstParticles(
                        progress: progress,
                        particleCount: particleCount,
                        radius: radius,
                        colors: [palette.flame.glyphColor, palette.goalMet.glyphColor]
                    )
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(1.0, duration: 0.9)
                    }
                }
                .allowsHitTesting(false)
        }
    }

    // MARK: Milestone badge

    private func milestoneBadge(days: Int, palette: Palette) -> some View {
        Label {
            Text(StreakLabels.milestone(days: days))
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
        } icon: {
            Image(systemName: "rosette")
                .font(.subheadline)
        }
        .foregroundStyle(palette.flame.foregroundColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(palette.flame.backgroundColor, in: Capsule())
        .overlay(Capsule().strokeBorder(palette.flame.glyphColor, lineWidth: 1))
        .opacity(revealed ? 1 : 0)
        .scaleEffect(reduceMotion || revealed ? 1 : 0.6)
    }
}

/// Small dots flying outwards from the centre and fading, `progress` running 0 to 1.
private struct BurstParticles: View {
    let progress: Double
    let particleCount: Int
    let radius: Double
    let colors: [Color]

    var body: some View {
        ZStack {
            ForEach(0..<particleCount, id: \.self) { index in
                let angle = Double(index) / Double(particleCount) * 2 * .pi
                Circle()
                    .fill(colors[index % colors.count])
                    .frame(width: 8, height: 8)
                    .offset(x: cos(angle) * radius * progress, y: sin(angle) * radius * progress)
                    // Invisible at both ends, so nothing flashes when the animation resets.
                    .opacity(sin(.pi * progress))
            }
        }
    }
}

/// The values the flame's keyframe animation moves.
private struct FlameFrame {
    var scale = 1.0
    var tilt = 0.0
}

#if DEBUG
#Preview("Celebration, light (burst)") {
    StreakCelebrationPreviewSample(previousCount: 12, count: 13)
        .preferredColorScheme(.light)
}

#Preview("Celebration, dark (milestone)") {
    StreakCelebrationPreviewSample(previousCount: 29, count: 30)
        .preferredColorScheme(.dark)
}

#Preview("Celebration, largest accessibility size (milestone)") {
    StreakCelebrationPreviewSample(previousCount: 6, count: 7)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Celebration, quiet") {
    StreakCelebrationPreviewSample(previousCount: 13, count: 13)
}

private struct StreakCelebrationPreviewSample: View {
    let previousCount: Int
    let count: Int

    var body: some View {
        ScrollView {
            StreakCelebrationView(previousCount: previousCount, count: count, freezesLeft: 1)
                .padding(.vertical, 60)
                .padding(.horizontal)
        }
        .bltScreenBackground()
    }
}
#endif
