//
//  main.swift
//  SwiftFP64Emulation
//
//  Created by Philip Turner on 3/25/23.
//

import Foundation
import simd

struct DoubleSingle {
  var hi: Float
  var lo: Float
  
  init(hi: Float, lo: Float) {
    self.hi = hi
    self.lo = lo
  }
  
  var value: Double {
    return Double(hi) + Double(lo)
  }
  
  init(_ value: Double) {
    self.hi = Float(value)
    self.lo = Float(value - Double(hi))
  }
  
  init(_ value: Float) {
    self.hi = value
    self.lo = 0
  }
  
  func negated() -> DoubleSingle {
    return DoubleSingle(hi: -hi, lo: -lo)
  }
  
  func halved() -> DoubleSingle {
    return DoubleSingle(hi: hi / 2, lo: lo / 2)
  }
  
  func normalized() -> DoubleSingle {
    let s = hi + lo
    let e = lo - (s - hi)
    return DoubleSingle(hi: s, lo: e)
  }
  
  init(adding lhs: Float, with rhs: Float) {
    let s = lhs + rhs
    let v = s - lhs
    let e = (lhs - (s - v)) + (rhs - v)
    self.hi = s
    self.lo = e
  }
  
  init(multiplying lhs: Float, with rhs: Float) {
    self.hi = lhs * rhs
    self.lo = fma(lhs, rhs, -hi)
  }
  
  static prefix func - (rhs: DoubleSingle) -> DoubleSingle {
    return rhs.negated()
  }
}

// Experimental, faster versions of each function.
infix operator ++: AdditionPrecedence
infix operator --: AdditionPrecedence
infix operator **: MultiplicationPrecedence
infix operator /%: MultiplicationPrecedence

extension DoubleSingle {
  static func + (lhs: DoubleSingle, rhs: DoubleSingle) -> DoubleSingle {
    var s: DoubleSingle = .init(adding: lhs.hi, with: rhs.hi)
    let t: DoubleSingle = .init(adding: lhs.lo, with: rhs.lo)
    s.lo += t.hi
    s = s.normalized()
    s.lo += t.lo
    s = s.normalized()
    return s
  }
  
  static func ++ (lhs: DoubleSingle, rhs: DoubleSingle) -> DoubleSingle {
    var s: DoubleSingle = .init(adding: lhs.hi, with: rhs.hi)
    s.lo += lhs.lo + rhs.lo
    s = s.normalized()
    return s
  }
  
  static func + (lhs: DoubleSingle, rhs: Float) -> DoubleSingle {
    var s: DoubleSingle = .init(adding: lhs.hi, with: rhs)
    s.lo += lhs.lo
    s = s.normalized()
    return s
  }
  
  static func + (lhs: Float, rhs: DoubleSingle) -> DoubleSingle {
    return rhs + lhs
  }
  
  static func - (lhs: DoubleSingle, rhs: DoubleSingle) -> DoubleSingle {
    return lhs + rhs.negated()
  }
  
  static func -- (lhs: DoubleSingle, rhs: DoubleSingle) -> DoubleSingle {
    return lhs ++ rhs.negated()
  }
  
  static func - (lhs: DoubleSingle, rhs: Float) -> DoubleSingle {
    return lhs + (-rhs)
  }
  
  static func - (lhs: Float, rhs: DoubleSingle) -> DoubleSingle {
    return lhs + rhs.negated()
  }
}

print("\nTest format:")
print("INPUT LHS")
print("INPUT RHS")
print("OUTPUT FP32")
print("OUTPUT eFP64")
print("OUTPUT FP64")

print("\nTest DoubleSingle.+")
do {
  let ds1 = DoubleSingle(1.23456789)
  let ds2 = DoubleSingle(9.87654321)
  print(ds1.value)
  print(ds2.value)
  
  let ds4 = ds1 ++ ds2
  let ds3 = ds1 + ds2
  print(Float(1.23456789) + Float(9.87654321))
  print(ds4.value)
  print(ds3.value)
  print(Double(1.23456789) + Double(9.87654321))
}

print("\nTest DoubleSingle.-")
do {
  let ds1 = DoubleSingle(1.23456789)
  let ds2 = DoubleSingle(9.87654321)
  print(ds1.value)
  print(ds2.value)
  
  let ds4 = ds1 -- ds2
  let ds3 = ds1 - ds2
  print(Float(1.23456789) - Float(9.87654321))
  print(ds4.value)
  print(ds3.value)
  print(Double(1.23456789) - Double(9.87654321))
}

