///|
/// Compare without first rounding an integer to binary64. NaN is unordered.
pub fn numeric_compare(a : CelValue, b : CelValue) -> Int32? {
  match (a, b) {
    (VInt(x), VInt(y)) => Some(if x < y { -1 } else if x > y { 1 } else { 0 })
    (VUint(x), VUint(y)) => Some(if x < y { -1 } else if x > y { 1 } else { 0 })
    (VInt(x), VUint(_)) =>
      if x < 0L {
        Some(-1)
      } else {
        numeric_compare(VUint(x.reinterpret_as_uint64()), b)
      }
    (VUint(_), VInt(_)) => numeric_compare(b, a).map(n => -n)
    (VDouble(x), VDouble(y)) =>
      if x.is_nan() || y.is_nan() {
        None
      } else {
        Some(if x < y { -1 } else if x > y { 1 } else { 0 })
      }
    (VInt(x), VDouble(y)) => {
      if y.is_nan() {
        return None
      }
      if y >= 9223372036854775808.0 {
        return Some(-1)
      }
      if y < -9223372036854775808.0 {
        return Some(1)
      }
      let integral = y.to_int64()
      if x < integral {
        Some(-1)
      } else if x > integral {
        Some(1)
      } else {
        Some(
          if y > integral.to_double() {
            -1
          } else if y < integral.to_double() {
            1
          } else {
            0
          },
        )
      }
    }
    (VUint(x), VDouble(y)) => {
      if y.is_nan() {
        return None
      }
      if y >= 18446744073709551616.0 {
        return Some(-1)
      }
      if y < 0.0 {
        return Some(1)
      }
      let integral = if y < 9223372036854775808.0 {
        y.to_int64().reinterpret_as_uint64()
      } else {
        (y - 9223372036854775808.0).to_int64().reinterpret_as_uint64() +
        9223372036854775808UL
      }
      if x < integral {
        Some(-1)
      } else if x > integral {
        Some(1)
      } else {
        Some(if y > integral.to_double() { -1 } else { 0 })
      }
    }
    (VDouble(_), VInt(_)) | (VDouble(_), VUint(_)) =>
      numeric_compare(b, a).map(n => -n)
    _ => None
  }
}

///|
/// cel-go's mixed double comparison rounds the integer to binary64. Perform
/// ties-to-even in the integer domain; same-type integer comparison stays exact.
pub fn cel_numeric_compare(a : CelValue, b : CelValue) -> Int32? {
  fn round_integer(v : CelValue) -> CelValue {
    let (magnitude, negative) = match v {
      VInt(x) =>
        (
          if x < 0L {
            (-x).reinterpret_as_uint64()
          } else {
            x.reinterpret_as_uint64()
          },
          x < 0L,
        )
      VUint(x) => (x, false)
      _ => return v
    }
    let mut shift = 0
    let mut significant = magnitude
    while significant > 9007199254740991UL {
      significant = significant >> 1
      shift += 1
    }
    if shift == 0 {
      return v
    }
    let half = 1UL << (shift - 1)
    let discarded = magnitude & ((1UL << shift) - 1UL)
    if discarded > half || (discarded == half && (significant & 1UL) == 1UL) {
      significant += 1UL
    }
    if significant == 9007199254740992UL && shift == 11 {
      return VDouble(18446744073709551616.0)
    }
    let rounded = significant << shift
    if negative {
      VInt(-rounded.reinterpret_as_int64())
    } else {
      VUint(rounded)
    }
  }
  match (a, b) {
    (VInt(_), VDouble(_)) | (VUint(_), VDouble(_)) =>
      numeric_compare(round_integer(a), b)
    (VDouble(_), VInt(_)) | (VDouble(_), VUint(_)) =>
      numeric_compare(a, round_integer(b))
    _ => numeric_compare(a, b)
  }
}
