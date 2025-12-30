// UsageExample.swift
// Example of using SplineInterpolation with Swift Charts

import SwiftUI
import Charts

// MARK: - Weight Chart View

struct WeightChartWithInterpolation: View {
    let entries: [WeightEntry]
    let method: InterpolationMethod

    var body: some View {
        let provider = WeightChartDataProvider(entries: entries)
        let smoothed = provider.smoothedCurve(method: method, pointCount: 100)

        Chart {
            ForEach(smoothed) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight)
                )
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(.blue)
            }

            ForEach(entries) { entry in
                PointMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.weight)
                )
                .foregroundStyle(.white)
                .symbolSize(50)
            }
        }
    }
}

// MARK: - Basic Usage

struct BasicUsageExample {
    func run() throws {
        let x = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]
        let y = [1.0, 2.0, 1.5, 3.0, 2.5, 4.0]

        // Throwing initializer
        let spline = try CubicSplineInterpolator(x: x, y: y)
        let pchip = try PCHIPInterpolator(x: x, y: y)
        let akima = try AkimaInterpolator(x: x, y: y)

        // Interpolate
        print("Cubic: \(spline.interpolate(at: 2.5))")
        print("PCHIP: \(pchip.interpolate(at: 2.5))")
        print("Akima: \(akima.interpolate(at: 2.5))")

        // Generate curve
        let curve = spline.generatePoints(count: 100)
        print("Points: \(curve.count)")
    }
}

// MARK: - Time Series Usage

struct TimeSeriesExample {
    func run() throws {
        let now = Date()
        let points = [
            TimeSeriesPoint(date: now, value: 70.0),
            TimeSeriesPoint(date: now.addingTimeInterval(86400), value: 69.5),
            TimeSeriesPoint(date: now.addingTimeInterval(172800), value: 69.0),
        ]

        let interpolator = try TimeSeriesInterpolator(points: points, method: .pchip)
        let smoothed = interpolator.smoothedPoints(count: 50)
        print("Smoothed points: \(smoothed.count)")
    }
}

// MARK: - Unchecked Usage (Non-throwing)

struct UncheckedExample {
    func run() {
        let x = [0.0, 1.0, 2.0, 3.0]
        let y = [1.0, 2.0, 1.5, 3.0]

        let spline = CubicSplineInterpolator(xUnchecked: x, yUnchecked: y)

        if spline.isValid {
            let value = spline.interpolate(at: 1.5)
            print("Value: \(value)")
        }
    }
}
