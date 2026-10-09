#!/usr/bin/env python3
"""
Generate a TerraVision annotation file for configs that use azapi_resource
(e.g. Azure Verified Modules), which TerraVision draws as generic icon-less nodes.

For every azapi_resource in the plan it:
  * reads the ARM type (e.g. Microsoft.Storage/storageAccounts@2023-05-01) and name
  * removes the generic azapi node
  * adds an azurerm_* stand-in node of the equivalent type (so it gets an icon)
  * labels the stand-in with the real resource name
  * re-creates the connections between the stand-ins

Inputs:
  plan.json   output of `terraform show -json <planfile>`
  graph.json  output of `terravision graphdata --source <dir> --outfile graph.json`

Usage:
  azapi_annotate.py plan.json graph.json > terravision.generated.yml
"""
import argparse
import json
import re
import sys

# ARM resource type (lowercase) -> azurerm resource type TerraVision may have an icon for.
ARM_TO_AZURERM = {
    "microsoft.resources/resourcegroups": "azurerm_resource_group",
    "microsoft.storage/storageaccounts": "azurerm_storage_account",
    "microsoft.network/virtualnetworks": "azurerm_virtual_network",
    "microsoft.network/virtualnetworks/subnets": "azurerm_subnet",
    "microsoft.network/networksecuritygroups": "azurerm_network_security_group",
    "microsoft.network/routetables": "azurerm_route_table",
    "microsoft.network/publicipaddresses": "azurerm_public_ip",
    "microsoft.network/networkinterfaces": "azurerm_network_interface",
    "microsoft.network/loadbalancers": "azurerm_lb",
    "microsoft.network/applicationgateways": "azurerm_application_gateway",
    "microsoft.network/privateendpoints": "azurerm_private_endpoint",
    "microsoft.network/privatednszones": "azurerm_private_dns_zone",
    "microsoft.network/dnszones": "azurerm_dns_zone",
    "microsoft.network/natgateways": "azurerm_nat_gateway",
    "microsoft.network/azurefirewalls": "azurerm_firewall",
    "microsoft.network/bastionhosts": "azurerm_bastion_host",
    "microsoft.network/virtualnetworkgateways": "azurerm_virtual_network_gateway",
    "microsoft.compute/virtualmachines": "azurerm_linux_virtual_machine",
    "microsoft.compute/virtualmachinescalesets": "azurerm_linux_virtual_machine_scale_set",
    "microsoft.compute/disks": "azurerm_managed_disk",
    "microsoft.containerservice/managedclusters": "azurerm_kubernetes_cluster",
    "microsoft.containerregistry/registries": "azurerm_container_registry",
    "microsoft.keyvault/vaults": "azurerm_key_vault",
    "microsoft.operationalinsights/workspaces": "azurerm_log_analytics_workspace",
    "microsoft.insights/components": "azurerm_application_insights",
    "microsoft.web/serverfarms": "azurerm_service_plan",
    "microsoft.web/sites": "azurerm_linux_web_app",
    "microsoft.sql/servers": "azurerm_mssql_server",
    "microsoft.sql/servers/databases": "azurerm_mssql_database",
    "microsoft.dbforpostgresql/flexibleservers": "azurerm_postgresql_flexible_server",
    "microsoft.dbformysql/flexibleservers": "azurerm_mysql_flexible_server",
    "microsoft.documentdb/databaseaccounts": "azurerm_cosmosdb_account",
    "microsoft.cache/redis": "azurerm_redis_cache",
    "microsoft.managedidentity/userassignedidentities": "azurerm_user_assigned_identity",
    "microsoft.eventhub/namespaces": "azurerm_eventhub_namespace",
    "microsoft.servicebus/namespaces": "azurerm_servicebus_namespace",
}

# ARM types that are plumbing rather than architecture: hidden from the diagram.
HIDE_ARM_TYPES = {
    "microsoft.authorization/locks",
    "microsoft.authorization/roleassignments",
    "microsoft.insights/diagnosticsettings",
}

# Terraform resource types that are noise in a diagram.
NOISE_TF_PREFIXES = ("random_", "time_", "modtm_", "null_")
NOISE_TF_TYPES = {"terraform_data"}


def norm_plan_addr(addr):
    """Drop [index] segments: module.x["a"].azapi_resource.this[0] -> module.x.azapi_resource.this"""
    return re.sub(r"\[[^\]]*\]", "", addr)


def norm_graph_key(key):
    """Drop [index] segments and a trailing ~N copy suffix."""
    return re.sub(r"~\d+$", "", norm_plan_addr(key))


def tf_type_of(addr):
    """Resource type of an address, e.g. 'azapi_resource' from '...azapi_resource.this'."""
    parts = norm_plan_addr(addr).split(".")
    return parts[-2] if len(parts) >= 2 else ""


def is_noise(addr):
    t = tf_type_of(addr)
    return t in NOISE_TF_TYPES or t.startswith(NOISE_TF_PREFIXES)


def strings_in(value):
    """All strings found anywhere inside a list/dict value (tolerant of graph.json shape)."""
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for v in value:
            yield from strings_in(v)
    elif isinstance(value, dict):
        for v in value.values():
            yield from strings_in(v)


