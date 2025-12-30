// SwiftChartSmoothingTests.swift

import XCTest
@testable import SwiftChartSmoothing

final class SplineInterpolationTests: XCTestCase {

    // Test data
    let testX = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]
    let testY = [1.0, 2.0, 1.5, 3.0, 2.5, 4.0]

    // MARK: - Cubic Spline Tests

    func testCubicSplineInterpolatesAtDataPoints() throws {
        let spline = try CubicSplineInterpolator(x: testX, y: testY)

        for (x, y) in zip(testX, testY) {
            XCTAssertEqual(spline.interpolate(at: x), y, accuracy: 1e-10,
                          "Spline should pass through data point (\(x), \(y))")
        }
    }

    func testCubicSplineGeneratesCorrectPointCount() throws {
        let spline = try CubicSplineInterpolator(x: testX, y: testY)
        let points = spline.generatePoints(count: 100)

        XCTAssertEqual(points.count, 100)
    }

    func testCubicSplineBoundaryValues() throws {
        let spline = try CubicSplineInterpolator(x: testX, y: testY)

        // First point
        XCTAssertEqual(spline.interpolate(at: 0.0), 1.0, accuracy: 1e-10)
        // Last point
        XCTAssertEqual(spline.interpolate(at: 5.0), 4.0, accuracy: 1e-10)
    }

    func testCubicSplineClampsOutOfRange() throws {
        let spline = try CubicSplineInterpolator(x: testX, y: testY)

        // Below range
        XCTAssertEqual(spline.interpolate(at: -1.0), spline.interpolate(at: 0.0), accuracy: 1e-10)
        // Above range
        XCTAssertEqual(spline.interpolate(at: 10.0), spline.interpolate(at: 5.0), accuracy: 1e-10)
    }

    func testCubicSplineIsValid() throws {
        let spline = try CubicSplineInterpolator(x: testX, y: testY)
        XCTAssertTrue(spline.isValid)
    }

    func testCubicSplineXRange() throws {
        let spline = try CubicSplineInterpolator(x: testX, y: testY)
        XCTAssertEqual(spline.xRange, 0.0...5.0)
    }

    // MARK: - PCHIP Tests

    func testPCHIPInterpolatesAtDataPoints() throws {
        let pchip = try PCHIPInterpolator(x: testX, y: testY)

        for (x, y) in zip(testX, testY) {
            XCTAssertEqual(pchip.interpolate(at: x), y, accuracy: 1e-10,
                          "PCHIP should pass through data point (\(x), \(y))")
        }
    }

    func testPCHIPPreservesMonotonicity() throws {
        // Monotonically increasing data
        let monoX = [0.0, 1.0, 2.0, 3.0, 4.0]
        let monoY = [1.0, 2.0, 4.0, 7.0, 11.0]

        let pchip = try PCHIPInterpolator(x: monoX, y: monoY)
        let points = pchip.generatePoints(count: 100)

        // Check monotonicity
        for i in 1..<points.count {
            XCTAssertGreaterThanOrEqual(points[i].y, points[i-1].y,
                "PCHIP should preserve monotonicity: point \(i) should be >= point \(i-1)")
        }
    }

    func testPCHIPNoOvershoot() throws {
        // Data with flat section followed by steep rise
        let x = [0.0, 1.0, 2.0, 3.0, 4.0]
        let y = [1.0, 1.0, 1.0, 5.0, 5.0]

        let pchip = try PCHIPInterpolator(x: x, y: y)
        let points = pchip.generatePoints(count: 100)

        // All interpolated values should be within data range (with small tolerance for numerical precision)
        let minY = y.min()!
        let maxY = y.max()!

        for point in points {
            XCTAssertGreaterThanOrEqual(point.y, minY - 1e-10,
                "PCHIP should not undershoot: \(point.y) < \(minY)")
            XCTAssertLessThanOrEqual(point.y, maxY + 1e-10,
                "PCHIP should not overshoot: \(point.y) > \(maxY)")
        }
    }

    // MARK: - Akima Tests

    func testAkimaInterpolatesAtDataPoints() throws {
        let akima = try AkimaInterpolator(x: testX, y: testY)

        for (x, y) in zip(testX, testY) {
            XCTAssertEqual(akima.interpolate(at: x), y, accuracy: 1e-10,
                          "Akima should pass through data point (\(x), \(y))")
        }
    }

    func testAkimaHandlesOutliers() throws {
        // Data with an outlier
        let x = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]
        let y = [1.0, 1.0, 10.0, 1.0, 1.0, 1.0]  // Outlier at x=2

        let akima = try AkimaInterpolator(x: x, y: y)

        // Check that values far from outlier are reasonable
        let valueAt0_5 = akima.interpolate(at: 0.5)
        let valueAt4_5 = akima.interpolate(at: 4.5)

        // These should be close to 1.0, not influenced much by outlier
        XCTAssertLessThan(abs(valueAt0_5 - 1.0), 2.0,
            "Akima should be robust to outliers")
        XCTAssertLessThan(abs(valueAt4_5 - 1.0), 2.0,
            "Akima should be robust to outliers")
    }

    // MARK: - Factory Tests

    func testFactoryCreatesCubicSpline() throws {
        let points = zip(testX, testY).map { DataPoint(x: $0, y: $1) }
        let interpolator = try createInterpolator(points: points, method: .cubicSpline)

        XCTAssertTrue(interpolator is CubicSplineInterpolator)
        XCTAssertTrue(interpolator.isValid)
    }

    func testFactoryCreatesPCHIP() throws {
        let points = zip(testX, testY).map { DataPoint(x: $0, y: $1) }
        let interpolator = try createInterpolator(points: points, method: .pchip)

        XCTAssertTrue(interpolator is PCHIPInterpolator)
        XCTAssertTrue(interpolator.isValid)
    }

    func testFactoryCreatesAkima() throws {
        let points = zip(testX, testY).map { DataPoint(x: $0, y: $1) }
        let interpolator = try createInterpolator(points: points, method: .akima)

        XCTAssertTrue(interpolator is AkimaInterpolator)
        XCTAssertTrue(interpolator.isValid)
    }

    func testFactoryUncheckedReturnsInvalidOnError() {
        let points: [DataPoint] = []  // Empty - should fail
        let interpolator = createInterpolatorUnchecked(points: points, method: .cubicSpline)

        XCTAssertFalse(interpolator.isValid)
        XCTAssertNil(interpolator.xRange)
        XCTAssertTrue(interpolator.generatePoints(count: 10).isEmpty)
        XCTAssertTrue(interpolator.interpolate(at: 0).isNaN)
    }

    // MARK: - Edge Cases: Valid Input

    func testTwoPoints() throws {
        let x = [0.0, 1.0]
        let y = [0.0, 1.0]

        let cubic = try CubicSplineInterpolator(x: x, y: y)
        let pchip = try PCHIPInterpolator(x: x, y: y)
        let akima = try AkimaInterpolator(x: x, y: y)

        // All should handle 2 points (linear interpolation)
        XCTAssertEqual(cubic.interpolate(at: 0.5), 0.5, accuracy: 1e-10)
        XCTAssertEqual(pchip.interpolate(at: 0.5), 0.5, accuracy: 1e-10)
        XCTAssertEqual(akima.interpolate(at: 0.5), 0.5, accuracy: 1e-10)
    }

    func testThreePoints() throws {
        let x = [0.0, 1.0, 2.0]
        let y = [0.0, 1.0, 0.0]

        let cubic = try CubicSplineInterpolator(x: x, y: y)
        let pchip = try PCHIPInterpolator(x: x, y: y)
        let akima = try AkimaInterpolator(x: x, y: y)

        // All should handle 3 points
        XCTAssertTrue(cubic.isValid)
        XCTAssertTrue(pchip.isValid)
        XCTAssertTrue(akima.isValid)

        // Should pass through all points
        XCTAssertEqual(cubic.interpolate(at: 1.0), 1.0, accuracy: 1e-10)
        XCTAssertEqual(pchip.interpolate(at: 1.0), 1.0, accuracy: 1e-10)
        XCTAssertEqual(akima.interpolate(at: 1.0), 1.0, accuracy: 1e-10)
    }

    func testUnsortedInput() throws {
        // Points not in order
        let points = [
            DataPoint(x: 3.0, y: 3.0),
            DataPoint(x: 1.0, y: 1.0),
            DataPoint(x: 4.0, y: 4.0),
            DataPoint(x: 2.0, y: 2.0),
        ]

        let spline = try CubicSplineInterpolator(points: points)

        // Should sort internally and work correctly
        XCTAssertEqual(spline.interpolate(at: 1.0), 1.0, accuracy: 1e-10)
        XCTAssertEqual(spline.interpolate(at: 4.0), 4.0, accuracy: 1e-10)
    }

    func testNegativeXValues() throws {
        let x = [-5.0, -2.0, 0.0, 3.0, 7.0]
        let y = [1.0, 4.0, 2.0, 5.0, 3.0]

        let spline = try CubicSplineInterpolator(x: x, y: y)

        XCTAssertTrue(spline.isValid)
        XCTAssertEqual(spline.xRange, -5.0...7.0)
        XCTAssertEqual(spline.interpolate(at: -5.0), 1.0, accuracy: 1e-10)
        XCTAssertEqual(spline.interpolate(at: 0.0), 2.0, accuracy: 1e-10)
    }

    func testLargeValues() throws {
        let x = [1e10, 2e10, 3e10, 4e10, 5e10]
        let y = [1e8, 2e8, 1.5e8, 3e8, 2.5e8]

        let spline = try CubicSplineInterpolator(x: x, y: y)

        XCTAssertTrue(spline.isValid)
        XCTAssertEqual(spline.interpolate(at: 1e10), 1e8, accuracy: 1e2)
        XCTAssertEqual(spline.interpolate(at: 5e10), 2.5e8, accuracy: 1e2)
    }

    func testSmallValues() throws {
        let x = [1e-10, 2e-10, 3e-10, 4e-10, 5e-10]
        let y = [1e-8, 2e-8, 1.5e-8, 3e-8, 2.5e-8]

        let spline = try CubicSplineInterpolator(x: x, y: y)

        XCTAssertTrue(spline.isValid)
        XCTAssertEqual(spline.interpolate(at: 1e-10), 1e-8, accuracy: 1e-18)
        XCTAssertEqual(spline.interpolate(at: 5e-10), 2.5e-8, accuracy: 1e-18)
    }

    func testNonUniformSpacing() throws {
        // Very non-uniform spacing
        let x = [0.0, 0.001, 0.002, 10.0, 100.0]
        let y = [1.0, 1.1, 1.2, 5.0, 10.0]

        let spline = try CubicSplineInterpolator(x: x, y: y)

        XCTAssertTrue(spline.isValid)
        // Should still pass through all points
        for (xVal, yVal) in zip(x, y) {
            XCTAssertEqual(spline.interpolate(at: xVal), yVal, accuracy: 1e-8)
        }
    }

    // MARK: - Edge Cases: Error Handling

    func testEmptyArrayThrows() {
        let x: [Double] = []
        let y: [Double] = []

        XCTAssertThrowsError(try CubicSplineInterpolator(x: x, y: y)) { error in
            guard let interpError = error as? InterpolationError else {
                XCTFail("Expected InterpolationError")
                return
            }
            if case .insufficientPoints(let count, let required) = interpError {
                XCTAssertEqual(count, 0)
                XCTAssertEqual(required, 2)
            } else {
                XCTFail("Expected insufficientPoints error")
            }
        }
    }

    func testSinglePointThrows() {
        let x = [1.0]
        let y = [2.0]

        XCTAssertThrowsError(try CubicSplineInterpolator(x: x, y: y)) { error in
            guard let interpError = error as? InterpolationError else {
                XCTFail("Expected InterpolationError")
                return
            }
            if case .insufficientPoints(let count, let required) = interpError {
                XCTAssertEqual(count, 1)
                XCTAssertEqual(required, 2)
            } else {
                XCTFail("Expected insufficientPoints error")
            }
        }
    }

    func testDuplicateXValuesThrows() {
        let x = [0.0, 1.0, 1.0, 2.0]  // Duplicate at x=1
        let y = [0.0, 1.0, 2.0, 3.0]

        XCTAssertThrowsError(try CubicSplineInterpolator(x: x, y: y)) { error in
            guard let interpError = error as? InterpolationError else {
                XCTFail("Expected InterpolationError")
                return
            }
            if case .duplicateXValues(let xVal) = interpError {
                XCTAssertEqual(xVal, 1.0, accuracy: 1e-15)
            } else {
                XCTFail("Expected duplicateXValues error")
            }
        }
    }

    func testNaNInXThrows() {
        let x = [0.0, Double.nan, 2.0]
        let y = [0.0, 1.0, 2.0]

        XCTAssertThrowsError(try CubicSplineInterpolator(x: x, y: y)) { error in
            guard let interpError = error as? InterpolationError else {
                XCTFail("Expected InterpolationError")
                return
            }
            if case .invalidValue(let desc) = interpError {
                XCTAssertTrue(desc.contains("NaN") || desc.contains("Infinite"))
            } else {
                XCTFail("Expected invalidValue error")
            }
        }
    }

    func testNaNInYThrows() {
        let x = [0.0, 1.0, 2.0]
        let y = [0.0, Double.nan, 2.0]

        XCTAssertThrowsError(try PCHIPInterpolator(x: x, y: y)) { error in
            guard let interpError = error as? InterpolationError else {
                XCTFail("Expected InterpolationError")
                return
            }
            if case .invalidValue = interpError {
                // Expected
            } else {
                XCTFail("Expected invalidValue error")
            }
        }
    }

    func testInfinityInXThrows() {
        let x = [0.0, Double.infinity, 2.0]
        let y = [0.0, 1.0, 2.0]

        XCTAssertThrowsError(try AkimaInterpolator(x: x, y: y)) { error in
            guard let interpError = error as? InterpolationError else {
                XCTFail("Expected InterpolationError")
                return
            }
            if case .invalidValue = interpError {
                // Expected
            } else {
                XCTFail("Expected invalidValue error")
            }
        }
    }

    func testNegativeInfinityInYThrows() {
        let x = [0.0, 1.0, 2.0]
        let y = [0.0, -Double.infinity, 2.0]

        XCTAssertThrowsError(try CubicSplineInterpolator(x: x, y: y)) { error in
            guard let interpError = error as? InterpolationError else {
                XCTFail("Expected InterpolationError")
                return
            }
            if case .invalidValue = interpError {
                // Expected
            } else {
                XCTFail("Expected invalidValue error")
            }
        }
    }

    // MARK: - Non-throwing (Unchecked) Initializers

    func testUncheckedWithInvalidDataReturnsInvalid() {
        let spline = CubicSplineInterpolator(xUnchecked: [], yUnchecked: [])

        XCTAssertFalse(spline.isValid)
        XCTAssertNil(spline.xRange)
        XCTAssertTrue(spline.interpolate(at: 0).isNaN)
        XCTAssertTrue(spline.generatePoints(count: 10).isEmpty)
    }

    func testUncheckedWithDuplicatesReturnsInvalid() {
        let pchip = PCHIPInterpolator(xUnchecked: [0, 1, 1, 2], yUnchecked: [0, 1, 2, 3])

        XCTAssertFalse(pchip.isValid)
    }

    func testUncheckedWithNaNReturnsInvalid() {
        let akima = AkimaInterpolator(xUnchecked: [0, 1, .nan], yUnchecked: [0, 1, 2])

        XCTAssertFalse(akima.isValid)
    }

    func testUncheckedWithValidDataWorks() {
        let spline = CubicSplineInterpolator(xUnchecked: testX, yUnchecked: testY)

        XCTAssertTrue(spline.isValid)
        XCTAssertEqual(spline.interpolate(at: 0.0), 1.0, accuracy: 1e-10)
    }

    // MARK: - Comparison Tests

    func testAllMethodsProduceDifferentResults() throws {
        let cubic = try CubicSplineInterpolator(x: testX, y: testY)
        let pchip = try PCHIPInterpolator(x: testX, y: testY)
        let akima = try AkimaInterpolator(x: testX, y: testY)

        // At midpoints, methods should give slightly different results
        let midpoint = 2.5
        let cubicValue = cubic.interpolate(at: midpoint)
        let pchipValue = pchip.interpolate(at: midpoint)
        let akimaValue = akima.interpolate(at: midpoint)

        // They should be close but not identical
        XCTAssertNotEqual(cubicValue, pchipValue, accuracy: 1e-6)

        // All should be reasonable (between surrounding data points)
        XCTAssertGreaterThan(cubicValue, 1.0)
        XCTAssertLessThan(cubicValue, 4.0)
        XCTAssertGreaterThan(pchipValue, 1.0)
        XCTAssertLessThan(pchipValue, 4.0)
        XCTAssertGreaterThan(akimaValue, 1.0)
        XCTAssertLessThan(akimaValue, 4.0)
    }

    // MARK: - Array Extension Tests

    func testArrayExtensionInterpolated() throws {
        let points = zip(testX, testY).map { DataPoint(x: $0, y: $1) }
        let interpolated = try points.interpolated(method: .cubicSpline, count: 50)

        XCTAssertEqual(interpolated.count, 50)
        XCTAssertEqual(interpolated.first?.x, testX.first)
        XCTAssertEqual(interpolated.last?.x, testX.last)
    }

    func testArrayExtensionInterpolatedUnchecked() {
        let points = zip(testX, testY).map { DataPoint(x: $0, y: $1) }
        let interpolated = points.interpolatedUnchecked(method: .pchip, count: 50)

        XCTAssertEqual(interpolated.count, 50)
    }

    func testArrayExtensionWithInvalidDataThrows() {
        let points: [DataPoint] = [DataPoint(x: 0, y: 0)]

        XCTAssertThrowsError(try points.interpolated(method: .cubicSpline, count: 10))
    }

    func testArrayExtensionUncheckedWithInvalidDataReturnsEmpty() {
        let points: [DataPoint] = []
        let interpolated = points.interpolatedUnchecked(method: .akima, count: 10)

        XCTAssertTrue(interpolated.isEmpty)
    }

    // MARK: - GeneratePoints Edge Cases

    func testGeneratePointsWithCountZero() throws {
        let spline = try CubicSplineInterpolator(x: testX, y: testY)
        let points = spline.generatePoints(count: 0)

        XCTAssertTrue(points.isEmpty)
    }

    func testGeneratePointsWithCountOne() throws {
        let spline = try CubicSplineInterpolator(x: testX, y: testY)
        let points = spline.generatePoints(count: 1)

        XCTAssertTrue(points.isEmpty)  // count < 2 returns empty
    }

    func testGeneratePointsWithCountTwo() throws {
        let spline = try CubicSplineInterpolator(x: testX, y: testY)
        let points = spline.generatePoints(count: 2)

        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points.first!.x, 0.0, accuracy: 1e-10)
        XCTAssertEqual(points.last!.x, 5.0, accuracy: 1e-10)
    }

    // MARK: - Performance Tests

    func testPerformanceCubicSpline() throws {
        let n = 1000
        let x = (0..<n).map { Double($0) }
        let y = x.map { sin($0 * 0.1) }

        measure {
            let spline = CubicSplineInterpolator(xUnchecked: x, yUnchecked: y)
            _ = spline.generatePoints(count: 10000)
        }
    }

    func testPerformancePCHIP() throws {
        let n = 1000
        let x = (0..<n).map { Double($0) }
        let y = x.map { sin($0 * 0.1) }

        measure {
            let pchip = PCHIPInterpolator(xUnchecked: x, yUnchecked: y)
            _ = pchip.generatePoints(count: 10000)
        }
    }

    func testPerformanceAkima() throws {
        let n = 1000
        let x = (0..<n).map { Double($0) }
        let y = x.map { sin($0 * 0.1) }

        measure {
            let akima = AkimaInterpolator(xUnchecked: x, yUnchecked: y)
            _ = akima.generatePoints(count: 10000)
        }
    }

    // MARK: - Binary Search Performance Test

    func testBinarySearchPerformance() throws {
        // Large dataset to test binary search performance
        let n = 10000
        let x = (0..<n).map { Double($0) }
        let y = x.map { sin($0 * 0.01) }

        let spline = try CubicSplineInterpolator(x: x, y: y)

        measure {
            // Many random lookups
            for _ in 0..<100000 {
                let randomX = Double.random(in: 0..<Double(n))
                _ = spline.interpolate(at: randomX)
            }
        }
    }
}

