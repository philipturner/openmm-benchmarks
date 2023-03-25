//
//  main.swift
//  SwiftFP64Emulation
//
//  Created by Philip Turner on 3/25/23.
//

import Foundation
import simd

// There is no tractable way to manually bypass Metal fast math. When
// implementing the shader, just disable the build option.

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
  
  static func - (lhs: DoubleSingle, rhs: Float) -> DoubleSingle {
    return lhs + (-rhs)
  }
  
  static func - (lhs: Float, rhs: DoubleSingle) -> DoubleSingle {
    return lhs + rhs.negated()
  }
}

print("\nTest DoubleSingle.+")
do {
  let ds1 = DoubleSingle(1.23456789)
  let ds2 = DoubleSingle(9.87654321)
  print(ds1.value)
  print(ds2.value)
  
  let ds3 = ds1 + ds2
  print(Float(1.23456789) + Float(9.87654321))
  print(ds3.value)
  print(Double(1.23456789) + Double(9.87654321))
}

print("\nTest DoubleSingle.-")
do {
  let ds1 = DoubleSingle(1.23456789)
  let ds2 = DoubleSingle(9.87654321)
  print(ds1.value)
  print(ds2.value)
  
  let ds3 = ds1 - ds2
  print(Float(1.23456789) - Float(9.87654321))
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
    return q
  }
  
  static func / (lhs: DoubleSingle, rhs: Float) -> DoubleSingle {
    let xn: Float = recip(rhs)
    let yn: Float = lhs.hi * xn
    let ayn: DoubleSingle = .init(multiplying: rhs, with: yn)
    let diff: Float = (lhs - ayn).hi
    let prod: DoubleSingle = .init(multiplying: xn, with: diff)
    let q: DoubleSingle = yn + prod
    return q
  }
  
  static func / (lhs: Float, rhs: DoubleSingle) -> DoubleSingle {
    let xn: Float = recip(rhs.hi)
    let yn: Float = lhs * xn
    let ayn: DoubleSingle = rhs * yn
    let diff: Float = (lhs - ayn).hi
    let prod: DoubleSingle = .init(multiplying: xn, with: diff)
    let q: DoubleSingle = yn + prod
    return q
  }
  
  init(dividing lhs: Float, with rhs: Float) {
    let xn: Float = recip(rhs)
    let yn: Float = lhs * xn
    let ayn: DoubleSingle = .init(multiplying: rhs, with: yn)
    let diff: Float = (lhs - ayn).hi
    let prod: DoubleSingle = .init(multiplying: xn, with: diff)
    let q: DoubleSingle = yn + prod
    self = q
  }
}

print("\nTesting Double./")
do {
  let ds1 = DoubleSingle(1.0)
  let ds2 = DoubleSingle(9.87654321)
  print(ds1.value)
  print(ds2.value)
  
  let ds3 = ds1 / ds2
  print(1 / Float(9.87654321))
  print(ds3.value)
  print(1 / Double(9.87654321))
}

print("\nTesting Double./")
do {
  let ds1 = DoubleSingle(9.87654321)
  let ds2 = DoubleSingle(1.23456789)
  print(ds1.value)
  print(ds2.value)
  
  let ds3 = ds1 / ds2
  print(Float(9.87654321) / Float(1.23456789))
  print(ds3.value)
  print(Double(9.87654321) / Double(1.23456789))
}

print("\nTesting Double./")
do {
  let ds1 = DoubleSingle(1.0)
  let ds2 = DoubleSingle(1.23456789)
  print(ds1.value)
  print(ds2.value)
  
  let ds3 = ds1 / ds2
  print(1 / Float(1.23456789))
  print(ds3.value)
  print(1 / Double(1.23456789))
}

// next, test recip
