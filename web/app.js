import * as fga from "./moonfga.js";
import { examples, testsSource } from "./examples.js";
import { buildTree } from "./explain.js";

const $ = (id) => document.getElementById(id);

function call(name, request) {
  return JSON.parse(fga[name](JSON.stringify(request)));
}

function debounce(fn, ms) {
  let timer = 0;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), ms);
  };
}

function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

/* ---------- editor ---------- */

function createEditor(host, { onInput, marks = true }) {
  const gutter = el("div", "gutter");
  const stage = el("div", "stage");
  const layer = el("div", "marks");
  const area = el("textarea");
  area.spellcheck = false;
  area.autocapitalize = "off";
  area.setAttribute("autocomplete", "off");
  area.wrap = "off";
  stage.append(layer, area);
  host.append(gutter, stage);

  let errorLines = new Set();

  function render() {
    const count = area.value.split("\n").length;
    const numbers = [];
    const rows = [];
    for (let i = 1; i <= count; i++) {
      const bad = errorLines.has(i);
      numbers.push(bad ? `<span class="bad">${i}</span>` : String(i));
      rows.push(bad ? '<div class="bad"></div>' : "<div></div>");
    }
    gutter.innerHTML = numbers.join("\n");
    if (marks) layer.innerHTML = rows.join("");
    sync();
  }

  function sync() {
    gutter.scrollTop = area.scrollTop;
    layer.scrollTop = area.scrollTop;
  }

  area.addEventListener("scroll", sync);
  area.addEventListener("input", () => {
    render();
    onInput?.();
  });
  area.addEventListener("keydown", (event) => {
    if (event.key === "Tab" && !event.shiftKey) {
      event.preventDefault();
      area.setRangeText("  ", area.selectionStart, area.selectionEnd, "end");
      area.dispatchEvent(new Event("input"));
    }
  });

  render();
  return {
    get value() {
      return area.value;
    },
    set value(text) {
      area.value = text;
      area.scrollTop = 0;
      render();
    },
    setErrorLines(lines) {
      errorLines = new Set(lines);
      render();
    },
    reveal(line, column) {
      const lines = area.value.split("\n");
      let offset = 0;
      for (let i = 0; i < line - 1 && i < lines.length; i++) offset += lines[i].length + 1;
      offset += Math.max(0, (column || 1) - 1);
      area.focus();
      area.setSelectionRange(offset, offset);
      const top = (line - 1) * 21;
      if (top < area.scrollTop || top > area.scrollTop + area.clientHeight - 42) {
        area.scrollTop = Math.max(0, top - area.clientHeight / 3);
      }
    },
  };
}

/* ---------- state ---------- */

const state = { example: null, format: "dsl", tab: "check" };

const modelEditor = createEditor($("model-editor"), { onInput: onModelInput });
const tuplesEditor = createEditor($("tuples-editor"), { onInput: refresh, marks: false });
const testsEditor = createEditor($("tests-editor"), { marks: false });

const fields = {
  checkUser: $("check-user"),
  checkRelation: $("check-relation"),
  checkObject: $("check-object"),
  checkContext: $("check-context"),
  objectsUser: $("objects-user"),
  objectsRelation: $("objects-relation"),
  objectsType: $("objects-type"),
  objectsContext: $("objects-context"),
  usersObject: $("users-object"),
  usersRelation: $("users-relation"),
  usersFilters: $("users-filters"),
  usersContext: $("users-context"),
};

/* ---------- validation ---------- */

function renderIssues(issues) {
  const list = $("issues");
  list.replaceChildren();
  list.hidden = issues.length === 0;
  const lines = [];
  for (const issue of issues) {
    const item = el("li");
    const located = issue.line > 0;
    item.append(el("span", "pos", located ? `${issue.line}:${issue.column}` : ""), el("span", "msg", issue.message));
    if (located) {
      lines.push(issue.line);
      item.addEventListener("click", () => modelEditor.reveal(issue.line, issue.column));
    }
    list.append(item);
  }
  modelEditor.setErrorLines(lines);
}

function onModelInput() {
  syncSuggestions();
  refresh();
}

