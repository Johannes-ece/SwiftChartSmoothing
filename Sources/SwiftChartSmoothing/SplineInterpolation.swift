// SplineInterpolation.swift
// Cubic Spline, PCHIP, and Akima Interpolation for Swift
// Compatible with Swift Charts and time series data
//
// MIT License - Use freely in your projects

import Foundation

// MARK: - Error Types

/// Errors that can occur during interpolation
public enum InterpolationError: Error, Equatable {
    case insufficientPoints(count: Int, required: Int)
    case duplicateXValues(x: Double)
    case invalidValue(description: String)
}

// MARK: - Data Point Protocol

/// A protocol for data points that can be interpolated
public protocol InterpolatablePoint {
    var x: Double { get }
    var y: Double { get }
}

/// Simple implementation of InterpolatablePoint
public struct DataPoint: InterpolatablePoint, Equatable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

// MARK: - Interpolation Method Enum

public enum InterpolationMethod {
    case cubicSpline
    case pchip       // Monotone, no overshoot
    case akima       // Outlier-robust
}

// MARK: - Spline Interpolator Protocol

public protocol SplineInterpolator {
    /// Interpolate y value at given x
    func interpolate(at x: Double) -> Double

    /// Generate n evenly spaced points between min and max x
    func generatePoints(count: Int) -> [DataPoint]

    /// Whether the interpolator has valid data
    var isValid: Bool { get }

    /// The valid x range for interpolation
    var xRange: ClosedRange<Double>? { get }
}

// MARK: - Validation Helpers

/// Validates and prepares points for interpolation
internal func validateAndPreparePoints(_ points: [InterpolatablePoint]) throws -> (xs: [Double], ys: [Double]) {
    // Check for minimum points
    guard points.count >= 2 else {
        throw InterpolationError.insufficientPoints(count: points.count, required: 2)
    }

    // Check for NaN/Infinity
    for point in points {
        if point.x.isNaN || point.x.isInfinite {
            throw InterpolationError.invalidValue(description: "x value is NaN or Infinite")
        }
        if point.y.isNaN || point.y.isInfinite {
            throw InterpolationError.invalidValue(description: "y value is NaN or Infinite")
        }
    }

    // Sort by x
    let sorted = points.sorted { $0.x < $1.x }

    // Check for duplicate x values
    for i in 0..<(sorted.count - 1) {
        if abs(sorted[i].x - sorted[i + 1].x) < 1e-15 {
            throw InterpolationError.duplicateXValues(x: sorted[i].x)
        }
    }

    return (sorted.map { $0.x }, sorted.map { $0.y })
}

// MARK: - 1. Cubic Spline Implementation

/// Natural Cubic Spline Interpolation
/// C² continuous - smoothest curve through all points
public class CubicSplineInterpolator: SplineInterpolator {
    private let xs: [Double]
    private let ys: [Double]
    private let n: Int
    private let validState: Bool
    private let initError: InterpolationError?

    // Spline coefficients: S_i(x) = a_i + b_i(x-x_i) + c_i(x-x_i)² + d_i(x-x_i)³
    private var a: [Double] = []
    private var b: [Double] = []
    private var c: [Double] = []
    private var d: [Double] = []

    public var isValid: Bool { validState }

    public var xRange: ClosedRange<Double>? {
        guard validState, let first = xs.first, let last = xs.last else { return nil }
        return first...last
    }

    /// Throwing initializer for strict error handling
    public init(points: [InterpolatablePoint]) throws {
        let validated = try validateAndPreparePoints(points)
        self.xs = validated.xs
        self.ys = validated.ys
        self.n = xs.count
        self.validState = true
        self.initError = nil

        computeCoefficients()
    }

    /// Non-throwing initializer (returns invalid interpolator on error)
    public init(pointsUnchecked points: [InterpolatablePoint]) {
        do {
            let validated = try validateAndPreparePoints(points)
            self.xs = validated.xs
            self.ys = validated.ys
            self.n = xs.count
            self.validState = true
            self.initError = nil
            computeCoefficients()
        } catch let error as InterpolationError {
            self.xs = []
            self.ys = []
            self.n = 0
            self.validState = false
            self.initError = error
        } catch {
            self.xs = []
            self.ys = []
            self.n = 0
            self.validState = false
            self.initError = .invalidValue(description: error.localizedDescription)
        }
    }