extension DoubleSingle {
  static func * (lhs: DoubleSingle, rhs: DoubleSingle) -> DoubleSingle {
    var p: DoubleSingle = .init(multiplying: lhs.hi, with: rhs.hi)
    p.lo = fma(lhs.hi, rhs.lo, p.lo)
    p.lo = fma(lhs.lo, rhs.hi, p.lo)
    p = p.normalized()
    return p
  }
  
  static func * (lhs: DoubleSingle, rhs: Float) -> DoubleSingle {
    var p: DoubleSingle = .init(multiplying: lhs.hi, with: rhs)
    p.lo = fma(lhs.lo, rhs, p.lo)
    p = p.normalized()
    return p
  }
  
  static func * (lhs: Float, rhs: DoubleSingle) -> DoubleSingle {
    return rhs * lhs
  }
}

print("\nTest DoubleSingle.*")
do {
  let ds1 = DoubleSingle(1.23456789)
  let ds2 = DoubleSingle(9.87654321)
  print(ds1.value)
  print(ds2.value)
  
  let ds3 = ds1 * ds2
  print(Float(1.23456789) * Float(9.87654321))
  print(ds3.value)
  print(Double(1.23456789) * Double(9.87654321))
}

extension DoubleSingle {
  static func / (lhs: DoubleSingle, rhs: DoubleSingle) -> DoubleSingle {
    let xn: Float = recip(rhs.hi)
    let yn: Float = lhs.hi * xn
    let ayn: DoubleSingle = rhs * yn
    let diff: Float = (lhs - ayn).hi
    let prod: DoubleSingle = .init(multiplying: xn, with: diff)
    let q: DoubleSingle = yn + prod
    
    // Don't handle infinity case because any `INF` will cause undefined
    // behavior in other code anyway.
    return q
  }
  
  static func /% (lhs: DoubleSingle, rhs: DoubleSingle) -> DoubleSingle {
    let xn: Float = recip(rhs.hi)
    let yn: Float = lhs.hi * xn
    let ayn: DoubleSingle = rhs * yn
    let diff: Float = (lhs -- ayn).hi
    let prod: DoubleSingle = .init(multiplying: xn, with: diff)
    let q: DoubleSingle = yn + prod
    
    // Don't handle infinity case because any `INF` will cause undefined
    // behavior in other code anyway.
    return q
  }
  
  static func / (lhs: DoubleSingle, rhs: Float) -> DoubleSingle {
    let xn: Float = recip(rhs)
    let yn: Float = lhs.hi * xn
    let ayn: DoubleSingle = .init(multiplying: rhs, with: yn)
    let diff: Float = (lhs - ayn).hi
    let prod: DoubleSingle = .init(multiplying: xn, with: diff)
    let q: DoubleSingle = yn + prod
    
    // Don't handle infinity case because any `INF` will cause undefined
    // behavior in other code anyway.
    return q
  }
  
  static func /% (lhs: DoubleSingle, rhs: Float) -> DoubleSingle {
    let xn: Float = recip(rhs)
    let yn: Float = lhs.hi * xn
    let ayn: DoubleSingle = .init(multiplying: rhs, with: yn)
    let diff: Float = (lhs -- ayn).hi
    let prod: DoubleSingle = .init(multiplying: xn, with: diff)
    let q: DoubleSingle = yn + prod
    
    // Don't handle infinity case because any `INF` will cause undefined
    // behavior in other code anyway.
    return q
  }
  
  static func / (lhs: Float, rhs: DoubleSingle) -> DoubleSingle {
    let xn: Float = recip(rhs.hi)
    let yn: Float = lhs * xn
    let ayn: DoubleSingle = rhs * yn
    let diff: Float = (lhs - ayn).hi
    let prod: DoubleSingle = .init(multiplying: xn, with: diff)
    let q: DoubleSingle = yn + prod
    
    // Don't handle infinity case because any `INF` will cause undefined
    // behavior in other code anyway.
    return q
  }
  
