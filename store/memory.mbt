// In-memory tuple store with object#relation and user indexes.
//
// The store implements `@fga.TupleReader`, so the evaluation engine only
// depends on the abstraction and can be pointed at another backend.

///|
/// Insertion-ordered in-memory tuple store.
///
/// Writes are idempotent: writing a tuple that already exists (same object,
/// relation, user and condition) is a no-op.
pub struct MemoryStore {
  priv tuples : Array[@fga.Tuple]
  priv by_object : Map[String, Array[@fga.Tuple]]
  priv by_user : Map[String, Array[@fga.Tuple]]
  priv keys : Map[String, Unit]
  priv objects_by_type : Map[String, Array[String]]
  priv object_counts : Map[String, Int32]
}

///|
/// Creates an empty store with independent indexes.
pub fn MemoryStore::new() -> MemoryStore {
  MemoryStore::{
    tuples: [],
    by_object: Map([]),
    by_user: Map([]),
    keys: Map([]),
    objects_by_type: Map([]),
    object_counts: Map([]),
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
  let count = self.object_counts.get(tuple.object).unwrap_or(0)
  if count == 0 {
    let type_name = @fga.object_type(tuple.object)
    match self.objects_by_type.get(type_name) {
      Some(objects) => objects.push(tuple.object)
      None => self.objects_by_type[type_name] = [tuple.object]
    }
  }
  self.object_counts[tuple.object] = count + 1
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
  let remaining = self.object_counts.get(tuple.object).unwrap_or(1) - 1
  if remaining == 0 {
    self.object_counts.remove(tuple.object)
    let type_name = @fga.object_type(tuple.object)
    match self.objects_by_type.get(type_name) {
      Some(objects) => {
        let kept = objects.filter(fn(o) { o != tuple.object })
        if kept.is_empty() {
          self.objects_by_type.remove(type_name)
        } else {
          self.objects_by_type[type_name] = kept
        }
      }
      None => ()
    }
  } else {
    self.object_counts[tuple.object] = remaining
  }
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
/// Deletes exact tuples, returning the number removed.
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
/// Removes all tuples and resets every index.
pub fn MemoryStore::clear(self : MemoryStore) -> Unit {
  self.tuples.clear()
  self.by_object.clear()
  self.by_user.clear()
  self.keys.clear()
  self.objects_by_type.clear()
  self.object_counts.clear()
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
/// Returns an insertion-ordered copy of all stored tuples.
pub fn MemoryStore::all_tuples(self : MemoryStore) -> Array[@fga.Tuple] {
  self.tuples.copy()
}

///|
/// Distinct object strings of the requested type, in insertion order.
pub fn MemoryStore::all_objects(
  self : MemoryStore,
  type_name : String,
) -> Array[String] {
  match self.objects_by_type.get(type_name) {
    Some(objects) => objects.copy()
    None => []
  }
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
/// Returns the number of distinct stored tuples.
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
pub struct ContextualStore {
  priv base : &@fga.TupleReader
  priv extra : MemoryStore
  priv shadow : Bool
}

///|
/// Creates a request-scoped reader. By default contextual triples shadow base
/// triples (Check semantics). With shadow=false both streams remain visible,
/// including different condition bindings (OpenFGA List API semantics).
pub fn ContextualStore::new(
  base : &@fga.TupleReader,
  tuples : Array[@fga.Tuple],
  shadow~ : Bool = true,
) -> ContextualStore {
  let extra = MemoryStore::new()
  let _ = extra.write_all(tuples)
  ContextualStore::{ base, extra, shadow, }
}

///|
/// Creates a request overlay backed by an in-memory store.
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
  shadow : Bool,
) -> Array[@fga.Tuple] {
  if !shadow {
    a.append(b)
    return a
  }
  let seen : Map[String, Unit] = Map([])
  let out : Array[@fga.Tuple] = []
  for t in a {
    let key = t.object + "#" + t.relation + "@" + t.user
    if !seen.contains(key) {
      seen[key] = ()
      out.push(t)
    }
  }
  for t in b {
    let key = t.object + "#" + t.relation + "@" + t.user
    if !seen.contains(key) {
      seen[key] = ()
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
    self.shadow,
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
    self.shadow,
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
