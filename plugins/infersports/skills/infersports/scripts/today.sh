#!/usr/bin/env bash
# today.sh — today's fixtures, CONCISE (one line per match, capped to protect small context windows).
# Usage: today.sh [--sport football|basketball] [--status live|scheduled|finished]
#                 [--league "name or lg_id"] [--tz IANA_TZ] [--limit N(<=50)] [--detailed]
# --league takes a league NAME (fuzzy, e.g. "World Cup") or an lg_… id.
source "$(dirname "$0")/_common.sh"

sport= status= league= tz= limit=20 detailed=
while [ $# -gt 0 ]; do case "$1" in
  --sport)    sport="${2:-}";  shift 2;;
  --status)   status="${2:-}"; shift 2;;
  --league)   league="${2:-}"; shift 2;;
  --tz)       tz="${2:-}";     shift 2;;
  --limit)    limit="${2:-}";  shift 2;;
  --detailed) detailed=--detailed; shift;;
  *) _die "unknown arg: $1" "today.sh [--sport] [--status] [--league] [--tz] [--limit] [--detailed]";;
esac; done

# Hard cap regardless of what was asked — a 300-match Saturday must never flood context.
if [ "$limit" -gt 50 ] 2>/dev/null; then limit=50; fi

body=$(python3 -c 'import json,sys
sport,status,league,tz,limit=sys.argv[1:6]
o={"limit":int(limit)}
if sport:o["sport"]=sport
if status:o["status"]=status
if league:o["league"]=league
if tz:o["timezone"]=tz
print(json.dumps(o))' "$sport" "$status" "$league" "$tz" "$limit") \
  || _die "bad arguments" "--limit must be a number; e.g. today.sh --status live --limit 15"

_call today POST /v1/mcp/list_today_matches "$body" | $FMT today --limit "$limit" $detailed
