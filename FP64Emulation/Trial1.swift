//
//  main.swift
//  SwiftFP64Emulation
//
//  Created by Philip Turner on 3/25/23.
//

import Foundation
import simd

// This file crudely implements the verbatim output from GPT-4.
// Another file should clean it up and generalize to more code.
// The final implementation should run Metal shaders.

print("This file must be compiled in debug mode.")
print("Otherwise, the compiler may optimize away certain transformations.")

//let SIGN_MASK: UInt64 = 0x8000000000000000
//let EXP_MASK: UInt64 = 0x7ff0000000000000
//let MANT_MASK: UInt64 = 0x000fffffffffffff
//let EXP_BIAS: Int32 = 1023
//
//struct FP64 {
//  var storage: UInt64
//}
//
//func fp64_sign(_ x: FP64) -> Int32 {
//  return Int32((x.storage & SIGN_MASK) >> 63)
//}
//
//func fp64_exp(_ x: FP64) -> Int32 {
//  return Int32((x.storage & EXP_MASK) >> 63)
//}
//
//func fp64_mant(_ x: FP64) -> UInt64 {
//  return x.storage & MANT_MASK
//}
//
//func fp64_make_sign(_ s: Int32) -> UInt64 {
//  return UInt64(s) << 63
//}
//
//func fp64_make_exp(_ e: Int32) -> UInt64 {
//  return UInt64(e) << 52
//}
//
//func fp64_make_mant(_ m: UInt64) -> UInt64 {
//  return m & MANT_MASK
//}

// Define a struct named DoubleSingle
struct DoubleSingle {
    // Declare two variables of type Float to store the high and low parts of a double-float value
    var hi: Float
    var lo: Float

    // Define an initializer that takes two Float arguments and assigns them to the variables
    init(hi: Float, lo: Float) {
        self.hi = hi
        self.lo = lo
    }

    // Define other methods and properties for the struct as needed
    // For example, you can define a computed property that returns the sum of the high and low parts as a Double
    var value: Double {
        return Double(hi) + Double(lo)
    }
}

// Define an extension for DoubleSingle
extension DoubleSingle {
    // Define an initializer that takes a Double argument and splits it into two Floats
    init(_ value: Double) {
        // Convert the double value into a float, truncating it to the nearest float
        let hi = Float(value)
        // Subtract the truncated value from the original value and convert the difference into a float
        let lo = Float(value - Double(hi))
        // Call the existing initializer with the high and low parts
        self.init(hi: hi, lo: lo)
    }
}

print("\nTest DoubleSingle.init")
do {
  // Create an instance of DoubleSingle using a double value
  let ds = DoubleSingle(1.23456789)
  
  // Print the high and low parts of the instance
  print(ds.hi) // 1.234568
  print(ds.lo) // 3.72529e-09
  
  // Print the value of the instance
  print(Float(1.23456789))
  print(ds.value) // 1.2345678900000001
  print(Double(1.23456789))
}

// TODO: Another research paper should describe faster ways to do this.
func quickTwoSum(_ a: Float, _ b: Float) -> DoubleSingle {
  let s = a + b
  let e = b - (s - a)
  return DoubleSingle(hi: s, lo: e)
}

func twoSum(_ a: Float, _ b: Float) -> DoubleSingle {
  let s = a + b
  let v = s - a
  let e = (a - (s - v)) + (b - v)
  return DoubleSingle(hi: s, lo: e)
}

func twoProd(_ a: Float, _ b: Float) -> DoubleSingle {
  let x = a * b
  let y = fma(a, b, -x)
  return DoubleSingle(hi: x, lo: y)
}