  init(dividing lhs: Float, with rhs: Float) {
    let xn: Float = recip(rhs)
    let yn: Float = lhs * xn
    let ayn: DoubleSingle = .init(multiplying: rhs, with: yn)
    let diff: Float = (lhs - ayn).hi
    let prod: DoubleSingle = .init(multiplying: xn, with: diff)
    let q: DoubleSingle = yn + prod
    
    // Don't handle infinity case because any `INF` will cause undefined
    // behavior in other code anyway.
    self = q
  }
  
  func reciprocal() -> DoubleSingle {
    let xn: Float = simd.recip(self.hi)
    let ayn: DoubleSingle = self * xn
    let diff: Float = (1 - ayn).hi
    let prod: DoubleSingle = .init(multiplying: xn, with: diff)
    let q: DoubleSingle = xn + prod
    
    // Don't handle infinity case because any `INF` will cause undefined
    // behavior in other code anyway.
    return q
  }
}

print("\nTesting Double./")
do {
  let ds1 = DoubleSingle(1.0)
  let ds2 = DoubleSingle(9.87654321)
  print(ds1.value)
  print(ds2.value)
  
  let ds4 = ds1 /% ds2
  let ds3 = ds1 / ds2
  print(1 / Float(9.87654321))
  print(ds4.value)
  print(ds3.value)
  print(1 / Double(9.87654321))
}

print("\nTesting Double./")
do {
  let ds1 = DoubleSingle(9.87654321)
  let ds2 = DoubleSingle(1.23456789)
  print(ds1.value)
  print(ds2.value)
  
  let ds4 = ds1 /% ds2
  let ds3 = ds1 / ds2
  print(Float(9.87654321) / Float(1.23456789))
  print(ds4.value)
  print(ds3.value)
  print(Double(9.87654321) / Double(1.23456789))
}

print("\nTesting Double./")
do {
  let ds1 = DoubleSingle(1.23456789)
  let ds2 = DoubleSingle(-9.87654321)
  print(ds1.value)
  print(ds2.value)
  
  let ds4 = ds1 /% ds2
  let ds3 = ds1 / ds2
  print(Float(1.23456789) / Float(-9.87654321))
  print(ds4.value)
  print(ds3.value)
  print(Double(1.23456789) / Double(-9.87654321))
}

print("\nTesting Double./")
do {
  let ds1 = DoubleSingle(-1.23456789)
  let ds2 = DoubleSingle(-9.87654321)
  print(ds1.value)
  print(ds2.value)
  
  let ds4 = ds1 /% ds2
  let ds3 = ds1 / ds2
  print(Float(-1.23456789) / Float(-9.87654321))
  print(ds4.value)
  print(ds3.value)
  print(Double(-1.23456789) / Double(-9.87654321))
}

print("\nTesting Double./")
do {
  let ds1 = DoubleSingle(-1.23456789)
  let ds2 = DoubleSingle(9.87654321)
  print(ds1.value)
  print(ds2.value)
  
  let ds4 = ds1 /% ds2
  let ds3 = ds1 / ds2
  print(Float(-1.23456789) / Float(9.87654321))
  print(ds4.value)
  print(ds3.value)
  print(Double(-1.23456789) / Double(9.87654321))
}

print("\nTesting Double./")
do {
  let ds1 = DoubleSingle(1.0)
  let ds2 = DoubleSingle(1.23456789)
  print(ds1.value)
  print(ds2.value)
  
  let ds4 = ds1 /% ds2
  let ds3 = ds1 / ds2
  print(1 / Float(1.23456789))
  print(ds4.value)
  print(ds3.value)
  print(1 / Double(1.23456789))
}

print("\nTesting Double.reciprocal")
do {
  let ds2 = DoubleSingle(9.87654321)
  print(ds2.value)
  
  let ds3 = ds2.reciprocal()
  print(1 / Float(9.87654321))
  print(ds3.value)
  print(1 / Double(9.87654321))
}

print("\nTesting Double.reciprocal")
do {
  let ds2 = DoubleSingle(1.23456789)
  print(ds2.value)
  
  let ds3 = ds2.reciprocal()
  print(1 / Float(1.23456789))
  print(ds3.value)
  print(1 / Double(1.23456789))
}

print("\nTesting Double.reciprocal")
do {
  let ds2 = DoubleSingle(-1.23456789)
  print(ds2.value)
  
  let ds3 = ds2.reciprocal()
  print(1 / Float(-1.23456789))
  print(ds3.value)
  print(1 / Double(-1.23456789))
}

