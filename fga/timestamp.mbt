///|
fn pad_time(n : Int64, width : Int32) -> String {
  let s = n.to_string()
  let zeros = if width > s.length() { width - s.length() } else { 0 }
  Array::make(zeros, "0").join("") + s
}

///|
/// Formats milliseconds since the Unix epoch as UTC RFC3339.
fn format_timestamp_ms(ms : Int64) -> String {
  let seconds = if ms >= 0L { ms / 1000L } else { (ms - 999L) / 1000L }
  let millis = ms - seconds * 1000L
  let days = if seconds >= 0L {
    seconds / 86400L
  } else {
    (seconds - 86399L) / 86400L
  }
  let tod = seconds - days * 86400L
  let z = days + 719468L
  let era = if z >= 0L { z / 146097L } else { (z - 146096L) / 146097L }
  let doe = z - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let y = yoe + era * 400L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let day = doy - (153L * mp + 2L) / 5L + 1L
  let month = mp + (if mp < 10L { 3L } else { -9L })
  let year = y + (if month <= 2L { 1L } else { 0L })
  let fraction = if millis == 0L {
    ""
  } else {
    let mut f = pad_time(millis, 3)
    while f.has_suffix("0") {
      f = f[:f.length() - 1].to_owned()
    }
    "." + f
  }
  pad_time(year, 4) +
  "-" +
  pad_time(month, 2) +
  "-" +
  pad_time(day, 2) +
  "T" +
  pad_time(tod / 3600L, 2) +
  ":" +
  pad_time(tod / 60L % 60L, 2) +
  ":" +
  pad_time(tod % 60L, 2) +
  fraction +
  "Z"
}

///|
/// CEL/condition JSON timestamp formatting. Preserve the input numeric timezone
/// and nanoseconds; equality and arithmetic still compare the UTC instant.
pub fn timestamp_to_rfc3339(value : CelValue) -> String {
  let (ms, sub) = value.timestamp_parts().unwrap()
  let offset = value.timestamp_offset()
  let wall_time = ms + offset.to_int64() * 60000L
  let mut base = format_timestamp_ms(wall_time)
  if sub != 0 {
    let whole = wall_time - (wall_time % 1000L + 1000L) % 1000L
    base = format_timestamp_ms(whole)
    let ns = (wall_time % 1000L + 1000L) % 1000L * 1000000L + sub.to_int64()
    let mut fraction = pad_time(ns, 9)
    while fraction.has_suffix("0") {
      fraction = fraction[:fraction.length() - 1].to_owned()
    }
    base = base[:base.length() - 1].to_owned() + "." + fraction + "Z"
  }
  if offset == 0 {
    return base
  }
  let minutes = if offset < 0 { -offset } else { offset }
  base[:base.length() - 1].to_owned() +
  (if offset < 0 { "-" } else { "+" }) +
  pad_time((minutes / 60).to_int64(), 2) +
  ":" +
  pad_time((minutes % 60).to_int64(), 2)
}
