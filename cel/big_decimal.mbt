// Minimal unsigned arithmetic for the server's 64-bit-precision decimal context
// conversion. Base 2^15 keeps multiplication portable on every backend.

///|
priv struct BigNatural {
  limbs : Array[Int32]
}

///|
fn BigNatural::one() -> BigNatural {
  { limbs: [1], }
}

///|
fn BigNatural::trim(self : BigNatural) -> Unit {
  while self.limbs.length() > 1 && self.limbs[self.limbs.length() - 1] == 0 {
    ignore(self.limbs.pop())
  }
}

///|
fn BigNatural::multiply(self : BigNatural, n : Int32, add~ : Int32 = 0) -> Unit {
  let mut carry = add
  for i in 0..<self.limbs.length() {
    let next = self.limbs[i] * n + carry
    self.limbs[i] = next % 32768
    carry = next / 32768
  }
  while carry != 0 {
    self.limbs.push(carry % 32768)
    carry /= 32768
  }
}

///|
fn BigNatural::bits(self : BigNatural) -> Int32 {
  let mut high = self.limbs[self.limbs.length() - 1]
  let mut count = 0
  while high > 0 {
    high = high >> 1
    count += 1
  }
  (self.limbs.length() - 1) * 15 + count
}

///|
fn BigNatural::shift(self : BigNatural, count : Int32) -> BigNatural {
  let shifted = BigNatural::{
    limbs: Array::make(count / 15, 0) + self.limbs.copy(),
  }
  shifted.multiply(1 << (count % 15))
  shifted
}

///|
fn BigNatural::compare(self : BigNatural, other : BigNatural) -> Int32 {
  if self.limbs.length() != other.limbs.length() {
    return if self.limbs.length() < other.limbs.length() { -1 } else { 1 }
  }
  for i = self.limbs.length() - 1; i >= 0; i = i - 1 {
    if self.limbs[i] != other.limbs[i] {
      return if self.limbs[i] < other.limbs[i] { -1 } else { 1 }
    }
  }
  0
}

///|
fn BigNatural::subtract(self : BigNatural, other : BigNatural) -> Unit {
  let mut borrow = 0
  for i in 0..<self.limbs.length() {
    let next = self.limbs[i] - other.limbs.get(i).unwrap_or(0) - borrow
    self.limbs[i] = if next < 0 { next + 32768 } else { next }
    borrow = if next < 0 { 1 } else { 0 }
  }
  self.trim()
}

///|
/// Returns sign, 64-bit significand and binary exponent after ties-to-even.
fn rounded_decimal(text : String) -> (Bool, UInt64, Int32) raise @fga.FgaError {
  let binary_mark = match text.find("p") {
    Some(i) => Some(i)
    None => text.find("P")
  }
  let (mantissa, binary_exponent) = match binary_mark {
    Some(i) => {
      let prefix = text[:i].to_owned()
      if prefix.contains("e") || prefix.contains("E") {
        raise eval_error("invalid mixed numeric exponent")
      }
      let exp = @string.parse_int(text[i + 1:].to_owned()) catch {
        _ => raise eval_error("invalid binary context exponent")
      }
      (prefix, exp)
    }
    None => (text, 0)
  }
  let (negative, digits, decimal_exponent) = decimal_parts(mantissa)
  if digits.is_empty() {
    return (negative, 0UL, 0)
  }
  let estimate = (
      digits.length().to_double() - 1.0 + decimal_exponent.to_double()
    ) *
    3.321928094887362 +
    binary_exponent.to_double()
  if estimate >= 2147483647.0 || estimate <= -2147483648.0 {
    raise eval_error("numeric context exponent out of range")
  }
  // Extreme magnitudes need only a saturation/precision decision, not an
  // allocation proportional to the exponent.
  if estimate > 1100.0 {
    return (negative, 9223372036854775808UL, 2048)
  }
  if estimate < -1200.0 {
    return (negative, 9223372036854775808UL, -2048)
  }
  let numerator = BigNatural::{ limbs: [0], }
  for ch in digits {
    numerator.multiply(10, add=ch.to_int() - 48)
  }
  let denominator = BigNatural::one()
  if decimal_exponent > 0 {
    for _ in 0..<decimal_exponent {
      numerator.multiply(10)
    }
  } else {
    for _ in 0..<-decimal_exponent {
      denominator.multiply(10)
    }
  }
  let mut exponent = numerator.bits() - denominator.bits()
  if exponent >= 0 {
    if numerator.compare(denominator.shift(exponent)) < 0 {
      exponent -= 1
    }
  } else if numerator.shift(-exponent).compare(denominator) < 0 {
    exponent -= 1
  }
  let scale = 63 - exponent
  let remainder = if scale >= 0 { numerator.shift(scale) } else { numerator }
  let divisor = if scale >= 0 { denominator } else { denominator.shift(-scale) }
  let mut significand = 0UL
  for bit = 63; bit >= 0; bit = bit - 1 {
    let candidate = divisor.shift(bit)
    if remainder.compare(candidate) >= 0 {
      remainder.subtract(candidate)
      significand = significand | (1UL << bit)
    }
  }
  remainder.multiply(2)
  let cmp = remainder.compare(divisor)
  if cmp > 0 || (cmp == 0 && (significand & 1UL) != 0UL) {
    if significand == 18446744073709551615UL {
      significand = 9223372036854775808UL
      exponent += 1
    } else {
      significand += 1UL
    }
  }
  (negative, significand, exponent + binary_exponent)
}
