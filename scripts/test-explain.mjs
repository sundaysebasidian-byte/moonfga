// Run after: moon build --target js --release
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { check } from "../_build/js/release/build/playground/playground.js";
const model = "examples/regressions/explain/model.fga";
const tuples = "examples/regressions/explain/tuples.json";
const req = { model: readFileSync(model, "utf8"), tuples: JSON.parse(readFileSync(tuples, "utf8")),
  object: "document:0", relation: "viewer", user: "user:0", explain: true };
const api = JSON.parse(check(JSON.stringify(req)));
assert.equal(api.ok, true);
assert.equal(api.allowed, true);
assert.equal(api.complete, true);
assert(api.paths.flat().some(s => s.includes("owner@user:0")));
delete api.ok;
const cli = spawnSync("moon", ["run", "--target", "native", "cmd/main", "--", "check",
  "--model", model, "--store", tuples, "--object", req.object, "--relation", req.relation,
  "--user", req.user, "--explain", "--json"], { encoding: "utf8" });
assert.equal(cli.status, 0, cli.stderr);
assert.deepEqual(JSON.parse(cli.stdout), api);
console.log("Explain CLI / JS: same allowed decision, owner witness, complete status");