print("\nTesting Double.reciprocal")
do {
  let ds2 = DoubleSingle(Float(0))
  print(ds2.value)
  
  let ds3 = ds2.reciprocal()
  print(1 / Float(0))
  print(ds3.value)
  print(1 / Double(0))
}

print("\nTesting Double.reciprocal")
do {
  let ds2 = DoubleSingle(Float.leastNormalMagnitude)
  print(ds2.value)
  
  let ds3 = ds2.reciprocal()
  print(1 / Float.leastNormalMagnitude)
  print(ds3.value)
  print(1 / Double(Float.leastNormalMagnitude))
}

print("\nTesting Double.reciprocal")
do {
  let ds2 = DoubleSingle(Float.greatestFiniteMagnitude)
  print(ds2.value)
  
  let ds3 = ds2.reciprocal()
  print(1 / Float.greatestFiniteMagnitude)
  print(ds3.value)
  print(1 / Double(Float.greatestFiniteMagnitude))
}

print("\nTesting Double.reciprocal")
do {
  let ds2 = DoubleSingle(Float.infinity)
  print(ds2.value)
  
  let ds3 = ds2.reciprocal()
  print(1 / Float.infinity)
  print(ds3.value)
  print(1 / Double(Float.infinity))
}

print("\nTesting Double.reciprocal")
do {
  let ds2 = DoubleSingle(Float.leastNormalMagnitude)
  print(ds2.value)
  
  let ds3 = ds2.reciprocal()
  print(1 / Float(1.23456789))
  print(ds3.value)
  print(1 / Double(1.23456789))
}

extension DoubleSingle {
  func squareRoot() -> DoubleSingle {
    let xn: Float = rsqrt(self.hi)
    let yn: Float = self.hi * xn
    let ynsqr: DoubleSingle = .init(multiplying: yn, with: yn)
    let diff: Float = (self - ynsqr).hi
    let prod: DoubleSingle = .init(multiplying: xn, with: diff)
    
    // Don't handle infinity case because any `INF` will cause undefined
    // behavior in other code anyway.
    var output = yn + prod.halved()
    if self.hi == 0 {
      output = DoubleSingle(hi: 0, lo: 0)
    }
    return output
  }
  
  func squareRoot2() -> DoubleSingle {
    let xn: Float = rsqrt(self.hi)
    let yn: Float = self.hi * xn
    let ynsqr: DoubleSingle = .init(multiplying: yn, with: yn)
    let diff: Float = (self -- ynsqr).hi
    let prod: DoubleSingle = .init(multiplying: xn, with: diff)
    
    // Don't handle infinity case because any `INF` will cause undefined
    // behavior in other code anyway.
    var output = yn + prod.halved()
    if self.hi == 0 {
      output = DoubleSingle(hi: 0, lo: 0)
    }
    return output
  }
  
  func reciprocalSquareRoot() -> DoubleSingle {
    let xn: Float = rsqrt(self.hi)
    let xn2: DoubleSingle = .init(multiplying: xn, with: xn)
    let y2n: DoubleSingle = self * xn2
    let diff: Float = (1 - y2n).hi
    let prod: DoubleSingle = .init(multiplying: xn, with: diff)
    
    // Don't handle infinity case because any `INF` will cause undefined
    // behavior in other code anyway.
    return xn + prod.halved()
  }
}

print("\nTesting Double.squareRoot")
do {
  let ds = DoubleSingle(9.87654321)
  print(ds.value)

  let dsr2 = ds.squareRoot2()
  let dsr = ds.squareRoot()
  print(sqrt(Float(9.87654321)))
  print(dsr2.value)
  print(dsr.value)
  print(sqrt(Double(9.87654321)))
}

print("\nTesting Double.squareRoot")
do {
  let ds = DoubleSingle(1.23456789)
  print(ds.value)

  let dsr2 = ds.squareRoot2()
  let dsr = ds.squareRoot()
  print(sqrt(Float(1.23456789)))
  print(dsr2.value)
  print(dsr.value)
  print(sqrt(Double(1.23456789)))
}

print("\nTesting Double.squareRoot")
do {
  let constant: Double = 3.23456789
  let ds = DoubleSingle(constant)
  print(ds.value)

  let dsr2 = ds.squareRoot2()
  let dsr = ds.squareRoot()
  print(sqrt(Float(constant)))
  print(dsr2.value)
  print(dsr.value)
  print(sqrt(Double(constant)))
}