    public convenience init(x: [Double], y: [Double]) throws {
        let points = zip(x, y).map { DataPoint(x: $0, y: $1) }
        try self.init(points: points)
    }

    public convenience init(xUnchecked x: [Double], yUnchecked y: [Double]) {
        let points = zip(x, y).map { DataPoint(x: $0, y: $1) }
        self.init(pointsUnchecked: points)
    }
    
    private func computeCoefficients() {
        guard n >= 2 else { return }
        
        // Initialize coefficients
        a = ys
        b = [Double](repeating: 0, count: n)
        c = [Double](repeating: 0, count: n)
        d = [Double](repeating: 0, count: n)
        
        if n == 2 {
            // Linear interpolation for 2 points
            b[0] = (ys[1] - ys[0]) / (xs[1] - xs[0])
            return
        }
        
        // Compute h_i = x_{i+1} - x_i
        var h = [Double](repeating: 0, count: n - 1)
        for i in 0..<(n - 1) {
            h[i] = xs[i + 1] - xs[i]
        }
        
        // Set up tridiagonal system for M (second derivatives)
        // Natural spline: M_0 = M_{n-1} = 0
        var alpha = [Double](repeating: 0, count: n)
        for i in 1..<(n - 1) {
            alpha[i] = 3.0 / h[i] * (ys[i + 1] - ys[i]) - 3.0 / h[i - 1] * (ys[i] - ys[i - 1])
        }
        
        // Solve tridiagonal system using Thomas algorithm
        var l = [Double](repeating: 1, count: n)
        var mu = [Double](repeating: 0, count: n)
        var z = [Double](repeating: 0, count: n)
        
        for i in 1..<(n - 1) {
            l[i] = 2.0 * (xs[i + 1] - xs[i - 1]) - h[i - 1] * mu[i - 1]
            mu[i] = h[i] / l[i]
            z[i] = (alpha[i] - h[i - 1] * z[i - 1]) / l[i]
        }
        
        // Back substitution
        for j in stride(from: n - 2, through: 0, by: -1) {
            c[j] = z[j] - mu[j] * c[j + 1]
            b[j] = (ys[j + 1] - ys[j]) / h[j] - h[j] * (c[j + 1] + 2.0 * c[j]) / 3.0
            d[j] = (c[j + 1] - c[j]) / (3.0 * h[j])
        }
    }
    
    public func interpolate(at x: Double) -> Double {
        guard validState, n >= 2 else { return .nan }
        guard let first = xs.first, let last = xs.last else { return .nan }

        // Clamp x to range
        let xClamped = max(first, min(last, x))

        // Find interval using binary search for better performance
        let i = findInterval(for: xClamped)

        // Evaluate polynomial
        let dx = xClamped - xs[i]
        return a[i] + b[i] * dx + c[i] * dx * dx + d[i] * dx * dx * dx
    }

