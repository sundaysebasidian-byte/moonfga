// Turns the witness paths returned by `check` into a tree.

export function normalizePath(steps) {
  const out = [];
  for (const step of steps) {
    if (out.length === 0 || out[out.length - 1] !== step) out.push(step);
  }
  return out;
}

export function stepKind(step) {
  if (step.startsWith("computed ")) return "rewrite";
  if (step.includes("@")) return "tuple";
  return "node";
}

// Merges paths that share a prefix. Returns a list of root nodes
// `{ label, kind, children }`.
export function buildTree(paths) {
  const roots = [];
  for (const raw of paths) {
    let level = roots;
    for (const step of normalizePath(raw)) {
      let node = level.find((n) => n.label === step);
      if (!node) {
        node = { label: step, kind: stepKind(step), children: [] };
        level.push(node);
      }
      level = node.children;
    }
  }
  return roots;
}

export function countNodes(nodes) {
  let total = 0;
  for (const node of nodes) total += 1 + countNodes(node.children);
  return total;
}
