#!/usr/bin/env bash
# preview.sh — one-line pre-match brief for a fixture: who's favored (de-vigged %), the sharp Asian
# handicap, and kickoff (or live score). Read-only / informational — never a pick. One verb wraps two
# reads (match_info + the sharp line); the model issues one command and gets one ready-to-read line.
# Usage: preview.sh "<team, A vs B, or evt_… id>" [--tz IANA_TZ] [--sport football|basketball]
#                   [--date YYYY-MM-DD] [--detailed]
source "$(dirname "$0")/_common.sh"

q= tz= sport= date= detailed=
while [ $# -gt 0 ]; do case "$1" in
  --tz)       tz="${2:-}";    shift 2;;
  --sport)    sport="${2:-}"; shift 2;;
  --date)     date="${2:-}";  shift 2;;
  --detailed) detailed=--detailed; shift;;
  --*) _die "unknown arg: $1" 'preview.sh "<query>" [--tz] [--sport] [--date] [--detailed]';;
  *) q="${q:+$q }$1"; shift;;
esac; done
[ -n "$q" ] || _die "no match query" 'pass a team or fixture, e.g. preview.sh "France vs Argentina"'
# An evt_… id (from today.sh/scan.sh) is resolved to its team name here, so drilling by id just works.
case "$q" in evt_*)
  _trip=$(_resolve_id "$q") || exit 1
  _home="${_trip%%|*}"; _rest="${_trip#*|}"; _away="${_rest%%|*}"; _edate="${_rest##*|}"
  q="$_home vs $_away"; [ -n "$date" ] || date="$_edate";;
esac

# Build both request bodies once (lifting any date written into the query into --date, like match.sh).
_bodies=$(python3 -c 'import json,re,sys
q,tz,sport,date=sys.argv[1:5]
if not date:
    m=re.search(r"\b(\d{4}-\d{2}-\d{2})\b",q)
    if m:
        date=m.group(1); q=re.sub(r"\s*\b"+re.escape(date)+r"\b","",q)
        q=re.sub(r"\s+(on|,)\s*$","",q.strip()).strip()
base={"query":q}
if sport:base["sport"]=sport
if date:base["date"]=date
info=dict(base)
if tz:info["timezone"]=tz
ln=dict(base); ln.update(market_type="asian_handicap",period="full_time",verbosity="terse")
print(json.dumps(info)); print(json.dumps(ln))' "$q" "$tz" "$sport" "$date")
info_body="$(printf '%s\n' "$_bodies" | head -1)"
line_body="$(printf '%s\n' "$_bodies" | tail -1)"

info_json=$(_call match POST /v1/mcp/match_info "$info_body") || exit 1

# Sharp line is best-effort: only when the fixture resolved cleanly, and never fatal to the preview.
line_json=""
info_status=$(printf '%s' "$info_json" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("status",""))
except Exception: print("")' 2>/dev/null || echo "")
if [ "$info_status" = "ok" ]; then
  line_json=$(_call line POST /v1/mcp/get_sharp_line "$line_body" 2>/dev/null) || line_json=""
fi

# Merge the two payloads into one object for the formatter (line may be absent).
python3 -c 'import json,sys
info=json.loads(sys.argv[1])
try: ln=json.loads(sys.argv[2])
except Exception: ln=None
print(json.dumps({"info":info,"line":ln}))' "$info_json" "${line_json:-}" | $FMT preview $detailed
