# _common.sh — shared config + HTTP for the InferSports skill scripts. `source` this.
# Determinism backbone: the API base + paths live HERE, not in the model. Scripts pass args only.
set -eo pipefail

_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SKILL_DIR="$(cd "$_SCRIPTS_DIR/.." && pwd)"
API_BASE="${INFERSPORTS_API_BASE:-https://api.infersports.dev}"
# Version lives in the VERSION file (one place, ships in the tarball) and is sent as the
# User-Agent so the server can tell skill traffic — and which release — apart from bare curl.
SKILL_VERSION="$(cat "$_SKILL_DIR/VERSION" 2>/dev/null || echo dev)"
FMT="python3 $_SCRIPTS_DIR/_fmt.py"

_die() {  # _die <message> [<fix>]
  printf 'ERROR: %s\n' "$1" >&2
  [ -n "${2:-}" ] && printf 'FIX: %s\n' "$2" >&2
  exit 1
}

command -v curl    >/dev/null 2>&1 || _die "curl not found" "install curl"
command -v python3 >/dev/null 2>&1 || _die "python3 not found" "install python3 (used only to compact output)"

# _call <verb> <GET|POST> <path> [json_body]
# Returns the response body on stdout (HTTP 200), or _die's with the API's message+fix on any error.
# INFERSPORTS_MOCK=1 answers from fixtures/<verb>.json instead of the network (offline, deterministic).
_call() {
  local verb="$1" method="$2" path="$3" body="${4:-}"
  if [ "${INFERSPORTS_MOCK:-0}" = "1" ]; then
    local fx="$_SKILL_DIR/fixtures/${verb}.json"
    [ -f "$fx" ] || _die "mock fixture missing for '$verb'" "unset INFERSPORTS_MOCK, or add fixtures/${verb}.json"
    cat "$fx"; return 0
  fi
  local url="${API_BASE}${path}" resp http payload
  local hdr=(-H "Accept: application/json" -A "infersports-skill/${SKILL_VERSION}")
  [ -n "${INFERSPORTS_API_KEY:-}" ] && hdr+=(-H "Authorization: Bearer ${INFERSPORTS_API_KEY}")
  if [ "$method" = "POST" ]; then
    resp=$(curl -sS -m 15 -w $'\n%{http_code}' -X POST "$url" -H "Content-Type: application/json" "${hdr[@]}" -d "$body") \
      || _die "network error reaching InferSports ($url)" "check connectivity or set INFERSPORTS_API_BASE, then retry"
  else
    resp=$(curl -sS -m 15 -w $'\n%{http_code}' "${hdr[@]}" "$url") \
      || _die "network error reaching InferSports ($url)" "check connectivity or set INFERSPORTS_API_BASE, then retry"
  fi
  http="${resp##*$'\n'}"
  payload="${resp%$'\n'*}"
  if [ "$http" != "200" ]; then
    local msg
    msg=$(printf '%s' "$payload" | python3 -c 'import sys,json
try:
    e=json.load(sys.stdin).get("error",{})
    print((e.get("message") or "request failed")+(" — "+e["fix"] if e.get("fix") else ""))
except Exception:
    print("request failed; see https://docs.infersports.dev")' 2>/dev/null || echo "request failed")
    _die "HTTP $http: $msg" "follow the message above, or see https://docs.infersports.dev"
  fi
  printf '%s' "$payload"
}

# _resolve_id <evt_id> → "Home|Away|YYYY-MM-DD" on stdout (or _die's via _call on a bad id).
# Lets match.sh / line.sh drill by the evt_… id that today.sh emits — the script resolves the id to
# a name itself, so the model never hand-builds a raw /v1/events call (determinism).
_resolve_id() {
  local ev
  ev=$(_call event GET "/v1/events/$1") || exit 1   # _call already printed ERROR/FIX; don't pipe empty to python
  printf '%s' "$ev" | python3 -c 'import json,sys
d=json.load(sys.stdin)
print("%s|%s|%s" % (d["home_team"]["name"], d["away_team"]["name"], (d.get("scheduled_at") or "")[:10]))' \
    || _die "could not read event $1" "pass the team name instead, e.g. \"Estonia vs Lithuania\""
}