// Define an extension for DoubleSingle
extension DoubleSingle {
    // Define a static method that takes two DoubleSingle arguments and returns their sum as a DoubleSingle
    static func add(_ x: DoubleSingle, _ y: DoubleSingle) -> DoubleSingle {
//        // Declare some variables to store the intermediate results
//        var s0, s1, t0, t1: Float
//
//        // Add the high parts of x and y
//        s0 = x.hi + y.hi
//
//        // Compute the difference between s0 and x.hi
//        t0 = s0 - x.hi
//
//        // Compute the difference between y.hi and t0
//        t1 = y.hi - t0
//
//        // Compute the difference between x.hi and t0
//        t0 = x.hi - t0
//
//        // Add the low parts of x and y
//        s1 = x.lo + y.lo
//
//        // Add the differences of the high parts to s1
//        s1 += (t0 + t1)
//
//        // Normalize the result by adding s0 and s1
//        let r = DoubleSingle(hi: s0 + s1, lo: (s0 - (s0 + s1)) + s1)
//
//        // Return the result
//        return r
      
      
      
      var s = twoSum(x.hi, y.hi)
      var t = twoSum(x.lo, y.lo)
      s.lo += t.hi
      s = quickTwoSum(s.hi, s.lo)
      s.lo += t.lo
      s = quickTwoSum(s.hi, s.lo)
      return s
    }
  
//  static func multiply(_ x: DoubleSingle, _ y: DoubleSingle) -> DoubleSingle {
//    func twoProd(_ a: Float, _ b: Float) -> DoubleSingle {
//      let x = a * b
//      let y = fma(a, b, -x)
//      return DoubleSingle(hi: x, lo: y)
//    }
//  }
}

print("\nTest DoubleSingle.add")
do {
  // Create two instances of DoubleSingle using some values
  let ds1 = DoubleSingle(1.23456789)
  let ds2 = DoubleSingle(9.87654321)
  
  // Print their values
  print(ds1.value) // 1.2345678900000001
  print(ds2.value) // 9.8765432100000006
  
  // Add them using the static method
  let ds3 = DoubleSingle.add(ds1, ds2)
  
  // Print the result
  print(Float(1.23456789) + Float(9.87654321))
  print(ds3.value) // 11.111111100000001
  print(Double(1.23456789) + Double(9.87654321))
}

// Define an extension for DoubleSingle
extension DoubleSingle {
    // Define a static method that takes two DoubleSingle arguments and returns their product as a DoubleSingle
    static func mul(_ x: DoubleSingle, _ y: DoubleSingle) -> DoubleSingle {
//        // Declare some constants to split a float into two halves
//        let split = Float(4097)
//        let splitHi = split * 0.5
//        let splitLo = 1.0 - splitHi
//
//        // Declare some variables to store the intermediate results
//        var p0, p1, p2: Float
//
//        // Split x.hi into two halves
//        let xHi = x.hi * split
//        let x0 = xHi - (xHi - x.hi)
//        let x1 = x.hi - x0
//
//        // Split y.hi into two halves
//        let yHi = y.hi * split
//        let y0 = yHi - (yHi - y.hi)
//        let y1 = y.hi - y0
//
//        // Multiply the high parts of x and y
//        p0 = x.hi * y.hi
//
//        // Multiply the low parts of x and y
//        p1 = x.lo * y.lo
//
//        // Multiply the cross products of x and y and add them to p1
//        p1 += (x0 * y1 + x1 * y0) + x.lo * y.hi + x.hi * y.lo
//
//        // Add p0 and p1
//        p2 = p0 + p1
//
//        // Normalize the result by adding p2 and (p0 - p2) + p1
//        let r = DoubleSingle(hi: p2, lo: (p0 - p2) + p1)
//
//        // Return the result
//        return r
      
      
      
      var p = twoProd(x.hi, y.hi)
      p.lo += x.hi * y.lo
      p.lo += x.lo * y.hi
      p = quickTwoSum(p.hi, p.lo)
      return p
    }
}

print("\nTest DoubleSingle.mul")
do {
  // Create two instances of DoubleSingle using some values
  let ds1 = DoubleSingle(1.23456789)
  let ds2 = DoubleSingle(9.87654321)
  
  // Print their values
  print(ds1.value) // 1.2345678900000001
  print(ds2.value) // 9.8765432100000006
  
  // Multiply them using the static method
  let ds3 = DoubleSingle.mul(ds1, ds2)
  
  // Print the result
  print(Float(1.23456789) * Float(9.87654321))
  print(ds3.value) // 12.193691456123457
  print(Double(1.23456789) * Double(9.87654321))
}