// MARK: - Time Series Tests

#if canImport(Charts)
import Charts

final class TimeSeriesInterpolationTests: XCTestCase {

    func testTimeSeriesInterpolator() throws {
        let now = Date()
        let points = [
            TimeSeriesPoint(date: now, value: 70.0),
            TimeSeriesPoint(date: now.addingTimeInterval(86400), value: 69.5),
            TimeSeriesPoint(date: now.addingTimeInterval(172800), value: 69.0),
        ]

        let interpolator = try TimeSeriesInterpolator(points: points)

        XCTAssertTrue(interpolator.isValid)
        XCTAssertEqual(interpolator.value(at: now), 70.0, accuracy: 1e-10)
    }

    func testTimeSeriesInterpolatorSmoothedPoints() throws {
        let now = Date()
        let points = [
            TimeSeriesPoint(date: now, value: 70.0),
            TimeSeriesPoint(date: now.addingTimeInterval(86400), value: 69.5),
            TimeSeriesPoint(date: now.addingTimeInterval(172800), value: 69.0),
        ]

        let interpolator = try TimeSeriesInterpolator(points: points)
        let smoothed = interpolator.smoothedPoints(count: 10)

        XCTAssertEqual(smoothed.count, 10)
        XCTAssertEqual(smoothed.first!.value, 70.0, accuracy: 1e-10)
        XCTAssertEqual(smoothed.last!.value, 69.0, accuracy: 1e-10)
    }

