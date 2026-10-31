// Built-in examples. Each one carries the model, the tuples, a default query
// per panel and the expected answers used by web/smoke.mjs.

export const examples = [
  {
    id: "github",
    label: "GitHub",
    model: `model
  schema 1.1

type user

type team
  relations
    define member: [user]

type organization
  relations
    define owner: [user]
    define member: [user, team#member] or owner
    define repo_admin: [user, team#member]

type repo
  relations
    define owner: [organization]
    define admin: [user, team#member] or repo_admin from owner
    define maintainer: [user, team#member] or admin
    define writer: [user, team#member] or maintainer
    define reader: [user, team#member] or writer or member from owner
`,
    tuples: `organization:acme#owner@user:anne
organization:acme#member@team:platform#member
team:platform#member@user:bob
team:platform#member@user:carol
repo:api#owner@organization:acme
repo:api#maintainer@user:dave
repo:web#owner@organization:acme
repo:web#writer@team:platform#member
`,
    check: { user: "user:bob", relation: "reader", object: "repo:api" },
    listObjects: { user: "user:bob", relation: "writer", type: "repo" },
    listUsers: { object: "repo:api", relation: "reader", filters: "user" },
    expect: {
      check: { allowed: true, pathSteps: 5 },
      denied: { user: "user:dave", relation: "admin", object: "repo:web" },
      listObjects: ["repo:web"],
      listUsers: ["user:anne", "user:bob", "user:carol", "user:dave"],
    },
    tests: `tests:
  - name: repo access
    check:
      - user: user:bob
        object: repo:api
        assertions:
          reader: true
          writer: false
      - user: user:dave
        object: repo:api
        assertions:
          writer: true
    listObjects:
      - user: user:bob
        type: repo
        assertions:
          writer: [repo:web]
`,
  },
  {
    id: "drive",
    label: "Drive",
    model: `model
  schema 1.1

type user

type group
  relations
    define member: [user]

type folder
  relations
    define parent: [folder]
    define owner: [user]
    define editor: [user, group#member] or owner or editor from parent
    define viewer: [user, group#member] or editor or viewer from parent

type doc
  relations
    define parent: [folder]
    define owner: [user]
    define editor: [user, group#member] or owner or editor from parent
    define commenter: [user, group#member] or editor
    define viewer: [user, user:*, group#member] or commenter or viewer from parent
`,
    tuples: `group:design#member@user:erin
group:design#member@user:frank
folder:projects#owner@user:anne
folder:q4#parent@folder:projects
doc:roadmap#parent@folder:q4
doc:roadmap#commenter@group:design#member
doc:press-kit#owner@user:grace
doc:press-kit#viewer@user:*
`,
    check: { user: "user:anne", relation: "editor", object: "doc:roadmap" },
    listObjects: { user: "user:erin", relation: "viewer", type: "doc" },
    listUsers: { object: "doc:roadmap", relation: "viewer", filters: "user" },
    expect: {
      check: { allowed: true, pathSteps: 7 },
      denied: { user: "user:erin", relation: "editor", object: "doc:roadmap" },
      listObjects: ["doc:press-kit", "doc:roadmap"],
      listUsers: ["user:anne", "user:erin", "user:frank"],
    },
    tests: `tests:
  - name: sharing
    check:
      - user: user:anne
        object: doc:roadmap
        assertions:
          editor: true
      - user: user:erin
        object: doc:roadmap
        assertions:
          commenter: true
          editor: false
      - user: user:zed
        object: doc:press-kit
        assertions:
          viewer: true
`,
  },
  {
    id: "abac",
    label: "ABAC",
    model: `model
  schema 1.1

type user

condition non_expired_grant(current_time: timestamp, grant_time: timestamp, grant_duration: duration) {
  current_time < grant_time + grant_duration
}

condition from_office(ip: ipaddress) {
  ip.in_cidr("10.0.0.0/8")
}

type document
  relations
    define owner: [user]
    define viewer: [user with non_expired_grant, user with from_office] or owner
`,
    tuples: `document:plan#owner@user:anne
document:plan#viewer@user:dana[non_expired_grant:{"grant_time":"2026-10-01T00:00:00Z","grant_duration":"720h"}]
document:plan#viewer@user:erin[from_office]
`,
    check: {
      user: "user:dana",
      relation: "viewer",
      object: "document:plan",
      context: '{"current_time": "2026-10-20T00:00:00Z", "ip": "192.168.0.9"}',
    },
    listObjects: {
      user: "user:erin",
      relation: "viewer",
      type: "document",
      context: '{"ip": "10.1.2.3"}',
    },
    listUsers: {
      object: "document:plan",
      relation: "viewer",
      filters: "user",
      context: '{"current_time": "2026-10-20T00:00:00Z", "ip": "192.168.0.9"}',
    },
    expect: {
      check: { allowed: true, pathSteps: 1 },
      denied: {
        user: "user:dana",
        relation: "viewer",
        object: "document:plan",
        context: { current_time: "2027-01-01T00:00:00Z" },
      },
      listObjects: ["document:plan"],
      listUsers: ["user:anne", "user:dana"],
    },
    tests: `tests:
  - name: grants
    check:
      - user: user:dana
        object: document:plan
        context: {current_time: "2026-10-20T00:00:00Z"}
        assertions:
          viewer: true
      - user: user:dana
        object: document:plan
        context: {current_time: "2027-01-01T00:00:00Z"}
        assertions:
          viewer: false
      - user: user:erin
        object: document:plan
        context: {ip: "10.1.2.3"}
        assertions:
          viewer: true
`,
  },
];

// Builds a self-contained `.fga.yaml` suite (inline model, no model_file)
// from an example, for the Tests tab.
function tuplesToYaml(text) {
  const rows = [];
  for (const raw of text.split("\n")) {
    const line = raw.trim();
    if (!line || line.startsWith("#")) continue;
    const match = line.match(/^([^#\s]+)#([^@\s]+)@([^\s[]+)(?:\[(\w+)(?::(.*))?\])?$/);
    if (!match) continue;
    const [, object, relation, user, condition, context] = match;
    let row = `  - object: ${object}\n    relation: ${relation}\n    user: ${user}\n`;
    if (condition) {
      row += `    condition:\n      name: ${condition}\n`;
      if (context) row += `      context: ${context}\n`;
    }
    rows.push(row);
  }
  return rows.join("");
}

export function testsSource(example) {
  const model = example.model.trimEnd().split("\n").map((line) => (line ? `  ${line}` : "")).join("\n");
  return `name: ${example.label}\nmodel: |\n${model}\ntuples:\n${tuplesToYaml(example.tuples)}${example.tests}`;
}
