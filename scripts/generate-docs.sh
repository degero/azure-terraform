#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
docs_root="$repo_root/docs"
export PATH="${HOME}/.local/bin:${PATH}"

PYTHON_BIN=python3
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "python3 is required to generate docs; install it and add it to PATH" >&2
  exit 1
fi

is_placeholder_doc() {
  "$PYTHON_BIN" - "$1" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.exists():
    raise SystemExit(1)
text = path.read_text(encoding='utf-8', errors='replace')
checks = ['No requirements.', 'No providers.', 'No modules.', 'No resources.', 'No inputs.', 'No outputs.']
raise SystemExit(0 if all(token in text for token in checks) else 1)
PY
}

render_terraform_docs() {
  local target_dir="$1"
  local out_file="$2"
  terraform-docs markdown table --hide header --indent 3 "$target_dir" > "$out_file"
}

mkdir -p "$docs_root"
rm -rf "$docs_root/modules" "$docs_root/environments"
rm -f "$docs_root/README.md"
mkdir -p "$docs_root/modules"

if [ -d "$repo_root/modules" ]; then
  while IFS= read -r module_dir; do
    module_rel="${module_dir#$repo_root/modules/}"
    if [ "$module_rel" = "$module_dir" ] || [ -z "$module_rel" ]; then
      continue
    fi

    target_file="$docs_root/modules/$module_rel/README.md"
    mkdir -p "$(dirname "$target_file")"
    temp_file="$(mktemp)"
    render_terraform_docs "$module_dir" "$temp_file"
    if is_placeholder_doc "$temp_file"; then
      rm -f "$temp_file" "$target_file"
      continue
    fi

    cp "$temp_file" "$target_file"
    rm -f "$temp_file"
  done < <(find "$repo_root/modules" -path '*/.terraform' -prune -o -type f -name '*.tf' -print 2>/dev/null | while IFS= read -r tf_file; do dirname "$tf_file"; done | sort -u)
fi

env_section_files=()
if [ -d "$repo_root/environments" ]; then
  while IFS= read -r env_dir; do
    env_name="$(basename "$env_dir")"
    temp_file="$(mktemp)"
    render_terraform_docs "$env_dir" "$temp_file"
    if is_placeholder_doc "$temp_file"; then
      rm -f "$temp_file"
      continue
    fi

    "$PYTHON_BIN" - "$temp_file" "$env_name" "$repo_root" <<'PY'
import re
import sys
from pathlib import Path

temp_path = Path(sys.argv[1])
env_name = sys.argv[2]
repo_root = Path(sys.argv[3])
env_dir = repo_root / 'environments' / env_name
text = temp_path.read_text(encoding='utf-8', errors='replace').splitlines()
if text and text[0].startswith('# '):
    text = text[1:]

module_map = {}
for tf_file in sorted(env_dir.rglob('*.tf')):
    content = tf_file.read_text(encoding='utf-8', errors='replace')
    for match in re.finditer(r'module\s+"([A-Za-z0-9_-]+)"\s*\{.*?source\s*=\s*"([^"]+)"', content, re.S):
        name, source = match.groups()
        source = source.strip().replace('\\', '/')
        if source.startswith(('git::', 'http://', 'https://')):
            continue
        if source.startswith(('./', '../', '/')):
            normalized = source.lstrip('./')
            if normalized.startswith('modules/'):
                module_map[name] = './' + normalized + '/README.md'

for module_name, readme_path in sorted(module_map.items()):
    text = [
        line.replace(f'](#module_{module_name})', f']({readme_path})')
        .replace(f'](#module\\_{module_name})', f']({readme_path})')
        for line in text
    ]

lines = [f'## Environment: {env_name}', '']
for line in text:
    if not line.strip():
        lines.append('')
        continue
    if line.startswith('## '):
        lines.append(f'### {line[3:]}')
    else:
        lines.append(line)

# Avoid emitting duplicate heading lines when the environment doc has a single top-level heading.
if lines and lines[0].strip() == f'## Environment: {env_name}':
    lines = lines[:1] + lines[2:]

lines.append('')
temp_path.write_text('\n'.join(lines).rstrip() + '\n', encoding='utf-8')
PY
    env_section_files+=("$temp_file")
  done < <(find "$repo_root/environments" -mindepth 1 -maxdepth 1 -type d | sort)
fi

"$PYTHON_BIN" - "$docs_root" "$repo_root" "${env_section_files[@]}" <<'PY'
import sys
from pathlib import Path

docs_root = Path(sys.argv[1])
repo_root = Path(sys.argv[2])
env_files = [Path(p) for p in sys.argv[3:] if p]

