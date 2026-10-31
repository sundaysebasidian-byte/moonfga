// Smoke test for the browser bundle.
//
//   scripts/build-web.sh && node web/smoke.mjs [dist-dir]
//
// Calls the exported functions the page uses and asserts the answers for the
// built-in examples.
import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { examples, testsSource } from "./examples.js";
import { buildTree, countNodes } from "./explain.js";

const here = dirname(fileURLToPath(import.meta.url));
const dist = resolve(process.argv[2] ?? resolve(here, "dist"));
const fga = await import(pathToFileURL(resolve(dist, "moonfga.js")).href);

const call = (name, request) => JSON.parse(fga[name](JSON.stringify(request)));
let passed = 0;
function test(name, fn) {
  try {
    fn();
    passed += 1;
    console.log(`ok   ${name}`);
  } catch (error) {
    console.error(`FAIL ${name}\n${error.stack}`);
    process.exitCode = 1;
  }
}

for (const example of examples) {
  const base = { model: example.model, tuples: example.tuples };
  const expect = example.expect;

  test(`${example.id}: model is valid`, () => {
    assert.deepEqual(call("validate_model", { model: example.model }), { ok: true, valid: true, issues: [] });
  });

  test(`${example.id}: DSL -> JSON -> DSL keeps the model`, () => {
    const json = call("dsl_to_json", { model: example.model });
    assert.equal(json.ok, true);
    assert.ok(JSON.parse(json.output).type_definitions.length > 0);
    const dsl = call("json_to_dsl", { model: json.output });
    assert.equal(dsl.ok, true);
    assert.equal(call("dsl_to_json", { model: dsl.output }).output, json.output);
  });

  test(`${example.id}: check allowed with explain`, () => {
    const res = call("check", { ...base, ...example.check, explain: true });
    assert.equal(res.ok, true);
    assert.equal(res.allowed, expect.check.allowed);
    const tree = buildTree(res.paths);
    assert.equal(tree.length, 1, "one root");
    assert.ok(tree[0].label.startsWith(`${example.check.object}#${example.check.relation}`), tree[0].label);
    assert.equal(countNodes(tree), expect.check.pathSteps);
    assert.equal(call("check", { ...base, ...example.check }).allowed, true);
  });

  test(`${example.id}: check denied`, () => {
    const res = call("check", { ...base, ...expect.denied, explain: true });
    assert.equal(res.ok, true);
    assert.equal(res.allowed, false);
    assert.deepEqual(res.paths, []);
  });

  test(`${example.id}: list-objects`, () => {
    const res = call("list_objects", { ...base, ...example.listObjects });
    assert.equal(res.ok, true);
    assert.deepEqual([...res.objects].sort(), expect.listObjects);
  });

  test(`${example.id}: list-users`, () => {
    const res = call("list_users", { ...base, ...example.listUsers });
    assert.equal(res.ok, true);
    assert.deepEqual([...res.users].sort(), expect.listUsers);
  });

  test(`${example.id}: .fga.yaml suite passes`, () => {
    const res = call("run_tests", { source: testsSource(example) });
    assert.equal(res.ok, true, JSON.stringify(res));
    assert.deepEqual(res.failures, []);
    assert.equal(res.tests_failed, 0);
    assert.ok(res.assertions_total > 0);
    assert.equal(res.assertions_passed, res.assertions_total);
  });
}

test("validation errors carry line and column", () => {
  const model = "model\n  schema 1.1\n\ntype user\n\ntype doc\n  relations\n    define viewer: [usr]\n";
  const res = call("validate_model", { model });
  assert.equal(res.ok, true);
  assert.equal(res.valid, false);
  assert.equal(res.issues[0].line, 8);
  assert.equal(res.issues[0].symbol, "usr");
});

test("syntax errors are reported as issues with a line", () => {
  const model = "model\n  schema 1.1\n\ntype user\n\ntype doc\n  relations\n    defin viewer: [user]\n";
  const res = call("validate_model", { model });
  assert.equal(res.valid, false);
  assert.equal(res.issues[0].line, 8);
});

test("queries on an invalid model return an error with issues", () => {
  const model = "model\n  schema 1.1\n\ntype user\n\ntype doc\n  relations\n    define viewer: [usr]\n";
  const res = call("check", { model, object: "doc:1", relation: "viewer", user: "user:a" });
  assert.equal(res.ok, false);
  assert.equal(res.error.line, 8);
  assert.equal(res.issues.length, 1);
});