// Define an extension for DoubleSingle
extension DoubleSingle {
    // Define a static method that takes a DoubleSingle argument and returns its reciprocal as a DoubleSingle
    static func recip(_ x: DoubleSingle) -> DoubleSingle {
        // Declare some constants to split a float into two halves
        let split = Float(4097)
        let splitHi = split * 0.5
        let splitLo = 1.0 - splitHi

        // Declare some variables to store the intermediate results
        var q0, q1, q2, s0, s1, t0, t1: Float

        // Compute the initial approximation of 1/x.hi using a magic constant
        q0 = 1.0 / x.hi

        // Split x.hi into two halves
        let xHi = x.hi * split
        let x0 = xHi - (xHi - x.hi)
        let x1 = x.hi - x0

        // Split q0 into two halves
        let qHi = q0 * split
        let q0Hi = qHi - (qHi - q0)
        let q0Lo = q0 - q0Hi

        // Perform the first Newton-Raphson iteration
        s0 = 1.0 - q0 * x.hi
        s1 = -q0 * x.lo + s0 * s0

        // Split s1 into two halves
        let sHi = s1 * split
        let s1Hi = sHi - (sHi - s1)
        let s1Lo = s1 - s1Hi

        // Multiply the correction term by q0 and add it to q0
        q1 = s1 * q0 + q0
        t0 = q0 + s1 * q0

        // Split t0 into two halves
        let tHi = t0 * split
        let t0Hi = tHi - (tHi - t0)
        let t0Lo = t0 - t0Hi

        // Perform the second Newton-Raphson iteration
        s0 = 1.0 - t0 * x.hi
        s1 = -t0 * x.lo + s0 * s0

        // Split s1 into two halves
        let s2Hi = s1 * split
        let s3Hi = s2Hi - (s2Hi - s1)
        let s3Lo = s1 - s3Hi

        // Multiply the correction term by t0 and add it to t0
        q2 = s1 * t0 + t0

        // Normalize the result by adding q2 and (t0 - q2) + (s1 * t0)
        let r = DoubleSingle(hi: q2, lo: (t0 - q2) + (s1 * t0))

        // Return the result
        return r
    }
}

print("\nTest DoubleSingle.recip")
do {
  // Create an instance of DoubleSingle using some value
  let ds = DoubleSingle(9.87654321)
  
  // Print its value
  print(ds.value) // 9.8765432100000006
  
  // Compute its reciprocal using the static method
  let dsr = DoubleSingle.recip(ds)
  
  // Print the result
//  print(dsr.value) // 0.10123456790000001
  print(1 / Float(9.87654321))
  print(dsr.value) // 0.10125
  print(1 / Double(9.87654321))
}

// Define an extension for DoubleSingle
extension DoubleSingle {
    // Define a static method that takes two DoubleSingle arguments and returns their quotient as a DoubleSingle
    static func div(_ x: DoubleSingle, _ y: DoubleSingle) -> DoubleSingle {
        // Compute the reciprocal of y using the recip method
        let yr = DoubleSingle.recip(y)

        // Multiply x by yr using the mul method
        let r = DoubleSingle.mul(x, yr)

        // Return the result
        return r
    }
}

print("\nTest DoubleSingle.div")
do {
  // Create two instances of DoubleSingle using some values
  let ds1 = DoubleSingle(9.87654321)
  let ds2 = DoubleSingle(1.23456789)

  // Print their values
  print(ds1.value) // 9.8765432100000006
  print(ds2.value) // 1.2345678900000001

  // Divide them using the static method
  let ds3 = DoubleSingle.div(ds1, ds2)

  // Print the result
  print(Float(9.87654321) / Float(1.23456789))
  print(ds3.value) // 8.000000000000002
  print(Double(9.87654321) / Double(1.23456789))
  
  print("Just taking reciprocal of the divisor:")
  print(1 / Float(1.23456789))
  print(DoubleSingle.recip(.init(1.23456789)).value) // 8.000000000000002
  print(1 / Double(1.23456789))
}