function validate() {
  const res = call("validate_model", { model: modelEditor.value });
  renderIssues(res.ok ? res.issues : [{ message: res.error.message, line: -1, column: -1 }]);
  return res.ok && res.valid;
}

/* ---------- suggestions ---------- */

function setOptions(id, values) {
  $(id).replaceChildren(
    ...[...values].map((value) => {
      const option = document.createElement("option");
      option.value = value;
      return option;
    }),
  );
}

function syncSuggestions() {
  const tuples = tuplesEditor.value.split("\n").map((line) => line.trim()).filter((line) => line && !line.startsWith("#"));
  const users = new Set();
  const objects = new Set();
  for (const line of tuples) {
    const match = line.match(/^([^#\s]+)#([^@\s]+)@([^\s[]+)/);
    if (!match) continue;
    objects.add(match[1]);
    if (!match[3].includes("#") && !match[3].endsWith(":*")) users.add(match[3]);
  }
  const converted = call("dsl_to_json", { model: modelEditor.value });
  const relations = new Set();
  const types = new Set();
  if (converted.ok) {
    try {
      for (const def of JSON.parse(converted.output).type_definitions) {
        types.add(def.type);
        for (const name of Object.keys(def.relations ?? {})) relations.add(name);
      }
    } catch {
      /* suggestions are optional */
    }
  }
  setOptions("dl-users", users);
  setOptions("dl-objects", objects);
  setOptions("dl-relations", relations);
  setOptions("dl-types", types);
  const hasConditions = /\bcondition\b|"conditions"/.test(modelEditor.value);
  document.querySelectorAll(".ctx").forEach((node) => (node.hidden = !hasConditions));
}

/* ---------- queries ---------- */

function base() {
  return { model: modelEditor.value, tuples: tuplesEditor.value };
}

function showError(host, error) {
  host.replaceChildren(el("div", "error", error.message));
}

function renderTree(nodes) {
  const root = el("ul", "tree");
  const fill = (list, nodesAtLevel) => {
    for (const node of nodesAtLevel) {
      const item = el("li");
      item.append(el("span", `step ${node.kind}`, node.label));
      if (node.children.length) {
        const sub = el("ul");
        fill(sub, node.children);
        item.append(sub);
      }
      list.append(item);
    }
  };
  fill(root, nodes);
  return root;
}

function runCheck() {
  const host = $("result-check");
  const res = call("check", {
    ...base(),
    user: fields.checkUser.value.trim(),
    relation: fields.checkRelation.value.trim(),
    object: fields.checkObject.value.trim(),
    context: fields.checkContext.value,
    explain: true,
  });
  if (!res.ok) return showError(host, res.error);
  const verdict = el("div", `verdict ${res.allowed ? "ok" : "no"}`, res.allowed ? "Allowed" : "Denied");
  host.replaceChildren(verdict);
  if (res.paths.length) host.append(renderTree(buildTree(res.paths)));
}

function renderList(host, values) {
  const head = el("div", "count", String(values.length));
  const chips = el("div", "chips");
  for (const value of values) chips.append(el("span", "chip", value));
  host.replaceChildren(head, chips);
}

function runObjects() {
  const host = $("result-objects");
  const res = call("list_objects", {
    ...base(),
    user: fields.objectsUser.value.trim(),
    relation: fields.objectsRelation.value.trim(),
    type: fields.objectsType.value.trim(),
    context: fields.objectsContext.value,
  });
  if (!res.ok) return showError(host, res.error);
  renderList(host, res.objects);
}

function runUsers() {
  const host = $("result-users");
  const res = call("list_users", {
    ...base(),
    object: fields.usersObject.value.trim(),
    relation: fields.usersRelation.value.trim(),
    filters: fields.usersFilters.value,
    context: fields.usersContext.value,
  });
  if (!res.ok) return showError(host, res.error);
  renderList(host, res.users);
}

function runTests() {
  const host = $("result-tests");
  const res = call("run_tests", { source: testsEditor.value });
  if (!res.ok) return showError(host, res.error);
  const passed = res.tests_failed === 0;
  const line = el("div", "report-line");
  line.append(
    el("span", `verdict ${passed ? "ok" : "no"}`, passed ? "Passed" : "Failed"),
    el("span", "count", `${res.tests_passed}/${res.tests_total} tests`),
    el("span", "count", `${res.assertions_passed}/${res.assertions_total} assertions`),
  );
  host.replaceChildren(line);
  for (const failure of res.failures) {
    const box = el("div", "failure");
    box.append(
      el("div", "head", `${failure.test} · ${failure.section} ${failure.request}`),
      el("div", "row", `expected ${failure.expected}`),
      el("div", "row", `actual   ${failure.actual}`),
    );
    if (failure.message) box.append(el("div", "row", failure.message));
    host.append(box);
  }
}

const runners = { check: runCheck, objects: runObjects, users: runUsers };

function refresh() {
  const valid = validate();
  const host = $(`result-${state.tab}`);
  if (state.tab === "tests") return;
  if (!valid) {
    host?.replaceChildren();
    return;
  }
  runners[state.tab]?.();
}

const refreshSoon = debounce(refresh, 80);
for (const input of Object.values(fields)) input.addEventListener("input", refreshSoon);

/* ---------- tabs ---------- */

function selectTab(name) {
  state.tab = name;
  document.querySelectorAll("#tabs button").forEach((button) => {
    button.setAttribute("aria-selected", String(button.dataset.tab === name));
  });
  for (const id of ["check", "objects", "users", "tests"]) $(`panel-${id}`).hidden = id !== name;
  refresh();
}
document.querySelectorAll("#tabs button").forEach((button) => {
  button.addEventListener("click", () => selectTab(button.dataset.tab));
});
$("run-tests").addEventListener("click", runTests);

/* ---------- format toggle ---------- */

function setFormat(format, convert) {
  if (convert && format !== state.format) {
    const name = format === "json" ? "dsl_to_json" : "json_to_dsl";
    const res = call(name, { model: modelEditor.value });
    if (!res.ok) {
      renderIssues([{ message: res.error.message, line: res.error.line, column: res.error.column }]);
      return;
    }
    modelEditor.value = res.output;
  }
  state.format = format;
  document.querySelectorAll("#format button").forEach((button) => {
    button.setAttribute("aria-pressed", String(button.dataset.format === format));
  });
  onModelInput();
}
document.querySelectorAll("#format button").forEach((button) => {
  button.addEventListener("click", () => setFormat(button.dataset.format, true));
});

/* ---------- examples ---------- */

function loadExample(example) {
  state.example = example;
  document.querySelectorAll("#examples button").forEach((button) => {
    button.setAttribute("aria-pressed", String(button.dataset.id === example.id));
  });
  modelEditor.value = example.model.trimEnd();
  tuplesEditor.value = example.tuples.trimEnd();
  testsEditor.value = testsSource(example);
  state.format = "dsl";
  document.querySelectorAll("#format button").forEach((button) => {
    button.setAttribute("aria-pressed", String(button.dataset.format === "dsl"));
  });
  const { check, listObjects, listUsers } = example;
  fields.checkUser.value = check.user;
  fields.checkRelation.value = check.relation;
  fields.checkObject.value = check.object;
  fields.checkContext.value = check.context ?? "";
  fields.objectsUser.value = listObjects.user;
  fields.objectsRelation.value = listObjects.relation;
  fields.objectsType.value = listObjects.type;
  fields.objectsContext.value = listObjects.context ?? "";
  fields.usersObject.value = listUsers.object;
  fields.usersRelation.value = listUsers.relation;
  fields.usersFilters.value = listUsers.filters;
  fields.usersContext.value = listUsers.context ?? "";
  $("result-tests").replaceChildren();
  syncSuggestions();
  refresh();
}

const exampleNav = $("examples");
for (const example of examples) {
  const button = el("button", "", example.label);
  button.type = "button";
  button.dataset.id = example.id;
  button.addEventListener("click", () => loadExample(example));
  exampleNav.append(button);
}

/* ---------- theme ---------- */

$("theme").addEventListener("click", () => {
  const root = document.documentElement;
  const dark =
    root.dataset.theme === "dark" ||
    (!root.dataset.theme && matchMedia("(prefers-color-scheme: dark)").matches);
  const next = dark ? "light" : "dark";
  root.dataset.theme = next;
  localStorage.setItem("theme", next);
});

selectTab("check");
loadExample(examples[0]);