    private func findInterval(for x: Double) -> Int {
        // Binary search for the correct interval
        var low = 0
        var high = n - 2

        while low < high {
            let mid = (low + high + 1) / 2
            if xs[mid] <= x {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return low
    }

    public func generatePoints(count: Int) -> [DataPoint] {
        guard validState, n >= 2, count >= 2 else { return [] }
        guard let xMin = xs.first, let xMax = xs.last else { return [] }

        let step = (xMax - xMin) / Double(count - 1)

        return (0..<count).map { i in
            let x = xMin + Double(i) * step
            return DataPoint(x: x, y: interpolate(at: x))
        }
    }
}

// MARK: - 2. PCHIP Implementation

/// Piecewise Cubic Hermite Interpolating Polynomial
/// Monotonicity-preserving - prevents overshoot
public class PCHIPInterpolator: SplineInterpolator {
    private let xs: [Double]
    private let ys: [Double]
    private let n: Int
    private let validState: Bool
    private let initError: InterpolationError?
    private var derivatives: [Double] = []

    public var isValid: Bool { validState }

    public var xRange: ClosedRange<Double>? {
        guard validState, let first = xs.first, let last = xs.last else { return nil }
        return first...last
    }

    /// Throwing initializer for strict error handling
    public init(points: [InterpolatablePoint]) throws {
        let validated = try validateAndPreparePoints(points)
        self.xs = validated.xs
        self.ys = validated.ys
        self.n = xs.count
        self.validState = true
        self.initError = nil

        computeDerivatives()
    }

    /// Non-throwing initializer (returns invalid interpolator on error)
    public init(pointsUnchecked points: [InterpolatablePoint]) {
        do {
            let validated = try validateAndPreparePoints(points)
            self.xs = validated.xs
            self.ys = validated.ys
            self.n = xs.count
            self.validState = true
            self.initError = nil
            computeDerivatives()
        } catch let error as InterpolationError {
            self.xs = []
            self.ys = []
            self.n = 0
            self.validState = false
            self.initError = error
        } catch {
            self.xs = []
            self.ys = []
            self.n = 0
            self.validState = false
            self.initError = .invalidValue(description: error.localizedDescription)
        }
    }

    public convenience init(x: [Double], y: [Double]) throws {
        let points = zip(x, y).map { DataPoint(x: $0, y: $1) }
        try self.init(points: points)
    }

    public convenience init(xUnchecked x: [Double], yUnchecked y: [Double]) {
        let points = zip(x, y).map { DataPoint(x: $0, y: $1) }
        self.init(pointsUnchecked: points)
    }
    
    private func computeDerivatives() {
        guard n >= 2 else { return }
        
        derivatives = [Double](repeating: 0, count: n)
        
        if n == 2 {
            let slope = (ys[1] - ys[0]) / (xs[1] - xs[0])
            derivatives[0] = slope
            derivatives[1] = slope
            return
        }
        
        // Compute h_i and delta_i (slopes)
        var h = [Double](repeating: 0, count: n - 1)
        var delta = [Double](repeating: 0, count: n - 1)
        
        for i in 0..<(n - 1) {
            h[i] = xs[i + 1] - xs[i]
            delta[i] = (ys[i + 1] - ys[i]) / h[i]
        }
        
        // Compute interior derivatives using PCHIP formula
        for i in 1..<(n - 1) {
            if delta[i - 1] * delta[i] <= 0 {
                // Different signs or zero -> set derivative to 0
                derivatives[i] = 0
            } else {
                // Weighted harmonic mean (Fritsch-Carlson)
                let w1 = 2.0 * h[i] + h[i - 1]
                let w2 = h[i] + 2.0 * h[i - 1]
                derivatives[i] = (w1 + w2) / (w1 / delta[i - 1] + w2 / delta[i])
            }
        }
        
        // End slopes using one-sided differences
        // For n=3, we need to handle carefully - use available data only
        if n >= 3 {
            derivatives[0] = pchipEndSlope(h[0], h[1], delta[0], delta[1])
            derivatives[n - 1] = pchipEndSlope(h[n - 2], h[n - 3], delta[n - 2], delta[n - 3])
        } else {
            // n == 2 case already handled above, but for safety:
            derivatives[0] = delta[0]
            derivatives[n - 1] = delta[n - 2]
        }
        
        // Apply Fritsch-Carlson monotonicity correction
        for i in 0..<(n - 1) {
            if abs(delta[i]) < 1e-30 {
                derivatives[i] = 0
                derivatives[i + 1] = 0
            } else {
                let alpha = derivatives[i] / delta[i]
                let beta = derivatives[i + 1] / delta[i]
                
                // Check if (alpha, beta) is in the monotonicity region
                let radius = alpha * alpha + beta * beta
                if radius > 9 {
                    // Scale to boundary
                    let tau = 3.0 / sqrt(radius)
                    derivatives[i] = tau * alpha * delta[i]
                    derivatives[i + 1] = tau * beta * delta[i]
                }
            }
        }
    }
    
    private func pchipEndSlope(_ h1: Double, _ h2: Double, _ del1: Double, _ del2: Double) -> Double {
        // One-sided three-point estimate
        var d = ((2.0 * h1 + h2) * del1 - h1 * del2) / (h1 + h2)
        
        // Enforce shape-preservation
        if d * del1 < 0 {
            d = 0
        } else if del1 * del2 < 0 && abs(d) > abs(3.0 * del1) {
            d = 3.0 * del1
        }
        
        return d
    }
    
    public func interpolate(at x: Double) -> Double {
        guard validState, n >= 2 else { return .nan }
        guard let first = xs.first, let last = xs.last else { return .nan }

        let xClamped = max(first, min(last, x))

        // Find interval using binary search
        let i = findInterval(for: xClamped)

        // Hermite basis evaluation
        let h = xs[i + 1] - xs[i]
        let t = (xClamped - xs[i]) / h

        // Hermite basis functions
        let h00 = (1.0 + 2.0 * t) * (1.0 - t) * (1.0 - t)  // 2t³ - 3t² + 1
        let h10 = t * (1.0 - t) * (1.0 - t)                 // t³ - 2t² + t
        let h01 = t * t * (3.0 - 2.0 * t)                   // -2t³ + 3t²
        let h11 = t * t * (t - 1.0)                         // t³ - t²

        return h00 * ys[i] + h10 * h * derivatives[i] +
               h01 * ys[i + 1] + h11 * h * derivatives[i + 1]
    }

    private func findInterval(for x: Double) -> Int {
        var low = 0
        var high = n - 2

        while low < high {
            let mid = (low + high + 1) / 2
            if xs[mid] <= x {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return low
    }

    public func generatePoints(count: Int) -> [DataPoint] {
        guard validState, n >= 2, count >= 2 else { return [] }
        guard let xMin = xs.first, let xMax = xs.last else { return [] }

        let step = (xMax - xMin) / Double(count - 1)

        return (0..<count).map { i in
            let x = xMin + Double(i) * step
            return DataPoint(x: x, y: interpolate(at: x))
        }
    }
}

// MARK: - 3. Akima Implementation

/// Akima Spline Interpolation
/// Outlier-robust - local method with reduced oscillation
public class AkimaInterpolator: SplineInterpolator {
    private let xs: [Double]
    private let ys: [Double]
    private let n: Int
    private let validState: Bool
    private let initError: InterpolationError?
    private var derivatives: [Double] = []

    public var isValid: Bool { validState }

    public var xRange: ClosedRange<Double>? {
        guard validState, let first = xs.first, let last = xs.last else { return nil }
        return first...last
    }

    /// Throwing initializer for strict error handling
    public init(points: [InterpolatablePoint]) throws {
        let validated = try validateAndPreparePoints(points)
        self.xs = validated.xs
        self.ys = validated.ys
        self.n = xs.count
        self.validState = true
        self.initError = nil

        computeDerivatives()
    }

    /// Non-throwing initializer (returns invalid interpolator on error)
    public init(pointsUnchecked points: [InterpolatablePoint]) {
        do {
            let validated = try validateAndPreparePoints(points)
            self.xs = validated.xs
            self.ys = validated.ys
            self.n = xs.count
            self.validState = true
            self.initError = nil
            computeDerivatives()
        } catch let error as InterpolationError {
            self.xs = []
            self.ys = []
            self.n = 0
            self.validState = false
            self.initError = error
        } catch {
            self.xs = []
            self.ys = []
            self.n = 0
            self.validState = false
            self.initError = .invalidValue(description: error.localizedDescription)
        }
    }

    public convenience init(x: [Double], y: [Double]) throws {
        let points = zip(x, y).map { DataPoint(x: $0, y: $1) }
        try self.init(points: points)
    }

    public convenience init(xUnchecked x: [Double], yUnchecked y: [Double]) {
        let points = zip(x, y).map { DataPoint(x: $0, y: $1) }
        self.init(pointsUnchecked: points)
    }
    
    private func computeDerivatives() {
        guard n >= 2 else { return }
        
        derivatives = [Double](repeating: 0, count: n)
        
        if n == 2 {
            let slope = (ys[1] - ys[0]) / (xs[1] - xs[0])
            derivatives[0] = slope
            derivatives[1] = slope
            return
        }
        
        // Compute slopes m_i = (y_{i+1} - y_i) / (x_{i+1} - x_i)
        var m = [Double](repeating: 0, count: n - 1)
        for i in 0..<(n - 1) {
            m[i] = (ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i])
        }
        
        // Extend slopes for boundary handling (Akima's method)
        // m_{-2}, m_{-1} at start and m_n, m_{n+1} at end
        let m_minus2: Double
        let m_minus1: Double
        let m_n: Double
        let m_nplus1: Double
        
        if n >= 3 {
            // Extrapolate using parabolic fit
            m_minus1 = 2.0 * m[0] - m[1]
            m_minus2 = 2.0 * m_minus1 - m[0]
            m_n = 2.0 * m[n - 2] - m[n - 3]
            m_nplus1 = 2.0 * m_n - m[n - 2]
        } else {
            m_minus1 = m[0]
            m_minus2 = m[0]
            m_n = m[n - 2]
            m_nplus1 = m[n - 2]
        }
        
        // Extended slope array: [m_{-2}, m_{-1}, m_0, ..., m_{n-2}, m_n, m_{n+1}]
        var mExt = [Double]()
        mExt.append(m_minus2)
        mExt.append(m_minus1)
        mExt.append(contentsOf: m)
        mExt.append(m_n)
        mExt.append(m_nplus1)
        
        // Compute derivatives using Akima formula
        for i in 0..<n {
            let idx = i + 2  // Offset due to extended array
            
            let w1 = abs(mExt[idx + 1] - mExt[idx])
            let w2 = abs(mExt[idx - 1] - mExt[idx - 2])
            
            if w1 + w2 < 1e-30 {
                // Both weights are zero -> simple average
                derivatives[i] = (mExt[idx - 1] + mExt[idx]) / 2.0
            } else {
                // Weighted average
                derivatives[i] = (w1 * mExt[idx - 1] + w2 * mExt[idx]) / (w1 + w2)
            }
        }
    }
    
    public func interpolate(at x: Double) -> Double {
        guard validState, n >= 2 else { return .nan }
        guard let first = xs.first, let last = xs.last else { return .nan }

        let xClamped = max(first, min(last, x))

        // Find interval using binary search
        let i = findInterval(for: xClamped)

        // Hermite basis evaluation (same as PCHIP)
        let h = xs[i + 1] - xs[i]
        let t = (xClamped - xs[i]) / h

        let h00 = (1.0 + 2.0 * t) * (1.0 - t) * (1.0 - t)
        let h10 = t * (1.0 - t) * (1.0 - t)
        let h01 = t * t * (3.0 - 2.0 * t)
        let h11 = t * t * (t - 1.0)

        return h00 * ys[i] + h10 * h * derivatives[i] +
               h01 * ys[i + 1] + h11 * h * derivatives[i + 1]
    }

    private func findInterval(for x: Double) -> Int {
        var low = 0
        var high = n - 2

        while low < high {
            let mid = (low + high + 1) / 2
            if xs[mid] <= x {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return low
    }

    public func generatePoints(count: Int) -> [DataPoint] {
        guard validState, n >= 2, count >= 2 else { return [] }
        guard let xMin = xs.first, let xMax = xs.last else { return [] }

        let step = (xMax - xMin) / Double(count - 1)

        return (0..<count).map { i in
            let x = xMin + Double(i) * step
            return DataPoint(x: x, y: interpolate(at: x))
        }
    }
}

// MARK: - Factory Functions

/// Create an interpolator with the specified method (throwing)
public func createInterpolator(
    points: [InterpolatablePoint],
    method: InterpolationMethod
) throws -> SplineInterpolator {
    switch method {
    case .cubicSpline:
        return try CubicSplineInterpolator(points: points)
    case .pchip:
        return try PCHIPInterpolator(points: points)
    case .akima:
        return try AkimaInterpolator(points: points)
    }
}

/// Create an interpolator with the specified method (non-throwing, returns invalid interpolator on error)
public func createInterpolatorUnchecked(
    points: [InterpolatablePoint],
    method: InterpolationMethod
) -> SplineInterpolator {
    switch method {
    case .cubicSpline:
        return CubicSplineInterpolator(pointsUnchecked: points)
    case .pchip:
        return PCHIPInterpolator(pointsUnchecked: points)
    case .akima:
        return AkimaInterpolator(pointsUnchecked: points)
    }
}

// MARK: - Array Extension for Convenience

public extension Array where Element: InterpolatablePoint {
    /// Interpolate this array of points using the specified method (throwing)
    func interpolated(method: InterpolationMethod, count: Int) throws -> [DataPoint] {
        let interpolator = try createInterpolator(points: self, method: method)
        return interpolator.generatePoints(count: count)
    }

    /// Interpolate this array of points using the specified method (non-throwing)
    func interpolatedUnchecked(method: InterpolationMethod, count: Int) -> [DataPoint] {
        let interpolator = createInterpolatorUnchecked(points: self, method: method)
        return interpolator.generatePoints(count: count)
    }
}
