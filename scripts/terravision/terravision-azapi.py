#!/usr/bin/env python3
"""Render a TerraVision diagram with known AzAPI resources mapped to Azure icons."""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


DEFAULT_TYPE_MAP = {
    "microsoft.compute/virtualmachines": "azurerm_virtual_machine",
    "microsoft.compute/virtualmachinescalesets": "azurerm_virtual_machine_scale_set",
    "microsoft.containerregistry/registries": "azurerm_container_registry",
    "microsoft.documentdb/databaseaccounts": "azurerm_cosmosdb_account",
    "microsoft.insights/components": "azurerm_application_insights",
    "microsoft.keyvault/vaults": "azurerm_key_vault",
    "microsoft.managedidentity/userassignedidentities": "azurerm_user_assigned_identity",
    "microsoft.network/applicationgateways": "azurerm_application_gateway",
    "microsoft.network/loadbalancers": "azurerm_lb",
    "microsoft.network/networkinterfaces": "azurerm_network_interface",
    "microsoft.network/networksecuritygroups": "azurerm_network_security_group",
    "microsoft.network/privateendpoints": "azurerm_private_endpoint",
    "microsoft.network/publicipaddresses": "azurerm_public_ip",
    "microsoft.network/routetables": "azurerm_route_table",
    "microsoft.network/virtualnetworks": "azurerm_virtual_network",
    "microsoft.operationalinsights/workspaces": "azurerm_log_analytics_workspace",
    "microsoft.resources/resourcegroups": "azurerm_resource_group",
    "microsoft.sql/servers": "azurerm_mssql_server",
    "microsoft.sql/servers/databases": "azurerm_mssql_database",
    "microsoft.storage/storageaccounts": "azurerm_storage_account",
    "microsoft.storage/storageaccounts/blobservices/containers": "azurerm_storage_container",
    "microsoft.web/serverfarms": "azurerm_service_plan",
}

INDEX_RE = re.compile(r'\[(?:"(?:[^"\\]|\\.)*"|[^\]])*\]')
NUMBERED_COPY_RE = re.compile(r"~\d+$")


def normalize_address(address):
    """Normalize Terraform instance addresses to the graph's base address."""
    return NUMBERED_COPY_RE.sub("", INDEX_RE.sub("", address))


def normalize_arm_type(arm_type):
    """Ignore API versions and ARM type casing when matching resource types."""
    return arm_type.split("@", 1)[0].strip().lower()


def target_type(arm_type, after, type_map):
    arm_type_key = normalize_arm_type(arm_type)
    if arm_type_key == "microsoft.web/sites":
        kind = after.get("kind", "")
        if isinstance(kind, str):
            kind_parts = {part.strip().lower() for part in kind.split(",")}
            if "functionapp" in kind_parts:
                if "linux" in kind_parts:
                    return "azurerm_linux_function_app"
                if "windows" in kind_parts:
                    return "azurerm_windows_function_app"
                return "azurerm_function_app"
            if "linux" in kind_parts:
                return "azurerm_linux_web_app"
            if "windows" in kind_parts:
                return "azurerm_windows_web_app"
            if "app" in kind_parts:
                return "azurerm_app_service"
        return type_map.get(arm_type_key)
    return type_map.get(arm_type_key)


def resource_type_map(plan, type_map):
    result = {}
    for resource in plan.get("resource_changes", []):
        if resource.get("mode") != "managed" or resource.get("type") != "azapi_resource":
            continue
        after = resource.get("change", {}).get("after") or {}
        arm_type = after.get("type")
        if not isinstance(arm_type, str):
            continue
        mapped_type = target_type(arm_type, after, type_map)
        if not mapped_type:
            print(
                f"WARNING: no Azure icon mapping for {resource.get('address')} "
                f"({arm_type}); keeping azapi_resource.",
                file=sys.stderr,
            )
            continue
        address = normalize_address(resource["address"])
        if address in result and result[address][0] != mapped_type:
            raise ValueError(
                f"{address} has multiple ARM resource types that map to different icons."
            )
        result[address] = (mapped_type, arm_type)
    return result


def remap_address(address, mapped_types):
    base_address = normalize_address(address)
    mapping = mapped_types.get(base_address)
    if not mapping:
        return address
    mapped_type, _ = mapping
    return re.sub(r"(^|\.)azapi_resource(?=\.)", rf"\g<1>{mapped_type}", address)


