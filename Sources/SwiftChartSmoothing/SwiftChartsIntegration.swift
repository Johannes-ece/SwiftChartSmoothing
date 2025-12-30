// SwiftChartsIntegration.swift
// Integration with Swift Charts for weight/time series data
//
// Usage: Add this file alongside SplineInterpolation.swift

import Foundation

#if canImport(Charts)
import Charts
import SwiftUI

// MARK: - Time Series Data Point

/// A data point with Date (for time series like weight tracking)
public struct TimeSeriesPoint: InterpolatablePoint, Identifiable {
    public let id = UUID()
    public let date: Date
    public let value: Double
    
    // For interpolation, we use timestamp as x
    public var x: Double { date.timeIntervalSince1970 }
    public var y: Double { value }
    
    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

/// Interpolated point with Date
public struct InterpolatedTimePoint: Identifiable {
    public let id = UUID()
    public let date: Date
    public let value: Double
    
    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

// MARK: - Time Series Interpolator

/// Convenience class for interpolating time series data
public class TimeSeriesInterpolator {
    private let points: [TimeSeriesPoint]
    private let interpolator: SplineInterpolator

    /// Whether the interpolator has valid data
    public var isValid: Bool { interpolator.isValid }

    /// Throwing initializer for strict error handling
    public init(points: [TimeSeriesPoint], method: InterpolationMethod = .cubicSpline) throws {
        self.points = points.sorted { $0.date < $1.date }
        self.interpolator = try createInterpolator(points: self.points, method: method)
    }

    /// Non-throwing initializer (returns invalid interpolator on error)
    public init(pointsUnchecked points: [TimeSeriesPoint], method: InterpolationMethod = .cubicSpline) {
        self.points = points.sorted { $0.date < $1.date }
        self.interpolator = createInterpolatorUnchecked(points: self.points, method: method)
    }
    
    /// Get interpolated value at a specific date
    public func value(at date: Date) -> Double {
        return interpolator.interpolate(at: date.timeIntervalSince1970)
    }
    
    /// Generate smoothed curve points
    public func smoothedPoints(count: Int) -> [InterpolatedTimePoint] {
        guard isValid, points.count >= 2, count >= 2 else { return [] }
        guard let startDate = points.first?.date, let endDate = points.last?.date else { return [] }

        let totalInterval = endDate.timeIntervalSince(startDate)
        guard totalInterval > 0 else { return [] }

        let step = totalInterval / Double(count - 1)

        return (0..<count).map { i in
            let date = startDate.addingTimeInterval(Double(i) * step)
            let value = interpolator.interpolate(at: date.timeIntervalSince1970)
            return InterpolatedTimePoint(date: date, value: value)
        }
    }
}

// MARK: - Weight Data Model (Example)

/// Example model for weight tracking apps
public struct WeightEntry: InterpolatablePoint, Identifiable {
    public let id = UUID()
    public let date: Date
    public let weight: Double  // in kg or lb
    public let dosage: String? // Optional medication dosage
    
    public var x: Double { date.timeIntervalSince1970 }
    public var y: Double { weight }
    
    public init(date: Date, weight: Double, dosage: String? = nil) {
        self.date = date
        self.weight = weight
        self.dosage = dosage
    }
}

/// Interpolated weight point for charts
public struct InterpolatedWeightPoint: Identifiable {
    public let id = UUID()
    public let date: Date
    public let weight: Double
    
    public init(date: Date, weight: Double) {
        self.date = date
        self.weight = weight
    }
}

// MARK: - Weight Chart Data Provider

/// Provides smoothed data for weight charts
public class WeightChartDataProvider {
    private let entries: [WeightEntry]

    /// Whether the provider has valid data (at least 2 entries with different dates)
    public var isValid: Bool {
        guard entries.count >= 2 else { return false }
        guard let first = entries.first, let last = entries.last else { return false }
        return first.date != last.date
    }

