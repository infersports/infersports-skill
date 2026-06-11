#!/usr/bin/env bash
# digest.sh — today's highlights: the N matches most worth watching, ranked (live first, then soonest
# kickoff, marquee first), one line each. Casual; read-only. The whole slate is pulled then ranked +
# capped to the top-N here, so a busy day never floods a small context window.
# Usage: digest.sh [--sport football|basketball] [--limit N(<=12)] [--status live|scheduled|finished] [--league "World Cup"] [--detailed]
source "$(dirname "$0")/_common.sh"

sport= limit=6 status= league= detailed=
while [ $# -gt 0 ]; do case "$1" in
  --sport)    sport="${2:-}";  shift 2;;
  --limit)    limit="${2:-}";  shift 2;;
  --status)   status="${2:-}"; shift 2;;
  --league)   league="${2:-}"; shift 2;;
  --detailed) detailed=--detailed; shift;;
  --*) _die "unknown arg: $1" 'digest.sh [--sport] [--limit N] [--status] [--league] [--detailed]';;
  *) _die "digest takes no match name; use flags" 'e.g. digest.sh --sport football --limit 6';;
esac; done
[ "$limit" -gt 12 ] 2>/dev/null && limit=12

# Pull the whole slate (no value filter); the formatter ranks it by interest and keeps the top-N.
body=$(python3 -c 'import json,sys
sport,status,league=sys.argv[1:4]
o={"only_signal":False,"limit":100}
if sport:  o["sport"]=sport
if status: o["status"]=status
if league: o["league"]=league
print(json.dumps(o))' "$sport" "$status" "$league")

_call digest POST /v1/mcp/scan_slate "$body" | $FMT digest --limit "$limit" $detailed
