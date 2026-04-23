import SwiftUI

struct UsageRingView: View {
    let fiveHourPercentage: Double
    let weeklyPercentage: Double
    let size: CGFloat
    let lineWidth: CGFloat

    init(fiveHourPercentage: Double, weeklyPercentage: Double, size: CGFloat = 120, lineWidth: CGFloat? = nil) {
        self.fiveHourPercentage = fiveHourPercentage
        self.weeklyPercentage = weeklyPercentage
        self.size = size
        self.lineWidth = lineWidth ?? (size > 30 ? size * 0.1 : 2.5)
    }

    var body: some View {
        ZStack {
            // Outer ring track (5h)
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Outer ring fill (5h)
            Circle()
                .trim(from: 0, to: fiveHourPercentage)
                .stroke(
                    ringColor(for: fiveHourPercentage),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // Inner ring track (weekly)
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
                .frame(width: innerSize, height: innerSize)

            // Inner ring fill (weekly)
            Circle()
                .trim(from: 0, to: weeklyPercentage)
                .stroke(
                    ringColor(for: weeklyPercentage),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: innerSize, height: innerSize)
                .rotationEffect(.degrees(-90))
        }
        .animation(.easeInOut(duration: 0.6), value: fiveHourPercentage)
        .animation(.easeInOut(duration: 0.6), value: weeklyPercentage)
    }

    private var innerSize: CGFloat {
        size - lineWidth * 2 - (size > 30 ? 4 : 1.5)
    }

    private func ringColor(for percentage: Double) -> Color {
        if percentage > 0.9 {
            return Color(red: 0.95, green: 0.3, blue: 0.3)
        } else if percentage > 0.7 {
            return Color(red: 0.95, green: 0.75, blue: 0.3)
        }
        return Color(red: 0.35, green: 0.65, blue: 1.0)
    }
}
