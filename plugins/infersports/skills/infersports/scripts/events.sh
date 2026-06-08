#!/usr/bin/env bash
# events.sh — the schedule for ONE specific day, CONCISE (one line per match, capped to protect context).
# Usage: events.sh --date YYYY-MM-DD [--tz IANA_TZ] [--sport football|basketball]
#                  [--status live|scheduled|finished] [--league lg_id] [--limit N(<=50)] [--detailed]
# --date is REQUIRED. UTC is canonical: --date is a UTC day unless --tz is given, in which case the
# day boundary (and each kickoff time shown) is that local zone — e.g. "June 12 in Asia/Shanghai".
source "$(dirname "$0")/_common.sh"

date= tz= sport= status= league= limit=20 detailed=
while [ $# -gt 0 ]; do case "$1" in
  --date)     date="${2:-}";   shift 2;;
  --tz)       tz="${2:-}";     shift 2;;
  --sport)    sport="${2:-}";  shift 2;;
  --status)   status="${2:-}"; shift 2;;
  --league)   league="${2:-}"; shift 2;;
  --limit)    limit="${2:-}";  shift 2;;
  --detailed) detailed=--detailed; shift;;
  *) _die "unknown arg: $1" "events.sh --date YYYY-MM-DD [--tz] [--sport] [--status] [--league] [--limit] [--detailed]";;
esac; done

[ -n "$date" ] || _die "no --date" 'a day is required, e.g. events.sh --date 2026-06-12 --tz Asia/Shanghai'

# Hard cap regardless of what was asked — a 300-match Saturday must never flood context.
if [ "$limit" -gt 50 ] 2>/dev/null; then limit=50; fi

body=$(python3 -c 'import json,sys
date,tz,sport,status,league,limit=sys.argv[1:7]
o={"date":date,"limit":int(limit)}
if tz:o["timezone"]=tz
if sport:o["sport"]=sport
if status:o["status"]=status
if league:o["league"]=league
print(json.dumps(o))' "$date" "$tz" "$sport" "$status" "$league" "$limit") \
  || _die "bad arguments" "--date YYYY-MM-DD, --limit a number; e.g. events.sh --date 2026-06-12 --limit 15"

_call events POST /v1/mcp/list_events "$body" | $FMT events --limit "$limit" $detailed