lines = ['# Terraform Documentation', '']

if env_files:
    for env_file in env_files:
        content = env_file.read_text(encoding='utf-8', errors='replace').rstrip()
        if content:
            lines.append(content)
            lines.append('')

module_root = docs_root / 'modules'
module_readmes = sorted(
    [p for p in module_root.rglob('README.md') if p.is_file() and p.parent != module_root],
    key=lambda p: p.relative_to(docs_root).as_posix(),
)
if module_readmes:
    lines += ['## Modules', '', 'Modules used by environments. These are located in `modules/`.', '']
    for readme in module_readmes:
        display = readme.parent.relative_to(module_root).as_posix()
        lines.append(f'- [{display}](./modules/{display}/README.md)')
    lines.append('')

modulegroup_root = repo_root / 'modulegroups'
modulegroup_readmes = sorted([p for p in modulegroup_root.rglob('README.md') if p.is_file()]) if modulegroup_root.exists() else []
if modulegroup_readmes:
    lines += ['## Module Groups', '', 'Module groups used by environments. These are located in `modulegroups/`.', '']
    for readme in modulegroup_readmes:
        display = readme.relative_to(repo_root).as_posix()
        lines.append(f'- [{display}]({readme.relative_to(repo_root).as_posix()})')
    lines.append('')

lines += [
    '## Diagram',
    '',
    'Only a diagram for the highest environment is generated.',
    '',
    '<!-- terraform-diagram:start -->',
]
diagrams = sorted(docs_root.glob('*terraform-diagram.svg'))
if diagrams:
    for diagram in diagrams:
        lines.append(f'![Terraform diagram]({diagram.name})')
else:
    lines.append('- Diagram output is generated by the diagram workflow.')
lines += ['<!-- terraform-diagram:end -->', '']

lines += ['## Cost Breakdown', '', 'Generated by Infracost.', '']
cost_breakdown = docs_root / 'infracost.md'
if cost_breakdown.exists():
    cost_lines = cost_breakdown.read_text(encoding='utf-8', errors='replace').splitlines()
    if cost_lines and cost_lines[0].startswith('# '):
        cost_lines = cost_lines[1:]
    while cost_lines and not cost_lines[0].strip():
        cost_lines = cost_lines[1:]
    lines.extend(cost_lines)
else:
    lines.append('- [Estimated monthly costs](./infracost.md)')
lines.append('')

(docs_root / 'README.md').write_text('\n'.join(lines).rstrip() + '\n', encoding='utf-8')
PY

# Clean stale generated README docs that contain placeholder content.
while IFS= read -r readme; do
  if grep -q "No requirements\." "$readme" && grep -q "No providers\." "$readme" && grep -q "No modules\." "$readme" && grep -q "No resources\." "$readme" && grep -q "No inputs\." "$readme" && grep -q "No outputs\." "$readme"; then
    rm -f "$readme"
  fi
done < <(find "$docs_root" -type f -name 'README.md' -print 2>/dev/null)

rm -rf "$docs_root/environments"
rm -f "$docs_root/modules/README.md"
find "$docs_root" -type d -empty -delete 2>/dev/null || true

"$PYTHON_BIN" - "$docs_root" <<'PY'
import re
import sys
from pathlib import Path

docs_root = Path(sys.argv[1])
markdown_link = re.compile(r'\[([^\]]+)\]\(([^)]+)\)')
html_link = re.compile(r'<a\s+href=(["\'])(.*?)\1([^>]*)>(.*?)</a>', re.I | re.S)
named_anchor = re.compile(r'<a\s+(?:name|id)=(["\']).*?\1\s*>\s*</a>', re.I)

def remove_link_fragment(match):
    label, target = match.groups()
    target = target.strip()
    if target.startswith('#'):
        return label

    destination, separator, title = target.partition(' ')
    destination = destination.split('#', 1)[0]
    return f'[{label}]({destination}{separator}{title})'

def remove_html_fragment(match):
    quote, href, attributes, label = match.groups()
    if href.startswith('#'):
        return label

    href = href.split('#', 1)[0]
    return f'<a href={quote}{href}{quote}{attributes}>{label}</a>'

for markdown_file in docs_root.rglob('*.md'):
    content = markdown_file.read_text(encoding='utf-8', errors='replace')
    content = html_link.sub(remove_html_fragment, content)
    content = markdown_link.sub(remove_link_fragment, content)
    content = named_anchor.sub('', content)
    markdown_file.write_text(content, encoding='utf-8')
PY

for temp_file in "${env_section_files[@]}"; do
  rm -f "$temp_file"
done
