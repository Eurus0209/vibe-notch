//
//  UsageBarView.swift
//  ClaudeIsland
//
//  Copyright 2026 Hudie LIU.
//  Licensed under the Apache License, Version 2.0 — see LICENSE.md.
//

import SwiftUI

struct UsageBarView: View {
    let percentage: Double
    let timeProgress: Double
    let height: CGFloat
    let width: CGFloat?
    let showTimeMarker: Bool

    init(percentage: Double, timeProgress: Double = 0, height: CGFloat = 6, width: CGFloat? = nil, showTimeMarker: Bool = true) {
        self.percentage = percentage
        self.timeProgress = timeProgress
        self.height = height
        self.width = width
        self.showTimeMarker = showTimeMarker
    }

    var body: some View {
        GeometryReader { geo in
            let barWidth = geo.size.width
            let fillWidth = barWidth * min(max(percentage, 0), 1.0)
            let markerX = barWidth * min(max(timeProgress, 0), 1.0)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.white.opacity(0.32))
                    .frame(height: height)
                    .overlay(
                        RoundedRectangle(cornerRadius: height / 2)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                    )

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(barColor)
                    .frame(width: max(fillWidth, height), height: height)

                if showTimeMarker && timeProgress > 0.01 && timeProgress < 0.99 {
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 1.5, height: height + 4)
                        .offset(x: markerX - 0.75)
                }
            }
        }
        .frame(width: width, height: height + 4)
        .animation(.easeInOut(duration: 0.6), value: percentage)
        .animation(.easeInOut(duration: 0.6), value: timeProgress)
    }

    private var barColor: Color {
        let green = Color(red: 0.35, green: 0.80, blue: 0.45)
        let orange = Color(red: 0.95, green: 0.70, blue: 0.25)
        let red = Color(red: 0.95, green: 0.30, blue: 0.30)

        if percentage >= 0.80 { return red }
        if percentage < 0.15 { return green }

        let delta = percentage - timeProgress  // positive ⇒ ahead of pace
        if delta > 0.10 { return red }
        if delta >= 0 { return orange }
        return green
    }
}
