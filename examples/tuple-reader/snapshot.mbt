// A host loads one consistent snapshot before evaluation. A failed database
// read never becomes an empty authorization dataset.

///|
pub struct Snapshot {
  priv rows : Array[@fga.Tuple]
}

///|
pub fn load_snapshot(
  result : Result[Array[@fga.Tuple], String],
) -> Snapshot raise @fga.FgaError {
  match result {
    Ok(rows) => Snapshot::{ rows: rows.copy(), }
    Err(message) =>
      raise @fga.fail(@fga.ERR_VALIDATION, "tuple host: " + message)
  }
}

///|
pub impl @fga.TupleReader for Snapshot with fn read(self, object, relation) {
  self.rows.filter(fn(t) { t.object == object && t.relation == relation })
}

///|
pub impl @fga.TupleReader for Snapshot with fn read_userset(
  self,
  object,
  relation,
) {
  self.rows.filter(fn(t) {
    t.object == object &&
    t.relation == relation &&
    (match @fga.parse_user_ref(t.user) {
      Some(u) => u.relation is Some(_)
      None => false
    })
  })
}

///|
pub impl @fga.TupleReader for Snapshot with fn all_objects(self, type_name) {
  let seen : Map[String, Unit] = Map([])
  let out = []
  for t in self.rows {
    if @fga.object_type(t.object) == type_name && !seen.contains(t.object) {
      seen[t.object] = ()
      out.push(t.object)
    }
  }
  out
}

///|
pub impl @fga.TupleReader for Snapshot with fn all_users(self) {
  let seen : Map[String, Unit] = Map([])
  let out = []
  for t in self.rows {
    if !seen.contains(t.user) {
      seen[t.user] = ()
      out.push(t.user)
    }
  }
  out
}

///|
pub extend Snapshot with @fga.TupleReader::{
  read,
  read_userset,
  all_objects,
  all_users,
}