def load_azapi_resources(plan):
    """Return [{address, arm_type, name}] for every azapi_resource in the plan."""
    found = []
    for rc in plan.get("resource_changes", []):
        if rc.get("type") != "azapi_resource":
            continue
        after = (rc.get("change") or {}).get("after") or {}
        arm = after.get("type")
        found.append({
            "address": rc["address"],
            "arm_type": arm.split("@")[0] if isinstance(arm, str) else None,
            "name": after.get("name") if isinstance(after.get("name"), str) else None,
        })
    return found


def short_name(addr):
    """Readable fallback label from the module path, e.g. module.storage.module.this... -> storage"""
    mods = re.findall(r"module\.([^.\[]+)", norm_plan_addr(addr))
    mods = [m for m in mods if m != "this"] or mods
    return mods[-1] if mods else norm_plan_addr(addr)


def q(s):
    """YAML-safe double-quoted string (JSON strings are valid YAML)."""
    return json.dumps(s)


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("plan_json")
    ap.add_argument("graph_json")
    ap.add_argument("--title", default=None)
    ap.add_argument("--keep-noise", action="store_true",
                    help="do not remove random_*/time_*/modtm_*/terraform_data nodes")
    args = ap.parse_args()

    with open(args.plan_json) as f:
        plan = json.load(f)
    with open(args.graph_json) as f:
        graph = json.load(f)
    if not isinstance(graph, dict):
        sys.exit(
            "graph.json is not a JSON object keyed by node name; was it made by `terravision graphdata`?")

    azapi = load_azapi_resources(plan)

    # Group graph keys by normalised address so plan resources can be matched to graph nodes.
    keys_by_norm = {}
    for k in graph:
        keys_by_norm.setdefault(norm_graph_key(k), []).append(k)
    plan_by_norm = {}
    for r in azapi:
        plan_by_norm.setdefault(norm_plan_addr(r["address"]), []).append(r)

    replace = {}   # graph key -> {"standin": name, "label": str, "azurerm": type}
    hide = []      # graph keys to remove with no replacement
    warnings = []
    used_names = set()

    for norm, keys in keys_by_norm.items():
        if tf_type_of(norm) != "azapi_resource":
            continue
        plans = plan_by_norm.get(norm, [])
        keys = sorted(keys)
        if not plans:
            warnings.append(
                f"{norm}: in graph but not in plan; left as a generic node")
            continue
        if len(plans) != len(keys):
            warnings.append(f"{norm}: {len(plans)} plan instance(s) vs {len(keys)} graph node(s); "
                            f"labels may be mismatched")
        for i, key in enumerate(keys):
            r = plans[i] if i < len(plans) else plans[0]
            arm = (r["arm_type"] or "").lower()
            if arm in HIDE_ARM_TYPES:
                hide.append(key)
                continue
            azurerm = ARM_TO_AZURERM.get(arm)
            label = r["name"] or short_name(key)
            if not azurerm:
                warnings.append(f"{key}: no azurerm mapping for ARM type {r['arm_type']!r}; "
                                f"labelled but still a generic node")
                replace[key] = {"standin": None,
                                "label": label, "azurerm": None}
                continue
            base = re.sub(r"\W+", "_", short_name(key)).strip("_") or "res"
            name, n = base, 2
            while f"{azurerm}.{name}" in used_names:
                name, n = f"{base}_{n}", n + 1
            used_names.add(f"{azurerm}.{name}")
            replace[key] = {"standin": f"{azurerm}.{name}",
                            "label": label, "azurerm": azurerm}

    standin_of = {k: v["standin"] for k, v in replace.items() if v["standin"]}
    noise = [] if args.keep_noise else [k for k in graph if is_noise(k)]
    removed = set(standin_of) | set(hide) | set(noise)

    # Connections between stand-ins, walking through any removed/hidden nodes in between.
    edges = {}
    for src in standin_of:
        seen, stack, targets = set(), list(strings_in(graph.get(src))), []
        while stack:
            t = stack.pop()
            if t in seen or t == src or t not in graph:
                continue
            seen.add(t)
            if t in standin_of:
                targets.append(standin_of[t])
            elif t in removed:
                stack.extend(strings_in(graph.get(t)))
        if targets:
            edges[standin_of[src]] = sorted(set(targets))

    out = ["format: 0.3"]
    if args.title:
        out.append(f"title: {q(args.title)}")
    out.append("")
    if removed:
        out.append("remove:")
        out += [f"  - {q(k)}" for k in sorted(removed)]
        out.append("")
    if standin_of:
        out.append("add:")
        out += [f"  {q(v)}: {{}}" for v in sorted(standin_of.values())]
        out.append("")
    if edges:
        out.append("connect:")
        for s, ts in sorted(edges.items()):
            out.append(f"  {q(s)}:")
            out += [f"    - {q(t)}" for t in ts]
        out.append("")
    labels = {}
    for k, v in replace.items():
        labels[v["standin"] or k] = v["label"]
    if labels:
        out.append("update:")
        for node, label in sorted(labels.items()):
            out.append(f"  {q(node)}:")
            out.append(f"    label: {q(label)}")
        out.append("")

    print("\n".join(out))
    for w in warnings:
        print(f"WARNING: {w}", file=sys.stderr)
    print(f"# {len(standin_of)} stand-in node(s), {len(hide)} hidden, {len(noise)} noise node(s) removed",
          file=sys.stderr)


if __name__ == "__main__":
    main()