    public init(entries: [WeightEntry]) {
        self.entries = entries.sorted { $0.date < $1.date }
    }

    /// Get smoothed weight curve using specified method
    public func smoothedCurve(
        method: InterpolationMethod,
        pointCount: Int = 100
    ) -> [InterpolatedWeightPoint] {
        guard entries.count >= 2, pointCount >= 2 else { return [] }

        let interpolator = createInterpolatorUnchecked(points: entries, method: method)
        guard interpolator.isValid else { return [] }

        let rawPoints = interpolator.generatePoints(count: pointCount)

        return rawPoints.map { point in
            let date = Date(timeIntervalSince1970: point.x)
            return InterpolatedWeightPoint(date: date, weight: point.y)
        }
    }

    /// Compare all three interpolation methods
    public func compareAllMethods(pointCount: Int = 100) -> (
        cubicSpline: [InterpolatedWeightPoint],
        pchip: [InterpolatedWeightPoint],
        akima: [InterpolatedWeightPoint]
    ) {
        return (
            cubicSpline: smoothedCurve(method: .cubicSpline, pointCount: pointCount),
            pchip: smoothedCurve(method: .pchip, pointCount: pointCount),
            akima: smoothedCurve(method: .akima, pointCount: pointCount)
        )
    }
}

// MARK: - SwiftUI Chart View Example

@available(iOS 16.0, macOS 13.0, *)
public struct WeightChartView: View {
    let entries: [WeightEntry]
    let interpolationMethod: InterpolationMethod
    
    @State private var smoothedData: [InterpolatedWeightPoint] = []
    
    public init(entries: [WeightEntry], method: InterpolationMethod = .cubicSpline) {
        self.entries = entries
        self.interpolationMethod = method
    }
    
    public var body: some View {
        Chart {
            // Smoothed line
            ForEach(smoothedData) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight)
                )
                .foregroundStyle(.blue.gradient)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            
            // Original data points
            ForEach(entries) { entry in
                PointMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.weight)
                )
                .foregroundStyle(.white)
                .symbolSize(50)
            }
        }
        .chartYAxisLabel("Weight")
        .chartXAxisLabel("Date")
        .onAppear {
            loadSmoothedData()
        }
    }
    
    private func loadSmoothedData() {
        let provider = WeightChartDataProvider(entries: entries)
        smoothedData = provider.smoothedCurve(method: interpolationMethod)
    }
}

// MARK: - Comparison Chart View

@available(iOS 16.0, macOS 13.0, *)
public struct InterpolationComparisonView: View {
    let entries: [WeightEntry]
    
    @State private var cubicData: [InterpolatedWeightPoint] = []
    @State private var pchipData: [InterpolatedWeightPoint] = []
    @State private var akimaData: [InterpolatedWeightPoint] = []
    
    public init(entries: [WeightEntry]) {
        self.entries = entries
    }
    
    public var body: some View {
        Chart {
            // Cubic Spline
            ForEach(cubicData) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight),
                    series: .value("Method", "Cubic Spline")
                )
                .foregroundStyle(.cyan)
            }
            
            // PCHIP
            ForEach(pchipData) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight),
                    series: .value("Method", "PCHIP")
                )
                .foregroundStyle(.yellow)
            }
            
            // Akima
            ForEach(akimaData) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight),
                    series: .value("Method", "Akima")
                )
                .foregroundStyle(.pink)
            }
            
            // Original points
            ForEach(entries) { entry in
                PointMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.weight)
                )
                .foregroundStyle(.white)
                .symbolSize(40)
            }
        }
        .chartForegroundStyleScale([
            "Cubic Spline": Color.cyan,
            "PCHIP": Color.yellow,
            "Akima": Color.pink
        ])
        .chartLegend(position: .top)
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        let provider = WeightChartDataProvider(entries: entries)
        let comparison = provider.compareAllMethods()
        cubicData = comparison.cubicSpline
        pchipData = comparison.pchip
        akimaData = comparison.akima
    }
}

#endif
