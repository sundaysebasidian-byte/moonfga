// In-memory tuple store with object#relation and user indexes.
//
// The store implements `@fga.TupleReader`, so the evaluation engine only
// depends on the abstraction and can be pointed at another backend.

///|
/// Insertion-ordered in-memory tuple store.
///
/// Writes are idempotent: writing a tuple that already exists (same object,
/// relation, user and condition) is a no-op.
pub(all) struct MemoryStore {
  tuples : Array[@fga.Tuple]
  by_object : Map[String, Array[@fga.Tuple]]
  by_user : Map[String, Array[@fga.Tuple]]
  keys : Map[String, Unit]
}

///|
pub fn MemoryStore::new() -> MemoryStore {
  MemoryStore::{
    tuples: [],
    by_object: Map([]),
    by_user: Map([]),
    keys: Map([]),
  }
}

///|
fn object_index_key(object : String, relation : String) -> String {
  object + "#" + relation
}

///|
fn push_index(
  index : Map[String, Array[@fga.Tuple]],
  key : String,
  tuple : @fga.Tuple,
) -> Unit {
  match index.get(key) {
    Some(bucket) => bucket.push(tuple)
    None => index[key] = [tuple]
  }
}

///|
fn remove_index(
  index : Map[String, Array[@fga.Tuple]],
  key : String,
  tuple : @fga.Tuple,
) -> Unit {
  match index.get(key) {
    None => ()
    Some(bucket) => {
      let kept : Array[@fga.Tuple] = []
      for t in bucket {
        if t.key() != tuple.key() {
          kept.push(t)
        }
      }
      if kept.length() == 0 {
        index.remove(key)
      } else {
        index[key] = kept
      }
    }
  }
}

///|
/// Inserts a tuple. Returns `true` when the tuple was new.
pub fn MemoryStore::write(self : MemoryStore, tuple : @fga.Tuple) -> Bool {
  let key = tuple.key()
  if self.keys.contains(key) {
    return false
  }
  self.keys[key] = ()
  self.tuples.push(tuple)
  push_index(
    self.by_object,
    object_index_key(tuple.object, tuple.relation),
    tuple,
  )
  push_index(self.by_user, tuple.user, tuple)
  true
}

///|
/// Inserts several tuples and returns how many were new.
pub fn MemoryStore::write_all(
  self : MemoryStore,
  tuples : Array[@fga.Tuple],
) -> Int32 {
  let mut added = 0
  for t in tuples {
    if self.write(t) {
      added = added + 1
    }
  }
  added
}

///|
/// Deletes an exact tuple. Returns `true` when it existed.
pub fn MemoryStore::delete(self : MemoryStore, tuple : @fga.Tuple) -> Bool {
  let key = tuple.key()
  if !self.keys.contains(key) {
    return false
  }
  self.keys.remove(key)
  remove_index(
    self.by_object,
    object_index_key(tuple.object, tuple.relation),
    tuple,
  )
  remove_index(self.by_user, tuple.user, tuple)
  let kept : Array[@fga.Tuple] = []
  for t in self.tuples {
    if t.key() != key {
      kept.push(t)
    }
  }
  self.tuples.clear()
  self.tuples.append(kept)
  true
}

///|
pub fn MemoryStore::delete_all(
  self : MemoryStore,
  tuples : Array[@fga.Tuple],
) -> Int32 {
  let mut removed = 0
  for t in tuples {
    if self.delete(t) {
      removed = removed + 1
    }
  }
  removed
}

///|
pub fn MemoryStore::clear(self : MemoryStore) -> Unit {
  self.tuples.clear()
  self.by_object.clear()
  self.by_user.clear()
  self.keys.clear()
}

///|
/// Returns all tuples for `object#relation`.
pub fn MemoryStore::read(
  self : MemoryStore,
  object : String,
  relation : String,
) -> Array[@fga.Tuple] {
  match self.by_object.get(object_index_key(object, relation)) {
    Some(bucket) => bucket.copy()
    None => []
  }
}

///|
/// Returns the tuples for `object#relation` whose user is a userset reference
/// (`type:id#relation`).
pub fn MemoryStore::read_userset(
  self : MemoryStore,
  object : String,
  relation : String,
) -> Array[@fga.Tuple] {
  let out : Array[@fga.Tuple] = []
  for t in self.read(object, relation) {
    match @fga.parse_user_ref(t.user) {
      Some(r) =>
        match r.relation {
          Some(_) => out.push(t)
          None => ()
        }
      None => ()
    }
  }
  out
}

