#!/usr/bin/env bash
set -euo pipefail

KICAD_VER="${1:-9.0}"   # pass 7.0/8.0 if needed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 1) KiCad config dir
if [[ "$OSTYPE" == "darwin"* ]]; then
  CFG_DIR="${HOME}/Library/Preferences/kicad/${KICAD_VER}"
else
  CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kicad/${KICAD_VER}"
fi
mkdir -p "${CFG_DIR}"

# 2) Update kicad_common.json env.KILIB_DIR
COMMON_FILE="${CFG_DIR}/kicad_common.json"
if [[ -f "${COMMON_FILE}" ]]; then
  # merge/update with jq if available; otherwise do a minimal sed-safe write
  if command -v jq >/dev/null 2>&1; then
    tmp="$(mktemp)"
    jq --arg path "${REPO_ROOT}" '
      .env = (.env // {}) | .env.KILIB_DIR = $path
    ' "${COMMON_FILE}" >"${tmp}" && mv "${tmp}" "${COMMON_FILE}"
  else
    # crude write that preserves file if missing jq
    cat > "${COMMON_FILE}.tmp" <<EOF
{
  "env": {
    "KILIB_DIR": "${REPO_ROOT}"
  }
}
EOF
    mv "${COMMON_FILE}.tmp" "${COMMON_FILE}"
  fi
else
  cat > "${COMMON_FILE}" <<EOF
{
  "env": {
    "KILIB_DIR": "${REPO_ROOT}"
  }
}
EOF
fi

# 3) Symlink (or copy) the tables
REPO_SYM="${REPO_ROOT}/tables/sym-lib-table"
REPO_FP="${REPO_ROOT}/tables/fp-lib-table"
USER_SYM="${CFG_DIR}/sym-lib-table"
USER_FP="${CFG_DIR}/fp-lib-table"

[[ -f "${REPO_SYM}" ]] || { echo "Missing ${REPO_SYM}"; exit 1; }
[[ -f "${REPO_FP}"  ]] || { echo "Missing ${REPO_FP}";  exit 1; }

link_or_copy () {
  local src="$1" dst="$2"
  rm -f "${dst}"
  if ln -s "${src}" "${dst}" 2>/dev/null; then
    :
  else
    cp -f "${src}" "${dst}"
  fi
}

link_or_copy "${REPO_SYM}" "${USER_SYM}"
link_or_copy "${REPO_FP}"  "${USER_FP}"

echo "KiCad libs wired up:"
echo "  KILIB_DIR = ${REPO_ROOT}"
echo "  sym-lib-table -> ${USER_SYM}"
echo "  fp-lib-table  -> ${USER_FP}"
