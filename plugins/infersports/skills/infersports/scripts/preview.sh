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
op=dict(base); op.update(markets=["asian_handicap"],period="full_time")
print(json.dumps(info)); print(json.dumps(ln)); print(json.dumps(op))' "$q" "$tz" "$sport" "$date")
info_body="$(printf '%s\n' "$_bodies" | sed -n 1p)"
line_body="$(printf '%s\n' "$_bodies" | sed -n 2p)"
opening_body="$(printf '%s\n' "$_bodies" | sed -n 3p)"

info_json=$(_call match POST /v1/mcp/match_info "$info_body") || exit 1

# Second read is best-effort and never fatal. Pre-match → the sharp CURRENT line. Live → the OPENING
# line instead: in-play prices answer "who wins from here", so the strength reference is the line
# from before kickoff (the formatter renders it as "pre-match: X opened -N").
line_json="" opening_json=""
_st=$(printf '%s' "$info_json" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
    print(d.get("status","") + " " + ((d.get("match") or {}).get("status") or ""))
except Exception: print("")' 2>/dev/null || echo "")
info_status="${_st%% *}"; match_status="${_st#* }"
if [ "$info_status" = "ok" ]; then
  if [ "$match_status" = "live" ]; then
    opening_json=$(_call opening POST /v1/mcp/get_opening_line "$opening_body" 2>/dev/null) || opening_json=""
  else
    line_json=$(_call line POST /v1/mcp/get_sharp_line "$line_body" 2>/dev/null) || line_json=""
  fi
fi

# Merge the payloads into one object for the formatter (line/opening may be absent).
python3 -c 'import json,sys
def load(s):
    try: return json.loads(s)
    except Exception: return None
print(json.dumps({"info":json.loads(sys.argv[1]),"line":load(sys.argv[2]),"opening":load(sys.argv[3])}))' \
  "$info_json" "${line_json:-}" "${opening_json:-}" | $FMT preview $detailed