extension DoubleSingle {
  static func neg(_ x: DoubleSingle) -> DoubleSingle {
    return DoubleSingle(hi: -x.hi, lo: -x.lo)
  }
  
  static func diff(_ x: DoubleSingle, _ y: DoubleSingle) -> DoubleSingle {
    return DoubleSingle.add(x, DoubleSingle.neg(y))
  }
}

// TODO: Optimize karp division for when X is 1.

// Define an extension for DoubleSingle
extension DoubleSingle {
    // Define a static method that takes two DoubleSingle arguments and returns their quotient as a DoubleSingle
//    static func karpDiv(_ x: DoubleSingle, _ y: DoubleSingle) -> DoubleSingle {
//        // Declare some variables to store the intermediate results
//        var xn, yn, ayn, diff, prod, q: Float
//
//        // Compute the initial approximation of 1/y.hi using single-precision division
//        xn = 1.0 / y.hi
//
//        // Compute the product of x.hi and xn using single-precision multiplication
//        yn = x.hi * xn
//
//        // Compute the product of y and yn using double-single multiplication
//        ayn = DoubleSingle.mul(y, DoubleSingle(hi: yn, lo: 0)).hi
//
//        // Compute the difference between x and ayn using double-single subtraction
//        diff = DoubleSingle.diff(x, DoubleSingle(hi: ayn, lo: 0)).hi
//
//        // Compute the product of xn and diff using single-precision multiplication
//        prod = xn * diff
//
//        // Compute the sum of yn and prod using single-precision addition
//        q = yn + prod
//
//        // Return the result as a double-single value
//        return DoubleSingle(hi: q, lo: 0)
//    }
  
  static func karpDiv(_ x: DoubleSingle, _ y: DoubleSingle) -> DoubleSingle {
      // Declare some variables to store the intermediate results

      // Compute the initial approximation of 1/y.hi using single-precision division
    let xn: Float = 1.0 / y.hi

      // Compute the product of x.hi and xn using single-precision multiplication
    let yn: Float = x.hi * xn

      // Compute the product of y and yn using double-single multiplication
    let ayn: DoubleSingle = DoubleSingle.mul(y, DoubleSingle(hi: yn, lo: 0))

      // Compute the difference between x and ayn using double-single subtraction
    let diff: Float = DoubleSingle.diff(x, ayn).hi

      // Compute the product of xn and diff using single-precision multiplication
    let prod: DoubleSingle = DoubleSingle.mul(
      DoubleSingle(hi: xn, lo: 0), DoubleSingle(hi: diff, lo: 0))

      // Compute the sum of yn and prod using single-precision addition
    let q: DoubleSingle = DoubleSingle.add(DoubleSingle(hi: yn, lo: 0), prod)

      // Return the result as a double-single value
      return q
  }
}

print("\nTesting Double.karpDiv")
do {
  // Create two instances of DoubleSingle using some values
  let ds1 = DoubleSingle(1.0)
  let ds2 = DoubleSingle(9.87654321)

  // Print their values
  print(ds1.value) // 1.0
  print(ds2.value) // 9.8765432100000006

  // Divide them using the static method
  let ds3 = DoubleSingle.karpDiv(ds1, ds2)

  // Print the result
//  print(ds3.value) // 0.10123456790000001
  print(1 / Float(9.87654321))
  print(ds3.value) // 0.10125
  print(1 / Double(9.87654321))
}

print("\nTesting Double.karpDiv")
do {
  // Create two instances of DoubleSingle using some values
  let ds1 = DoubleSingle(9.87654321)
  let ds2 = DoubleSingle(1.23456789)

  // Print their values
  print(ds1.value) // 9.8765432100000006
  print(ds2.value) // 1.2345678900000001

  // Divide them using the static method
  let ds3 = DoubleSingle.karpDiv(ds1, ds2)

  // Print the result
  print(Float(9.87654321) / Float(1.23456789))
  print(ds3.value) // 8.000000000000002
  print(Double(9.87654321) / Double(1.23456789))
}