    func testTimeSeriesInterpolatorWithInsufficientPoints() {
        let now = Date()
        let points = [TimeSeriesPoint(date: now, value: 70.0)]

        XCTAssertThrowsError(try TimeSeriesInterpolator(points: points))
    }

    func testTimeSeriesInterpolatorUnchecked() {
        let now = Date()
        let points = [TimeSeriesPoint(date: now, value: 70.0)]

        let interpolator = TimeSeriesInterpolator(pointsUnchecked: points)

        XCTAssertFalse(interpolator.isValid)
        XCTAssertTrue(interpolator.smoothedPoints(count: 10).isEmpty)
    }

    func testWeightChartDataProvider() {
        let now = Date()
        let entries = [
            WeightEntry(date: now, weight: 70.0),
            WeightEntry(date: now.addingTimeInterval(86400), weight: 69.5),
            WeightEntry(date: now.addingTimeInterval(172800), weight: 69.0),
        ]

        let provider = WeightChartDataProvider(entries: entries)

        XCTAssertTrue(provider.isValid)

        let curve = provider.smoothedCurve(method: .cubicSpline, pointCount: 10)
        XCTAssertEqual(curve.count, 10)
    }

    func testWeightChartDataProviderWithSingleEntry() {
        let now = Date()
        let entries = [WeightEntry(date: now, weight: 70.0)]

        let provider = WeightChartDataProvider(entries: entries)

        XCTAssertFalse(provider.isValid)
        XCTAssertTrue(provider.smoothedCurve(method: .cubicSpline).isEmpty)
    }

    func testWeightChartDataProviderCompareAllMethods() {
        let now = Date()
        let entries = [
            WeightEntry(date: now, weight: 70.0),
            WeightEntry(date: now.addingTimeInterval(86400), weight: 69.5),
            WeightEntry(date: now.addingTimeInterval(172800), weight: 69.0),
            WeightEntry(date: now.addingTimeInterval(259200), weight: 68.0),
        ]

        let provider = WeightChartDataProvider(entries: entries)
        let comparison = provider.compareAllMethods(pointCount: 20)

        XCTAssertEqual(comparison.cubicSpline.count, 20)
        XCTAssertEqual(comparison.pchip.count, 20)
        XCTAssertEqual(comparison.akima.count, 20)
    }
}
#endif
