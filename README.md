# SwiftChartSmoothing

Cubic Spline, PCHIP, and Akima interpolation for Swift. Built for Swift Charts and time series data.

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/YOURUSERNAME/SwiftChartSmoothing", from: "1.0.0")
]
```

## Usage

```swift
import SwiftChartSmoothing

let x = [0.0, 1.0, 2.0, 3.0, 4.0]
let y = [1.0, 2.0, 1.5, 3.0, 2.5]

// Create interpolator (throws on invalid input)
let spline = try CubicSplineInterpolator(x: x, y: y)

// Interpolate at any point
let value = spline.interpolate(at: 2.5)

// Generate smooth curve
let curve = spline.generatePoints(count: 100)
```

## Methods

| Method | Use Case |
|--------|----------|
| `CubicSplineInterpolator` | Smoothest curve, general visualization |
| `PCHIPInterpolator` | No overshoot, preserves monotonicity |
| `AkimaInterpolator` | Robust to outliers |

## Time Series

```swift
let points = [
    TimeSeriesPoint(date: date1, value: 70.0),
    TimeSeriesPoint(date: date2, value: 69.5),
    TimeSeriesPoint(date: date3, value: 69.0),
]

let interpolator = try TimeSeriesInterpolator(points: points, method: .pchip)
let smoothed = interpolator.smoothedPoints(count: 50)
```

## Swift Charts Integration

```swift
let provider = WeightChartDataProvider(entries: entries)
let curve = provider.smoothedCurve(method: .cubicSpline, pointCount: 100)

Chart {
    ForEach(curve) { point in
        LineMark(x: .value("Date", point.date), y: .value("Weight", point.weight))
    }
}
```

## Error Handling

```swift
// Throwing (strict)
do {
    let spline = try CubicSplineInterpolator(x: x, y: y)
} catch InterpolationError.insufficientPoints(let count, let required) {
    // Handle error
} catch InterpolationError.duplicateXValues(let x) {
    // Handle error
} catch InterpolationError.invalidValue(let description) {
    // Handle error
}

// Non-throwing (returns invalid interpolator)
let spline = CubicSplineInterpolator(xUnchecked: x, yUnchecked: y)
if spline.isValid {
    // Safe to use
}
```

## Requirements

- iOS 15.0+ / macOS 12.0+ / watchOS 8.0+ / tvOS 15.0+
- Swift 5.7+

## License

MIT
