#!/usr/bin/env bash
# scan.sh — today's slate ranked by VALUE: the top-N outcomes whose best price beats the sharp
# de-vigged fair line, one line each. DETECTION ONLY (read-only): the edge is information, never a
# pick. The whole fan-out + ranking happens server-side; you only see the capped top-N.
# Usage: scan.sh [--sport football|basketball] [--market 1x2|asian_handicap|totals]
#                [--min-edge PCT] [--limit N(<=50)] [--status live|scheduled|finished] [--detailed]
source "$(dirname "$0")/_common.sh"

sport= market= minedge=2 limit=10 status= detailed=
while [ $# -gt 0 ]; do case "$1" in
  --sport)    sport="${2:-}";   shift 2;;
  --market)   market="${2:-}";  shift 2;;
  --min-edge) minedge="${2:-}"; shift 2;;
  --limit)    limit="${2:-}";   shift 2;;
  --status)   status="${2:-}";  shift 2;;
  --detailed) detailed=--detailed; shift;;
  --*) _die "unknown arg: $1" 'scan.sh [--sport] [--market] [--min-edge PCT] [--limit N] [--status] [--detailed]';;
  *) _die "scan takes no match name; use flags" 'e.g. scan.sh --sport football --min-edge 2 --limit 10';;
esac; done
[ "$limit" -gt 50 ] 2>/dev/null && limit=50

# Server-side composite: scan_slate runs the per-match value scan, sorts signal-first and caps to
# `limit`, so a busy weekend slate never reaches the model — only the ranked top-N does.
body=$(python3 -c 'import json,sys
sport,market,minedge,limit,status=sys.argv[1:6]
o={"only_signal":True,"limit":int(limit)}
try: o["min_edge_pct"]=float(minedge)
except Exception: o["min_edge_pct"]=2.0
if sport:  o["sport"]=sport
if status: o["status"]=status
if market: o["markets"]=[market]
print(json.dumps(o))' "$sport" "$market" "$minedge" "$limit" "$status")

_call scan POST /v1/mcp/scan_slate "$body" | $FMT scan --limit "$limit" $detailed
