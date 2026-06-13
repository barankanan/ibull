#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
npx --yes ruflo@latest doctor --fix
npx --yes ruflo@latest memory init
npx --yes ruflo@latest swarm init --topology hierarchical --max-agents 8 --strategy specialized
echo "Claude Code plugins (inside claude session):"
echo "  /plugin marketplace add ruvnet/ruflo"
echo "  /plugin install ruflo-core@ruflo"
echo "  /plugin install ruflo-swarm@ruflo"
