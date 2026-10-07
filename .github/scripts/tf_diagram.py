#!/usr/bin/env python3
"""Build a readable Graphviz diagram from a Terraform plan + `terraform graph`.

Why not just render `terraform graph`?  It is a dependency dump full of
var/local/output/provider nodes, and it knows nothing about azapi resources
(it only sees "azapi_resource.this").  Here we:

  * take the RESOURCES from the plan JSON (so we know each azapi_resource's
    real Azure type, e.g. Microsoft.Storage/storageAccounts, and its name),
  * take the DEPENDENCIES from `terraform graph`, bridging across var/local/
    output/data nodes so that  rg -> var.parent_id -> sa  becomes  rg -> sa,
  * group resources into nested clusters per module,
  * drop noise (telemetry, random_*, time_*, ...) and redundant edges.

Arrows point from a dependency to the thing that depends on it
(e.g. resource group -> storage account).

Usage:
  tf_diagram.py --plan plan.json --graph graph.dot --out diagram.dot
  dot -Tsvg diagram.dot -o diagram.svg
"""
import argparse
import json
import re
import sys
from collections import defaultdict

DEFAULT_IGNORE_PREFIXES = ("modtm_", "random_", "time_", "null_", "tls_")
DEFAULT_IGNORE_TYPES = {"terraform_data"}

INDEX_RE = re.compile(r'\[(?:"(?:[^"\\]|\\.)*"|[^\]])*\]')
EDGE_RE = re.compile(r'"((?:[^"\\]|\\.)*)"\s*->\s*"((?:[^"\\]|\\.)*)"')
PASSTHROUGH_RE = re.compile(r"(?:^|\.)(?:var|local|output|data)\.")


def strip_index(addr: str) -> str:
    return INDEX_RE.sub("", addr)


def norm_graph_label(label: str) -> str:
    label = label.replace('\\"', '"')
    label = label.replace("[root] ", "")
    return strip_index(label.replace(" (expand)", "").strip())


def split_address(addr: str):
    """module.a.module.b.type.name -> (['module.a', 'module.b'], 'type.name')"""
    m = re.match(r"^((?:module\.[^.]+\.)*)(.+)$", addr)
    mods = [p for p in re.findall(r"module\.[^.]+", m.group(1))]
    return mods, m.group(2)


def load_resources(plan_path, ignore_prefixes, ignore_types, include_data):
    plan = json.load(open(plan_path))
    nodes = {}
    for rc in plan.get("resource_changes", []):
        if rc.get("mode") != "managed" and not (include_data and rc.get("mode") == "data"):
            continue
        actions = rc.get("change", {}).get("actions", [])
        if actions == ["delete"]:
            continue
        rtype = rc["type"]
        if rtype in ignore_types or rtype.startswith(ignore_prefixes):
            continue
        addr = strip_index(rc["address"])
        after = rc.get("change", {}).get("after") or {}
        if addr in nodes:
            nodes[addr]["count"] += 1
            continue
        nodes[addr] = {
            "type": rtype,
            "name": rc.get("name", ""),
            "after": after,
            "count": 1,
        }
    return nodes


def load_edges(graph_path):
    """Return adjacency: node -> set(dependencies)  (terraform: A -> B means A depends on B)."""
    dot = open(graph_path).read()
    adj = defaultdict(set)
    for src, dst in EDGE_RE.findall(dot):
        adj[norm_graph_label(src)].add(norm_graph_label(dst))
    return adj


def contract_edges(nodes, adj):
    """dependency -> dependent edges between kept nodes, bridging pass-through nodes."""
    links = set()
    for r in nodes:
        visited = {r}
        stack = list(adj.get(r, ()))
        while stack:
            m = stack.pop()
            if m in visited:
                continue
            visited.add(m)
            if m in nodes:
                links.add((m, r))
            elif PASSTHROUGH_RE.search(m):
                stack.extend(adj.get(m, ()))
            # anything else (providers, module (expand)/(close), root): stop
    links = {(a, b) for a, b in links if a != b}
    return links


def transitive_reduction(links):
    out = defaultdict(set)
    for a, b in links:
        out[a].add(b)

    def reachable_without(a, b):
        seen, stack = set(), [n for n in out[a] if n != b]
        while stack:
            n = stack.pop()
            if n == b:
                return True
            if n in seen:
                continue
            seen.add(n)
            stack.extend(out[n])
        return False

    return {(a, b) for a, b in links if not reachable_without(a, b)}