print("\nTesting Double.squareRoot")
do {
  let constant: Double = 0
  let ds = DoubleSingle(constant)
  print(ds.value)

  let dsr2 = ds.squareRoot2()
  let dsr = ds.squareRoot()
  print(sqrt(Float(constant)))
  print(dsr2.value)
  print(dsr.value)
  print(sqrt(Double(constant)))
}

print("\nTesting Double.squareRoot")
do {
  let constant: Double = .init(Float.leastNormalMagnitude)
  let ds = DoubleSingle(constant)
  print(ds.value)

  let dsr2 = ds.squareRoot2()
  let dsr = ds.squareRoot()
  print(sqrt(Float(constant)))
  print(dsr2.value)
  print(dsr.value)
  print(sqrt(Double(constant)))
}

print("\nTesting Double.squareRoot")
do {
  let constant: Double = .init(Float.greatestFiniteMagnitude)
  let ds = DoubleSingle(constant)
  print(ds.value)

  let dsr2 = ds.squareRoot2()
  let dsr = ds.squareRoot()
  print(sqrt(Float(constant)))
  print(dsr2.value)
  print(dsr.value)
  print(sqrt(Double(constant)))
}

print("\nTesting Double.squareRoot")
do {
  let constant: Double = .infinity
  let ds = DoubleSingle(constant)
  print(ds.value)

  let dsr2 = ds.squareRoot2()
  let dsr = ds.squareRoot()
  print(sqrt(Float(constant)))
  print(dsr2.value)
  print(dsr.value)
  print(sqrt(Double(constant)))
}


print("\nTesting Double.reciprocalSquareRoot")
do {
  let ds = DoubleSingle(9.87654321)
  print(ds.value)

  let dsr = ds.reciprocalSquareRoot()
  print(rsqrt(Float(9.87654321)))
  print(dsr.value)
  print(rsqrt(Double(9.87654321)))
}

print("\nTesting Double.reciprocalSquareRoot")
do {
  let ds = DoubleSingle(1.23456789)
  print(ds.value)

  let dsr = ds.reciprocalSquareRoot()
  print(rsqrt(Float(1.23456789)))
  print(dsr.value)
  print(rsqrt(Double(1.23456789)))
}

print("\nTesting Double.reciprocalSquareRoot")
do {
  let constant: Double = 3.23456789
  let ds = DoubleSingle(constant)
  print(ds.value)

  let dsr = ds.reciprocalSquareRoot()
  print(rsqrt(Float(constant)))
  print(dsr.value)
  print(rsqrt(Double(constant)))
}

print("\nTesting Double.reciprocalSquareRoot")
do {
  let constant: Double = 0.00
  let ds = DoubleSingle(constant)
  print(ds.value)

  let dsr = ds.reciprocalSquareRoot()
  print(rsqrt(Float(constant)))
  print(dsr.value)
  print(rsqrt(Double(constant)))
}

print("\nTesting Double.reciprocalSquareRoot")
do {
  let constant: Double = .init(Float.leastNormalMagnitude)
  let ds = DoubleSingle(constant)
  print(ds.value)

  let dsr = ds.reciprocalSquareRoot()
  print(rsqrt(Float(constant)))
  print(dsr.value)
  print(rsqrt(Double(constant)))
}

print("\nTesting Double.reciprocalSquareRoot")
do {
  let constant: Double = .init(Float.greatestFiniteMagnitude)
  let ds = DoubleSingle(constant)
  print(ds.value)

  let dsr = ds.reciprocalSquareRoot()
  print(rsqrt(Float(constant)))
  print(dsr.value)
  print(rsqrt(Double(constant)))
}

print("\nTesting Double.reciprocalSquareRoot")
do {
  let constant: Double = .infinity
  let ds = DoubleSingle(constant)
  print(ds.value)

  let dsr = ds.reciprocalSquareRoot()
  print(rsqrt(Float(constant)))
  print(dsr.value)
  print(rsqrt(Double(constant)))
}

extension DoubleSingle {
  init(_ value: Int64) {
    self.hi = Float(value)
    
    // If you can guarantee this never happens, it will improve performance.
    if abs(self.hi) >= Float(Int64.max) {
      self.lo = 0
    } else {
      self.lo = Float(value - Int64(hi))
    }
  }
  
