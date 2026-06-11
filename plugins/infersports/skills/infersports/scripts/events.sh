#!/usr/bin/env bash
# events.sh — the schedule for a specific day OR a date range, CONCISE (one line per match, capped).
# Usage: events.sh --date YYYY-MM-DD [--to YYYY-MM-DD] [--tz IANA_TZ] [--sport football|basketball]
#                  [--status live|scheduled|finished] [--league "name or lg_id"] [--limit N] [--detailed]
# --league takes a league NAME (fuzzy, e.g. "World Cup") or an lg_… id.
# --date is REQUIRED. --to (inclusive, max 31 days after --date) covers a whole window in ONE call —
# e.g. all World Cup group-stage matches: --date 2026-06-11 --to 2026-06-28 --league "World Cup".
# UTC is canonical: days are UTC unless --tz is given, in which case the day boundary (and each
# kickoff time shown) is that local zone — e.g. "June 12 in Asia/Shanghai".
source "$(dirname "$0")/_common.sh"

date= dto= tz= sport= status= league= limit= detailed=
while [ $# -gt 0 ]; do case "$1" in
  --date)     date="${2:-}";   shift 2;;
  --to)       dto="${2:-}";    shift 2;;
  --tz)       tz="${2:-}";     shift 2;;
  --sport)    sport="${2:-}";  shift 2;;
  --status)   status="${2:-}"; shift 2;;
  --league)   league="${2:-}"; shift 2;;
  --limit)    limit="${2:-}";  shift 2;;
  --detailed) detailed=--detailed; shift;;
  *) _die "unknown arg: $1" "events.sh --date YYYY-MM-DD [--to YYYY-MM-DD] [--tz] [--sport] [--status] [--league] [--limit] [--detailed]";;
esac; done

[ -n "$date" ] || _die "no --date" 'a day is required, e.g. events.sh --date 2026-06-12 --tz Asia/Shanghai'

# Hard cap regardless of what was asked — a 300-match Saturday must never flood context.
# A range gets a higher default + cap (a tournament window is dozens of one-liners; use --league).
if [ -n "$dto" ]; then cap=100; def=100; else cap=50; def=20; fi
[ -n "$limit" ] || limit=$def
if [ "$limit" -gt "$cap" ] 2>/dev/null; then limit=$cap; fi

body=$(python3 -c 'import json,sys
date,dto,tz,sport,status,league,limit=sys.argv[1:8]
o={"date":date,"limit":int(limit)}
if dto:o["date_to"]=dto
if tz:o["timezone"]=tz
if sport:o["sport"]=sport
if status:o["status"]=status
if league:o["league"]=league
print(json.dumps(o))' "$date" "$dto" "$tz" "$sport" "$status" "$league" "$limit") \
  || _die "bad arguments" "--date YYYY-MM-DD, --limit a number; e.g. events.sh --date 2026-06-12 --limit 15"

_call events POST /v1/mcp/list_events "$body" | $FMT events --limit "$limit" $detailed