test("explain keeps the decision of a plain check and reports completeness", () => {
  const abac = examples.find((e) => e.id === "abac");
  const base = { model: abac.model, tuples: abac.tuples, relation: "viewer", object: "document:plan" };
  const contexts = [
    {},
    { current_time: "2026-10-20T00:00:00Z" },
    { current_time: "2027-01-01T00:00:00Z" },
    { ip: "10.1.2.3" },
    { current_time: "2026-10-20T00:00:00Z", ip: "192.168.0.9" },
  ];
  for (const user of ["user:dana", "user:erin", "user:anne", "user:zed"]) {
    for (const context of contexts) {
      const query = { ...base, user, context };
      const plain = call("check", query);
      const explained = call("check", { ...query, explain: true });
      assert.equal(explained.ok, plain.ok, JSON.stringify({ user, context }));
      if (!plain.ok) continue;
      assert.equal(explained.allowed, plain.allowed, JSON.stringify({ user, context }));
      assert.equal(typeof explained.complete, "boolean");
      assert.equal(explained.complete, !explained.allowed || explained.paths.length > 0);
      assert.equal("explain_error" in explained, !explained.complete);
    }
  }
});

test("allowed explanations are complete and carry a path", () => {
  for (const example of examples) {
    const res = call("check", { model: example.model, tuples: example.tuples, ...example.check, explain: true });
    assert.equal(res.complete, true, example.id);
    assert.ok(res.paths.length > 0, example.id);
    assert.equal("explain_error" in res, false, example.id);
  }
});

test("list-users filters: absent, null and valid values are accepted", () => {
  const e = examples[0];
  const q = { model: e.model, tuples: e.tuples, object: "repo:api", relation: "reader" };
  const all = call("list_users", q);
  assert.equal(all.ok, true);
  assert.deepEqual(call("list_users", { ...q, filters: null }), all);
  assert.deepEqual(call("list_users", { ...q, filters: ["user"] }).users, all.users);
  assert.deepEqual(call("list_users", { ...q, filters: "user" }).users, all.users);
});

for (const [label, filters] of [
  ["number", 42],
  ["object", { type: "user" }],
  ["boolean", true],
  ["mixed array", ["user", 1]],
  ["array holding null", ["user", null]],
  ["blank string", " , "],
]) {
  test(`list-users rejects filters of kind ${label}`, () => {
    const e = examples[0];
    const res = call("list_users", { model: e.model, tuples: e.tuples, object: "repo:api", relation: "reader", filters });
    assert.equal(res.ok, false);
    assert.match(res.error.message, /filters/);
  });
}

test("tuples accept an array or a string, not an object", () => {
  const e = examples[0];
  const q = { model: e.model, ...e.check };
  const wrapped = call("check", { ...q, tuples: { tuples: [] } });
  assert.equal(wrapped.ok, false);
  assert.match(wrapped.error.message, /tuples/);
  const asString = call("check", { ...q, tuples: JSON.stringify({ tuples: [] }) });
  assert.equal(asString.ok, false);
  assert.match(asString.error.message, /JSON array/);
});

test("errors are JSON, never exceptions", () => {
  for (const name of ["validate_model", "dsl_to_json", "json_to_dsl", "check", "list_objects", "list_users", "run_tests"]) {
    const garbage = JSON.parse(fga[name]("not json"));
    assert.equal(garbage.ok, false, name);
    assert.equal(typeof garbage.error.message, "string", name);
    const empty = JSON.parse(fga[name]("{}"));
    assert.equal(typeof empty.ok, "boolean", name);
  }
  const suite = call("run_tests", { source: "name: x\nmodel_file: m.fga\ntests: []\n" });
  assert.equal(suite.ok, false);
  const bad = call("check", { model: examples[0].model, tuples: "nonsense", object: "repo:api", relation: "reader", user: "user:bob" });
  assert.equal(bad.ok, false);
});

test("tuples accept text, JSON text and arrays", () => {
  const e = examples[0];
  const q = { model: e.model, ...e.check };
  const asText = call("check", { ...q, tuples: e.tuples });
  const asArray = call("check", {
    ...q,
    tuples: e.tuples
      .trim()
      .split("\n")
      .map((line) => {
        const [lhs, user] = line.split(/@(.+)/);
        const [object, relation] = lhs.split(/#(.+)/);
        return { object, relation, user };
      }),
  });
  assert.equal(asText.allowed, true);
  assert.equal(asArray.allowed, true);
  assert.equal(call("check", { ...q, tuples: JSON.stringify([]) }).allowed, false);
});

console.log(`${passed} checks passed`);
if (process.exitCode) console.error("smoke test failed");