  init(_ value: UInt64) {
    // If you can guarantee this never happens, it will improve performance.
    if value & (2 << 63) != 0 {
      self.hi = Float(value)
      if Int64(self.hi) > value {
        self.lo = Float(Int64(value) - Int64(hi))
      } else {
        self.lo = Float(value - UInt64(hi))
      }
    } else {
      self.hi = Float(value)
      
      // If you can guarantee this never happens, it will improve performance.
      if abs(self.hi) >= Float(UInt64.max) {
        self.lo = 0
      } else {
        self.lo = Float(Int64(value) - Int64(hi))
      }
    }
  }
}

print("\nTesting Double.init(_: Int64)")
do {
  let constant: Int64 = 987654321
  print(constant)
  
  let ds = DoubleSingle(constant)
  print(Float(constant))
  print(ds.value)
  print(Double(constant))
}

print("\nTesting Double.init(_: Int64)")
do {
  let constant: Int64 = -987654321
  print(constant)
  
  let ds = DoubleSingle(constant)
  print(Float(constant))
  print(ds.value)
  print(Double(constant))
}

print("\nTesting Double.init(_: Int64)")
do {
  let constant: Int64 = .max
  print(constant)
  
  let ds = DoubleSingle(constant)
  print(Float(constant))
  print(ds.value)
  print(Double(constant))
}

print("\nTesting Double.init(_: Int64)")
do {
  let constant: Int64 = .max / 4
  print(constant)
  
  let ds = DoubleSingle(constant)
  print(Float(constant))
  print(ds.value)
  print(Double(constant))
}

print("\nTesting Double.init(_: Int64)")
do {
  let constant: Int64 = .max - 5
  print(constant)
  
  let ds = DoubleSingle(constant)
  print(Float(constant))
  print(ds.value)
  print(Double(constant))
}

print("\nTesting Double.init(_: Int64)")
do {
  let constant: Int64 = .min
  print(constant)
  
  let ds = DoubleSingle(constant)
  print(Float(constant))
  print(ds.value)
  print(Double(constant))
}

print("\nTesting Double.init(_: Int64)")
do {
  let constant: Int64 = .min / 4
  print(constant)
  
  let ds = DoubleSingle(constant)
  print(Float(constant))
  print(ds.value)
  print(Double(constant))
}

print("\nTesting Double.init(_: Int64)")
do {
  let constant: Int64 = .min + 5
  print(constant)
  
  let ds = DoubleSingle(constant)
  print(Float(constant))
  print(ds.value)
  print(Double(constant))
}

print("\nTesting Double.init(_: UInt64)")
do {
  let constant: UInt64 = 987654321
  print(constant)
  
  let ds = DoubleSingle(constant)
  print(Float(constant))
  print(ds.value)
  print(Double(constant))
}

print("\nTesting Double.init(_: UInt64)")
do {
  let constant: UInt64 = .max
  print(constant)
  
  let ds = DoubleSingle(constant)
  print(Float(constant))
  print(ds.value)
  print(Double(constant))
}

print("\nTesting Double.init(_: UInt64)")
do {
  let constant: UInt64 = .max / 4
  print(constant)
  
  let ds = DoubleSingle(constant)
  print(Float(constant))
  print(ds.value)
  print(Double(constant))
}

print("\nTesting Double.init(_: UInt64)")
do {
  let constant: UInt64 = .max - 5
  print(constant)
  
  let ds = DoubleSingle(constant)
  print(Float(constant))
  print(ds.value)
  print(Double(constant))
}

print("\nTesting Double.init(_: UInt64)")
do {
  let constant: UInt64 = .min
  print(constant)
  
  let ds = DoubleSingle(constant)
  print(Float(constant))
  print(ds.value)
  print(Double(constant))
}

print("\nTesting Double.init(_: UInt64)")
do {
  let constant: UInt64 = .min / 4
  print(constant)
  
  let ds = DoubleSingle(constant)
  print(Float(constant))
  print(ds.value)
  print(Double(constant))
}

print("\nTesting Double.init(_: UInt64)")
do {
  let constant: UInt64 = .min + 5
  print(constant)
  
  let ds = DoubleSingle(constant)
  print(Float(constant))
  print(ds.value)
  print(Double(constant))
}

