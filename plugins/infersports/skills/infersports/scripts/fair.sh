#!/usr/bin/env bash
# fair.sh — the sharp DE-VIGGED fair-value reference for a match, as probabilities. One line: the
# "true odds" the sharp book implies once the vig is removed — what a prediction-market / cross-venue
# trader checks their own price against. Read-only / informational, never a pick. (This is the sharp
# line as probabilities; for the worked decimal line use line.sh, to judge YOUR price use compare.sh.)
# Usage: fair.sh "<team or A vs B, or evt_… id>" [--market 1x2|asian_handicap|totals]
#                [--period full_time|half_time] [--sport] [--date] [--detailed]
source "$(dirname "$0")/_common.sh"

q= market=1x2 period=full_time sport= date= detailed=
while [ $# -gt 0 ]; do case "$1" in
  --market)   market="${2:-}"; shift 2;;
  --period)   period="${2:-}"; shift 2;;
  --sport)    sport="${2:-}";  shift 2;;
  --date)     date="${2:-}";   shift 2;;
  --detailed) detailed=--detailed; shift;;
  --*) _die "unknown arg: $1" 'fair.sh "<query>" [--market] [--period] [--sport] [--date] [--detailed]';;
  *) q="${q:+$q }$1"; shift;;
esac; done
[ -n "$q" ] || _die "no match query" 'pass a team or fixture, e.g. fair.sh "France vs Argentina"'
case "$q" in evt_*)
  _trip=$(_resolve_id "$q") || exit 1
  _home="${_trip%%|*}"; _rest="${_trip#*|}"; _away="${_rest%%|*}"; _edate="${_rest##*|}"
  q="$_home vs $_away"; [ -n "$date" ] || date="$_edate";;
esac

# Same query/date handling as line.sh; force probability format so the output IS the fair %.
body=$(python3 -c 'import json,re,sys
q,market,period,sport,date=sys.argv[1:6]
if not date:
    m=re.search(r"\b(\d{4}-\d{2}-\d{2})\b",q)
    if m:
        date=m.group(1); q=re.sub(r"\s*\b"+re.escape(date)+r"\b","",q)
        q=re.sub(r"\s+(on|,)\s*$","",q.strip()).strip()
o={"query":q,"market_type":market,"period":period,"format":"probability","verbosity":"terse"}
if sport: o["sport"]=sport
if date:  o["date"]=date
print(json.dumps(o))' "$q" "$market" "$period" "$sport" "$date")

_call fair POST /v1/mcp/get_sharp_line "$body" | $FMT fair $detailed
