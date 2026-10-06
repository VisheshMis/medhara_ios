import SwiftUI

/// MedhaActivityRingsView renders elegant concentric activity rings using Medha's exact color palette:
/// - Outer Ring: Daily Focus Goal (Medha Violet / Indigo gradient)
/// - Middle Ring: Weekly Target Progress (Medha Vibrant Notes Blue)
/// - Inner Ring: Session / Streak Consistency (Medha Emerald / Retention Green)
public struct MedhaActivityRingsView: View {
    public let dailyProgress: Double    // 0.0 to 1.0+ (clamped or overflow)
    public let weeklyProgress: Double   // 0.0 to 1.0+
    public let consistencyProgress: Double // 0.0 to 1.0+
    public let size: CGFloat
    public let ringThickness: CGFloat

    public init(
        dailyProgress: Double,
        weeklyProgress: Double,
        consistencyProgress: Double,
        size: CGFloat = 120,
        ringThickness: CGFloat = 11
    ) {
        self.dailyProgress = dailyProgress
        self.weeklyProgress = weeklyProgress
        self.consistencyProgress = consistencyProgress
        self.size = size
        self.ringThickness = ringThickness
    }

    public var body: some View {
        ZStack {
            // Subtle dark background backing ring base
            Circle()
                .fill(MedhaTheme.Colors.bgBase.opacity(0.4))
                .frame(width: size, height: size)

            // Outer Ring: Daily Focus Goal (Medha Violet to Indigo)
            singleRing(
                progress: dailyProgress,
                radius: (size - ringThickness) / 2,
                color: MedhaTheme.Colors.accentStart,
                secondaryColor: MedhaTheme.Colors.accentEnd
            )

            // Middle Ring: Weekly Target Progress (Medha Notes Blue)
            let middleRadius = (size - ringThickness) / 2 - (ringThickness + 2.5)
            if middleRadius > 0 {
                singleRing(
                    progress: weeklyProgress,
                    radius: middleRadius,
                    color: MedhaTheme.Colors.notesAccent,
                    secondaryColor: MedhaTheme.Colors.info
                )
            }

            // Inner Ring: Consistency & Sessions (Medha Emerald Green)
            let innerRadius = (size - ringThickness) / 2 - (ringThickness + 2.5) * 2
            if innerRadius > 0 {
                singleRing(
                    progress: consistencyProgress,
                    radius: innerRadius,
                    color: MedhaTheme.Colors.graphAccent,
                    secondaryColor: MedhaTheme.Colors.success
                )
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private func singleRing(
        progress: Double,
        radius: CGFloat,
        color: Color,
        secondaryColor: Color
    ) -> some View {
        let diameter = radius * 2
        let clamped = max(0.001, min(progress, 1.0))

        ZStack {
            // Track (dimmed background ring)
            Circle()
                .stroke(
                    color.opacity(0.18),
                    style: StrokeStyle(lineWidth: ringThickness, lineCap: .round)
                )
                .frame(width: diameter, height: diameter)

            // Filled Progress Arc
            Circle()
                .trim(from: 0, to: CGFloat(clamped))
                .stroke(
                    LinearGradient(
                        colors: [color, secondaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: ringThickness, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: diameter, height: diameter)
                .shadow(color: color.opacity(0.35), radius: 3, x: 0, y: 1)
        }
    }
}
