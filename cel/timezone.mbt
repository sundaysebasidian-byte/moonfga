///|
priv struct TZInfo {
  transitions : Bytes
  initial : Int32
  future : (
    Int32,
    Int32,
    (Int32, Int32, Int32, Int32),
    (Int32, Int32, Int32, Int32),
  )?
}

///|
fn floor_div(n : Int64, d : Int64) -> Int64 {
  let q = n / d
  if n % d < 0L {
    q - 1L
  } else {
    q
  }
}

///|
fn rule_instant(
  year : Int64,
  r : (Int32, Int32, Int32, Int32),
  offset : Int32,
) -> Int64 {
  let first = days_from_civil(year, r.0.to_int64(), 1L)
  let weekday = ((first + 4L) % 7L + 7L) % 7L
  let mut day = 1L +
    (r.2.to_int64() - weekday + 7L) % 7L +
    (r.1 - 1).to_int64() * 7L
  if day > days_in_month(year.to_int(), r.0).to_int64() {
    day -= 7L
  }
  (first + day - 1L) * 86400L + r.3.to_int64() - offset.to_int64()
}

///|
fn timezone_offset(
  name : String,
  seconds : Int64,
  year : Int64,
) -> Int32 raise @fga.FgaError {
  if name == "UTC" || name == "" {
    return 0
  }
  if name.contains(":") {
    let parts = name.split(":").collect()
    if parts.length() != 2 {
      raise eval_error("invalid timezone")
    }
    validate_decimal(parts[0].to_owned(), true)
    validate_decimal(parts[1].to_owned(), true)
    let h = @string.parse_int(parts[0].to_owned()) catch {
      _ => raise eval_error("invalid timezone")
    }
    let m = @string.parse_int(parts[1].to_owned()) catch {
      _ => raise eval_error("invalid timezone")
    }
    if h < -23 || h > 23 || m < 0 || m > 59 {
      raise eval_error("invalid timezone")
    }
    return h * 3600 + (if name.has_prefix("-") { -m * 60 } else { m * 60 })
  }
  let index = match timezone_index(name) {
    Some(i) => i
    None => raise eval_error("unknown timezone")
  }
  let zone = timezone_table(index)
  if !zone.transitions.is_empty() &&
    seconds > zone.transition(zone.transitions.length() / 12 - 1).0 {
    match zone.future {
      Some((standard, summer, start, end)) => {
        let a = rule_instant(year, start, standard)
        let b = rule_instant(year, end, summer)
        let active = if a < b {
          seconds >= a && seconds < b
        } else {
          seconds >= a || seconds < b
        }
        return if active { summer } else { standard }
      }
      None => ()
    }
  }
  let mut lo = 0
  let mut hi = zone.transitions.length() / 12
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    if zone.transition(mid).0 <= seconds {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  if lo == 0 {
    zone.initial
  } else {
    zone.transition(lo - 1).1
  }
}

///|
fn timestamp_getter(
  value : @fga.CelValue,
  name : String,
  zone : String?,
) -> @fga.CelValue raise @fga.FgaError {
  let (seconds, nanos) = value.timestamp_seconds().unwrap()
  let (utc_year, _, _, _, _, _) = civil_second_fields(seconds)
  let offset = match zone {
    Some(z) => timezone_offset(z, seconds, utc_year)
    None => 0
  }
  let local_seconds = seconds + offset.to_int64()
  let (y, m, d, hour, minute, second) = civil_second_fields(local_seconds)
  let days = go_epoch_days(local_seconds)
  @fga.VInt(
    match name {
      "getFullYear" => y
      "getMonth" => m - 1L
      "getDate" => d
      "getDayOfMonth" => d - 1L
      "getDayOfYear" => days - days_from_civil(y, 1L, 1L)
      "getDayOfWeek" => ((days + 4L) % 7L + 7L) % 7L
      "getHours" => hour
      "getMinutes" => minute
      "getSeconds" => second
      "getMilliseconds" => nanos.to_int64() / 1000000L
      _ => raise eval_error("unknown timestamp getter")
    },
  )
}

///|
fn civil_second_fields(
  seconds : Int64,
) -> (Int64, Int64, Int64, Int64, Int64, Int64) {
  let days = go_epoch_days(seconds)
  let z = days + 719468L
  let era = floor_div(z, 146097L)
  let doe = z - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let y = yoe + era * 400L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let d = doy - (153L * mp + 2L) / 5L + 1L
  let m = mp + (if mp < 10L { 3L } else { -9L })
  let year = y + (if m <= 2L { 1L } else { 0L })
  let tod = ((seconds.reinterpret_as_uint64() + 9223372028741760000UL) % 86400UL).reinterpret_as_int64()
  (year, m, d, tod / 3600L, tod / 60L % 60L, tod % 60L)
}

///|
fn TZInfo::transition(self : TZInfo, index : Int32) -> (Int64, Int32) {
  let base = index * 12
  let mut seconds = 0UL
  for j in 0..<8 {
    seconds = seconds |
      (
        self.transitions[base + j].to_int().to_int64().reinterpret_as_uint64() <<
        (j * 8)
      )
  }
  let mut offset = 0
  for j in 0..<4 {
    offset = offset | (self.transitions[base + 8 + j].to_int() << (j * 8))
  }
  (seconds.reinterpret_as_int64(), offset)
}

///|
fn go_epoch_days(seconds : Int64) -> Int64 {
  ((seconds.reinterpret_as_uint64() + 9223372028741760000UL) / 86400UL).reinterpret_as_int64() -
  106751991073400L
}
