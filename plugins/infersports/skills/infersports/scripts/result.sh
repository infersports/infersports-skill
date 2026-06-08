#!/usr/bin/env bash
# result.sh — finished-match scores from the 30-day cache. CONCISE (one line per result, capped).
# List: result.sh [<team substring>] [--date YYYY-MM-DD] [--league name] [--limit N(<=50)] [--detailed]
# One:  result.sh --id evt_XXXX [--detailed]
source "$(dirname "$0")/_common.sh"

team= date= league= limit=20 id= detailed=
while [ $# -gt 0 ]; do case "$1" in
  --date)     date="${2:-}";   shift 2;;
  --league)   league="${2:-}"; shift 2;;
  --limit)    limit="${2:-}";  shift 2;;
  --id)       id="${2:-}";     shift 2;;
  --detailed) detailed=--detailed; shift;;
  --*) _die "unknown arg: $1" "result.sh [<team>] [--date] [--league] [--limit] | result.sh --id evt_…";;
  *) team="${team:+$team }$1"; shift;;
esac; done

if [ -n "$id" ]; then
  _call result_one GET "/v1/results/$id" | $FMT result $detailed
  exit 0
fi

if [ "$limit" -gt 50 ] 2>/dev/null; then limit=50; fi
qs=$(python3 -c 'import sys,urllib.parse
team,date,league,limit=sys.argv[1:5]
p={"limit":limit}
if team:p["team"]=team
if date:p["date"]=date
if league:p["league"]=league
print("?"+urllib.parse.urlencode(p))' "$team" "$date" "$league" "$limit") \
  || _die "bad arguments" "--limit must be a number; e.g. result.sh Myanmar --date 2026-06-06"

_call result GET "/v1/results$qs" | $FMT result --limit "$limit" $detailed