///|
/// Returns every tuple whose user is exactly `user`.
pub fn MemoryStore::read_by_user(
  self : MemoryStore,
  user : String,
) -> Array[@fga.Tuple] {
  match self.by_user.get(user) {
    Some(bucket) => bucket.copy()
    None => []
  }
}

///|
pub fn MemoryStore::all_tuples(self : MemoryStore) -> Array[@fga.Tuple] {
  self.tuples.copy()
}

///|
/// Distinct object strings of the requested type, in insertion order.
pub fn MemoryStore::all_objects(
  self : MemoryStore,
  type_name : String,
) -> Array[String] {
  let seen : Map[String, Unit] = Map([])
  let out : Array[String] = []
  for t in self.tuples {
    if @fga.object_type(t.object) == type_name && !seen.contains(t.object) {
      seen[t.object] = ()
      out.push(t.object)
    }
  }
  out
}

///|
/// Distinct user strings (including usersets and wildcards) in insertion
/// order.
pub fn MemoryStore::all_users(self : MemoryStore) -> Array[String] {
  let seen : Map[String, Unit] = Map([])
  let out : Array[String] = []
  for t in self.tuples {
    if !seen.contains(t.user) {
      seen[t.user] = ()
      out.push(t.user)
    }
  }
  out
}

///|
pub fn MemoryStore::length(self : MemoryStore) -> Int32 {
  self.tuples.length()
}

///|
pub impl @fga.TupleReader for MemoryStore with fn read(self, object, relation) {
  self.read(object, relation)
}

///|
pub impl @fga.TupleReader for MemoryStore with fn read_userset(
  self,
  object,
  relation,
) {
  self.read_userset(object, relation)
}

///|
pub impl @fga.TupleReader for MemoryStore with fn all_objects(self, type_name) {
  self.all_objects(type_name)
}

///|
pub impl @fga.TupleReader for MemoryStore with fn all_users(self) {
  self.all_users()
}

///|
/// Reader that overlays contextual tuples on top of a base reader. Contextual
/// tuples are only visible for the lifetime of a single request.
pub(all) struct ContextualStore {
  base : &@fga.TupleReader
  extra : MemoryStore
}

///|
pub fn ContextualStore::new(
  base : &@fga.TupleReader,
  tuples : Array[@fga.Tuple],
) -> ContextualStore {
  let extra = MemoryStore::new()
  let _ = extra.write_all(tuples)
  ContextualStore::{ base, extra, }
}

///|
pub fn ContextualStore::from_store(
  store : MemoryStore,
  tuples : Array[@fga.Tuple],
) -> ContextualStore {
  ContextualStore::new(store as &@fga.TupleReader, tuples)
}

///|
fn merge_tuples(
  a : Array[@fga.Tuple],
  b : Array[@fga.Tuple],
) -> Array[@fga.Tuple] {
  let seen : Map[String, Unit] = Map([])
  let out : Array[@fga.Tuple] = []
  for t in a {
    if !seen.contains(t.key()) {
      seen[t.key()] = ()
      out.push(t)
    }
  }
  for t in b {
    if !seen.contains(t.key()) {
      seen[t.key()] = ()
      out.push(t)
    }
  }
  out
}

///|
pub extend ContextualStore with @fga.TupleReader::{
  read,
  read_userset,
  all_objects,
  all_users,
}

///|
pub impl @fga.TupleReader for ContextualStore with fn read(
  self,
  object,
  relation,
) {
  merge_tuples(
    self.extra.read(object, relation),
    self.base.read(object, relation),
  )
}

///|
pub impl @fga.TupleReader for ContextualStore with fn read_userset(
  self,
  object,
  relation,
) {
  merge_tuples(
    self.extra.read_userset(object, relation),
    self.base.read_userset(object, relation),
  )
}

///|
pub impl @fga.TupleReader for ContextualStore with fn all_objects(
  self,
  type_name,
) {
  let seen : Map[String, Unit] = Map([])
  let out : Array[String] = []
  for o in self.extra.all_objects(type_name) {
    if !seen.contains(o) {
      seen[o] = ()
      out.push(o)
    }
  }
  for o in self.base.all_objects(type_name) {
    if !seen.contains(o) {
      seen[o] = ()
      out.push(o)
    }
  }
  out
}

///|
pub impl @fga.TupleReader for ContextualStore with fn all_users(self) {
  let seen : Map[String, Unit] = Map([])
  let out : Array[String] = []
  for u in self.extra.all_users() {
    if !seen.contains(u) {
      seen[u] = ()
      out.push(u)
    }
  }
  for u in self.base.all_users() {
    if !seen.contains(u) {
      seen[u] = ()
      out.push(u)
    }
  }
  out
}
