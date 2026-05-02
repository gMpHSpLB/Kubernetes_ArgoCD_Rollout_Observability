#!/usr/bin/env bash
# add a very small CI guard that fails if any dashboard JSON in your 
# tree looks like the v2 model (e.g., has layout.kind: GridLayout and 
# elements with Panel kinds). The idea is to treat k8s-provisioned dashboards 
# as classic-only and catch v2 exports before they ever reach the repo.
#
# Fail the build if any JSON under your dashboards tree contains obvious v2 markers.
set -euo pipefail

ROOT="infra/k8s/monitoring/grafana/dashboards"

[ -d "$ROOT" ] || exit 0

mapfile -t files < <(find "$ROOT" -type f -name '*.json')

if [ "${#files[@]}" -eq 0 ]; then
  exit 0
fi

failed=0

for f in "${files[@]}"; do
  # parse safely; if jq fails, fail early
  if ! jq empty "$f" >/dev/null 2>&1; then
    echo "ERROR: invalid JSON in $f"
    failed=1
    continue
  fi

  has_panels=$(jq 'has("panels")' "$f")
  has_elements=$(jq 'has("elements")' "$f")
  has_layout_grid=$(jq '.layout.kind == "GridLayout" or .layout.kind == "RowsLayout" or .layout.kind == "TabsLayout"' "$f" 2>/dev/null || echo "false")

  # classic we expect: panels == true, elements == false
  if [ "$has_elements" = "true" ] || [ "$has_layout_grid" = "true" ] && [ "$has_panels" != "true" ]; then
    echo "ERROR: $f looks like a v2 dashboard (elements/layout v2 schema)."
    failed=1
  fi
done

if [ "$failed" -ne 0 ]; then
  echo
  echo "Hint: For kube-prometheus-stack file provisioning, keep dashboards in classic JSON model."
  echo "Re-export dashboards from Grafana using classic JSON instead of v2 schema."
  exit 1
fi