print("\nTesting Double.karpDiv")
do {
  // Create two instances of DoubleSingle using some values
  let ds1 = DoubleSingle(1.0)
  let ds2 = DoubleSingle(1.23456789)

  // Print their values
  print(ds1.value) // 1.0
  print(ds2.value) // 9.8765432100000006

  // Divide them using the static method
  let ds3 = DoubleSingle.karpDiv(ds1, ds2)

  // Print the result
//  print(ds3.value) // 0.10123456790000001
  print(1 / Float(1.23456789))
  print(ds3.value) // 0.10125
  print(1 / Double(1.23456789))
  
  print("Attempting to multiply the reciprocal:")
  print(Float(9.87654321) / Float(1.23456789))
  print(DoubleSingle.mul(DoubleSingle(9.87654321), ds3).value) // 8.000000000000002
  print(Double(9.87654321) / Double(1.23456789))
}

// Define an extension for DoubleSingle
extension DoubleSingle {
    // Define a static method that takes a DoubleSingle argument and returns its reciprocal square root as a DoubleSingle
//    static func karpRecipSqrt(_ x: DoubleSingle) -> DoubleSingle {
//        // Declare some variables to store the intermediate results
//        var xn, xn2, y2n, diff, prod, q: Float
//
//        // Compute the initial approximation of 1/sqrt(x.hi) using single-precision division
//        xn = 1.0 / sqrt(x.hi)
//
//        // Compute the square of xn using single-precision multiplication
//        xn2 = xn * xn
//
//        // Compute the product of x and xn2 using double-single multiplication
//        y2n = DoubleSingle.mul(x, DoubleSingle(hi: xn2, lo: 0)).hi
//
//        // Compute the difference between 1 and y2n using single-precision subtraction
//        diff = 1.0 - y2n
//
//        // Compute the product of xn and diff using single-precision multiplication
//        prod = xn * diff
//
//        // Compute half of prod using single-precision division
//        prod = prod / 2.0
//
//        // Compute the sum of xn and prod using single-precision addition
//        q = xn + prod
//
//        // Return the result as a double-single value
//        return DoubleSingle(hi: q, lo: 0)
//    }
  
  static func karpRecipSqrt(_ x: DoubleSingle) -> DoubleSingle {
      // Declare some variables to store the intermediate results

      // Compute the initial approximation of 1/sqrt(x.hi) using single-precision division
    let xn: Float = 1.0 / sqrt(x.hi)

      // Compute the square of xn using single-precision multiplication
    let xn2: DoubleSingle = DoubleSingle.mul(DoubleSingle(hi: xn, lo: 0), DoubleSingle(hi: xn, lo: 0))

      // Compute the product of x and xn2 using double-single multiplication
    let y2n: DoubleSingle = DoubleSingle.mul(x, xn2)

      // Compute the difference between 1 and y2n using single-precision subtraction
    let diff: Float = DoubleSingle.diff(DoubleSingle(hi: 1.0, lo: 0.0), y2n).hi

      // Compute the product of xn and diff using single-precision multiplication
    var prod: DoubleSingle = DoubleSingle.mul(DoubleSingle(hi: xn, lo: 0), DoubleSingle(hi: diff, lo: 0))

      // Compute half of prod using single-precision division
    prod.hi /= 2.0
    prod.lo /= 2.0

      // Compute the sum of xn and prod using single-precision addition
    let q: DoubleSingle = DoubleSingle.add(DoubleSingle(hi: xn, lo: 0), prod)

      // Return the result as a double-single value
      return q
  }
}

print("\nTesting Double.karpRecipSqrt")
do {
  // Create an instance of DoubleSingle using some value
  let ds = DoubleSingle(9.87654321)
  
  // Print its value
  print(ds.value) // 9.8765432100000006
  
  // Compute its reciprocal square root using the static method
  let dsr = DoubleSingle.karpRecipSqrt(ds)
  
  // Print the result
  print(rsqrt(Float(9.87654321)))
  print(dsr.value) // 0.3183098861837907
  print(rsqrt(Double(9.87654321)))
}

