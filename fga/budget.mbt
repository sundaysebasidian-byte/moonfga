///|
/// Cooperative request deadline/budget failure (OpenFGA deadline_exceeded).
pub const ERR_DEADLINE_EXCEEDED : Int32 = 4004

///|
/// Shared request work counter and optional host deadline/cancellation predicate.
/// Create a fresh budget per request; copies share consumption and terminal state.
pub struct ExecutionBudget {
  priv mut remaining : Int32
  priv mut stopped : Bool
  priv cancelled : () -> Bool
}

///|
pub fn ExecutionBudget::new(
  steps~ : Int32 = 2147483647,
  cancelled~ : () -> Bool = fn() { false },
) -> ExecutionBudget {
  { remaining: steps, stopped: false, cancelled, }
}

///|
/// Checks the host predicate without consuming work. Failure is sticky.
pub fn ExecutionBudget::check(self : ExecutionBudget) -> Unit raise FgaError {
  if self.stopped || (self.cancelled)() {
    self.stopped = true
    raise fail(
      ERR_DEADLINE_EXCEEDED,
      "request deadline or work budget exceeded",
    )
  }
}

///|
/// Consumes one portable unit of work; this counter is separate from CEL cost.
pub fn ExecutionBudget::step(self : ExecutionBudget) -> Unit raise FgaError {
  self.check()
  if self.remaining <= 0 {
    self.stopped = true
    raise fail(ERR_DEADLINE_EXCEEDED, "request work budget exceeded")
  }
  self.remaining -= 1
}