def esc(s: str) -> str:
    return (str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


def node_label(addr, info):
    rtype, after = info["type"], info["after"]
    name = after.get("name") if isinstance(after.get("name"), str) else None
    leaf = split_address(addr)[1].split(".", 1)[-1]  # resource name part
    if rtype == "azapi_resource" and isinstance(after.get("type"), str):
        azure_type = after["type"].split("@")[0]            # Microsoft.Storage/storageAccounts
        ns, _, kind = azure_type.partition("/")
        title, sub = kind or azure_type, ns
    else:
        title, sub = rtype, ""
    if info["count"] > 1:
        line3 = f"{leaf}  ×{info['count']}"   # count/for_each: instance names differ
    else:
        line3 = name or leaf
    parts = [f'<B>{esc(title)}</B>']
    if sub:
        parts.append(f'<FONT POINT-SIZE="9" COLOR="#555555">{esc(sub)}</FONT>')
    parts.append(f'<FONT POINT-SIZE="10">{esc(line3)}</FONT>')
    return "<" + "<BR/>".join(parts) + ">"


def node_fill(rtype):
    if rtype.startswith("azapi"):
        return "#dbeafe"
    if rtype.startswith("azurerm"):
        return "#e0f2fe"
    return "#f3f4f6"


def nid(addr):
    return "n_" + re.sub(r"[^A-Za-z0-9_]", "_", addr)


def build_dot(nodes, links, title):
    tree = {"children": {}, "nodes": []}
    for addr in sorted(nodes):
        mods, _ = split_address(addr)
        cur = tree
        for m in mods:
            cur = cur["children"].setdefault(m, {"children": {}, "nodes": []})
        cur["nodes"].append(addr)

    lines = [
        "digraph terraform {",
        '  rankdir=LR; compound=true; newrank=true; nodesep=0.35; ranksep=0.8;',
        f'  label=<<B>{esc(title)}</B>>; labelloc=t; fontname="Helvetica"; fontsize=18;',
        '  node [shape=box, style="rounded,filled", fontname="Helvetica", fontsize=11, margin="0.15,0.08"];',
        '  edge [color="#6b7280", arrowsize=0.7];',
    ]

    counter = [0]

    def emit(sub, indent, name=None):
        pad = "  " * indent
        if name:
            counter[0] += 1
            lines.append(f"{pad}subgraph cluster_{counter[0]} {{")
            lines.append(
                f'{pad}  label=<<B>{esc(name)}</B>>; style="rounded,filled"; '
                f'fillcolor="#fafafa"; color="#9ca3af"; fontname="Helvetica"; fontsize=12;'
            )
        for addr in sub["nodes"]:
            info = nodes[addr]
            lines.append(
                f'{pad}  {nid(addr)} [label={node_label(addr, info)}, fillcolor="{node_fill(info["type"])}", '
                f'color="#94a3b8"];'
            )
        for child_name, child in sorted(sub["children"].items()):
            emit(child, indent + 1, child_name)
        if name:
            lines.append(f"{pad}}}")

    emit(tree, 1)
    for a, b in sorted(links):
        lines.append(f"  {nid(a)} -> {nid(b)};")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--plan", required=True, help="plan JSON from `terraform show -json tfplan`")
    ap.add_argument("--graph", required=True, help="DOT from `terraform graph`")
    ap.add_argument("--out", required=True, help="Graphviz DOT file to write")
    ap.add_argument("--title", default="Terraform infrastructure")
    ap.add_argument("--include-data", action="store_true", help="also show data sources")
    ap.add_argument("--ignore-type-prefix", action="append", default=[],
                    help="extra resource type prefix to hide (repeatable)")
    ap.add_argument("--keep-transitive", action="store_true",
                    help="do not remove redundant (transitive) edges")
    args = ap.parse_args()

    prefixes = DEFAULT_IGNORE_PREFIXES + tuple(args.ignore_type_prefix)
    nodes = load_resources(args.plan, prefixes, DEFAULT_IGNORE_TYPES, args.include_data)
    if not nodes:
        print("ERROR: no resources found in plan (after filtering).", file=sys.stderr)
        return 1

    adj = load_edges(args.graph)
    links = contract_edges(nodes, adj)
    n_before = len(links)
    if not args.keep_transitive:
        links = transitive_reduction(links)

    open(args.out, "w").write(build_dot(nodes, links, args.title))
    print(f"resources: {len(nodes)}  edges: {len(links)} (before reduction: {n_before})",
          file=sys.stderr)
    if n_before == 0:
        print("WARNING: no dependency edges found; check the `terraform graph` output format.",
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