print("\nTesting Double.karpRecipSqrt")
do {
  // Create an instance of DoubleSingle using some value
  let ds = DoubleSingle(1.23456789)
  
  // Print its value
  print(ds.value) // 9.8765432100000006
  
  // Compute its reciprocal square root using the static method
  let dsr = DoubleSingle.karpRecipSqrt(ds)
  
  // Print the result
  print(rsqrt(Float(1.23456789)))
  print(dsr.value) // 0.3183098861837907
  print(rsqrt(Double(1.23456789)))
}

extension DoubleSingle {
    // Define a static method that takes a DoubleSingle argument and returns its reciprocal square root as a DoubleSingle
//    static func karpSqrt(_ x: DoubleSingle) -> DoubleSingle {
//      let xn = rsqrt(x.hi)
//      let yn = x.hi * xn
//      let ynsqr = DoubleSingle.mul(
//        DoubleSingle(hi: yn, lo: 0), DoubleSingle(hi: yn, lo: 0))
//
//      let diff = DoubleSingle.diff(x, ynsqr).hi
//      var prod = twoProd(xn, diff)
//      prod.hi /= 2
//      prod.lo /= 2
//      return DoubleSingle.add(DoubleSingle(hi: yn, lo: 0), prod)
//    }
  
  static func karpSqrt(_ x: DoubleSingle) -> DoubleSingle {
    let xn = rsqrt(x.hi)
    let yn = x.hi * xn
    let ynsqr = DoubleSingle.mul(
      DoubleSingle(hi: yn, lo: 0), DoubleSingle(hi: yn, lo: 0))
    
    let diff = DoubleSingle.diff(x, ynsqr).hi
    var prod = twoProd(xn, diff)
    prod.hi /= 2
    prod.lo /= 2
    return DoubleSingle.add(DoubleSingle(hi: yn, lo: 0), prod)
  }
}

print("\nTesting Double.karpSqrt")
do {
  // Create an instance of DoubleSingle using some value
  let ds = DoubleSingle(9.87654321)
  
  // Print its value
  print(ds.value) // 9.8765432100000006
  
  // Compute its reciprocal square root using the static method
  let dsr = DoubleSingle.karpSqrt(ds)
  
  // Print the result
  print(sqrt(Float(9.87654321)))
  print(dsr.value) // 0.3183098861837907
  print(sqrt(Double(9.87654321)))
  
  print("Attempting to take the reciprocal:")
  print(rsqrt(Float(9.87654321)))
  print(DoubleSingle.karpDiv(DoubleSingle(hi: 1, lo: 0), dsr).value) // 8.000000000000002
  print(rsqrt(Double(9.87654321)))
}

print("\nTesting Double.karpSqrt")
do {
  // Create an instance of DoubleSingle using some value
  let ds = DoubleSingle(1.23456789)
  
  // Print its value
  print(ds.value) // 9.8765432100000006
  
  // Compute its reciprocal square root using the static method
  let dsr = DoubleSingle.karpSqrt(ds)
  
  // Print the result
  print(sqrt(Float(1.23456789)))
  print(dsr.value) // 0.3183098861837907
  print(sqrt(Double(1.23456789)))
  
  print("Attempting to take the reciprocal:")
  print(rsqrt(Float(1.23456789)))
  print(DoubleSingle.karpDiv(DoubleSingle(hi: 1, lo: 0), dsr).value) // 8.000000000000002
  print(rsqrt(Double(1.23456789)))
}

print("\nTesting Double.karpSqrt")
do {
  // Create an instance of DoubleSingle using some value
  let constant: Double = 3.23456789
  let ds = DoubleSingle(constant)
  
  // Print its value
  print(ds.value) // 9.8765432100000006
  
  // Compute its reciprocal square root using the static method
  let dsr = DoubleSingle.karpSqrt(ds)
  
  // Print the result
  print(sqrt(Float(constant)))
  print(dsr.value) // 0.3183098861837907
  print(sqrt(Double(constant)))
  
  print("Attempting to take the reciprocal:")
  print(DoubleSingle.karpRecipSqrt(ds).value)
  print(rsqrt(Float(constant)))
  print(DoubleSingle.karpDiv(DoubleSingle(hi: 1, lo: 0), dsr).value) // 8.000000000000002
  print(rsqrt(Double(constant)))
}
