// Error model and OpenFGA-compatible error codes.
//
// Codes mirror the public OpenFGA error code enumeration so that the
// conformance runner can compare numeric codes directly.

///|
/// Validation error raised by request or model validation.
pub const ERR_VALIDATION : Int32 = 2000

///|
/// Authorization model not found.
pub const ERR_MODEL_NOT_FOUND : Int32 = 2001

///|
/// Resolution exceeded the maximum relation rewrite depth.
pub const ERR_RESOLUTION_TOO_COMPLEX : Int32 = 2002

///|
/// Invalid write input.
pub const ERR_INVALID_WRITE : Int32 = 2003

///|
/// A type referenced by a request does not exist in the model.
pub const ERR_TYPE_NOT_FOUND : Int32 = 2021

///|
/// A relation referenced by a request does not exist on the type.
pub const ERR_RELATION_NOT_FOUND : Int32 = 2022

///|
/// A tuple is syntactically invalid or does not satisfy type restrictions.
pub const ERR_INVALID_TUPLE : Int32 = 2027

///|
/// A referenced condition name is unknown.
pub const ERR_UNKNOWN_CONDITION : Int32 = 2021

///|
/// Maximum relation rewrite depth used by OpenFGA.
pub const MAX_RESOLUTION_DEPTH : Int32 = 25

///|
/// Error type shared by the parser, validator, store and engine.
///
/// `line` and `column` are 1-based source positions when known; they are
/// `-1` for runtime errors that have no source location.
pub suberror FgaError {
  FgaError(code~ : Int32, message~ : String, line~ : Int32, column~ : Int32)
}

///|
pub fn fail(code : Int32, message : String) -> FgaError {
  FgaError(code~, message~, line=-1, column=-1)
}

///|
pub fn fail_at(
  code : Int32,
  message : String,
  line : Int32,
  column : Int32,
) -> FgaError {
  FgaError(code~, message~, line~, column~)
}

///|
pub fn error_code(err : FgaError) -> Int32 {
  match err {
    FgaError(code~, ..) => code
  }
}

///|
pub fn error_message(err : FgaError) -> String {
  match err {
    FgaError(message~, ..) => message
  }
}

///|
pub fn format_error(err : FgaError) -> String {
  match err {
    FgaError(code~, message~, line~, column~) =>
      if line >= 0 {
        "E" +
        code.to_string() +
        " at " +
        line.to_string() +
        ":" +
        column.to_string() +
        ": " +
        message
      } else {
        "E" + code.to_string() + ": " + message
      }
  }
}