def rewrite_graph(graph, mapped_types):
    """Rewrite graph node addresses without changing graph topology."""
    rewritten = {}
    for address, targets in graph.items():
        new_address = remap_address(address, mapped_types)
        if new_address in rewritten:
            raise ValueError(f"Mapping creates duplicate graph node {new_address!r}.")
        rewritten[new_address] = [
            remap_address(target, mapped_types) for target in targets
        ]
    return rewritten


def load_type_map(path):
    type_map = dict(DEFAULT_TYPE_MAP)
    if path is None:
        return type_map
    custom = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(custom, dict) or not all(
        isinstance(key, str)
        and isinstance(value, str)
        and value.startswith("azurerm_")
        for key, value in custom.items()
    ):
        raise ValueError(
            "The mapping file must be a JSON object of ARM type to azurerm_* type."
        )
    type_map.update({normalize_arm_type(key): value for key, value in custom.items()})
    return type_map


def run(command, *, cwd, env=None):
    print("+", " ".join(str(part) for part in command), file=sys.stderr)
    subprocess.run(command, cwd=cwd, env=env, check=True)


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Plan Terraform, map supported AzAPI ARM types to Azure service icons, "
            "and render with TerraVision."
        )
    )
    parser.add_argument("--source", type=Path, default=Path("."))
    parser.add_argument("--outfile", type=Path, default=Path("architecture"))
    parser.add_argument("--format", default="svg")
    parser.add_argument("--title")
    parser.add_argument("--workspace")
    parser.add_argument("--varfile", action="append", default=[])
    parser.add_argument("--mapping", type=Path, help="JSON ARM-type-to-azurerm-type overrides")
    parser.add_argument("--engine", choices=("auto", "terraform", "tofu"), default="auto")
    args = parser.parse_args()

    source = args.source.resolve()
    if not source.is_dir():
        parser.error(f"Terraform source directory does not exist: {source}")

    engine = args.engine
    if engine == "auto":
        engine = "terraform" if shutil.which("terraform") else "tofu"
    executable = shutil.which(engine)
    if not executable:
        parser.error(f"Could not find {engine!r} on PATH.")
    terravision = shutil.which("terravision")
    if not terravision:
        parser.error("Could not find 'terravision' on PATH.")

    try:
        type_map = load_type_map(args.mapping)
        with tempfile.TemporaryDirectory(prefix="terravision-azapi-") as temp:
            temp_path = Path(temp)
            plan_binary = temp_path / "tfplan"
            plan_json = temp_path / "plan.json"
            terraform_graph = temp_path / "graph.dot"
            raw_graph = temp_path / "architecture.tvg.json"
            remapped_graph = temp_path / "architecture-remapped.tvg.json"

            env = os.environ.copy()
            if args.workspace:
                env["TF_WORKSPACE"] = args.workspace

            run([executable, "init", "-input=false"], cwd=source, env=env)
            plan_command = [
                executable,
                "plan",
                "-input=false",
                f"-out={plan_binary}",
            ]
            for varfile in args.varfile:
                plan_command.extend(["-var-file", str(Path(varfile).resolve())])
            run(plan_command, cwd=source, env=env)
            with plan_json.open("w", encoding="utf-8") as output:
                subprocess.run(
                    [executable, "show", "-json", str(plan_binary)],
                    cwd=source,
                    env=env,
                    check=True,
                    stdout=output,
                )
            with terraform_graph.open("w", encoding="utf-8") as output:
                subprocess.run(
                    [executable, "graph"],
                    cwd=source,
                    env=env,
                    check=True,
                    stdout=output,
                )

            run(
                [
                    terravision,
                    "graphdata",
                    "--source",
                    str(source),
                    "--planfile",
                    str(plan_json),
                    "--graphfile",
                    str(terraform_graph),
                    "--outfile",
                    str(raw_graph),
                ],
                cwd=source,
                env=env,
            )
            graph = json.loads(raw_graph.read_text(encoding="utf-8"))
            mapped_types = resource_type_map(
                json.loads(plan_json.read_text(encoding="utf-8")), type_map
            )
            remapped = rewrite_graph(graph, mapped_types)
            remapped_graph.write_text(
                json.dumps(remapped, indent=2) + "\n", encoding="utf-8"
            )
            print(f"Mapped {len(mapped_types)} AzAPI resource(s).", file=sys.stderr)

            draw_command = [
                terravision,
                "draw",
                "--source",
                str(remapped_graph),
                "--format",
                args.format,
                "--outfile",
                str(args.outfile.resolve()),
            ]
            if args.title:
                draw_command.extend(["--title", args.title])
            run(draw_command, cwd=source, env=env)
    except (OSError, ValueError, json.JSONDecodeError, subprocess.CalledProcessError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
