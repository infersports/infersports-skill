#!/usr/bin/env bash
# scoreprob.sh — MARKET-IMPLIED correct-score probabilities for one football match. The de-vigged
# 1x2 + totals prices are inverted into a Poisson score grid server-side: the most likely scorelines
# with their probabilities, straight from the market. Read-only / informational, never a pick.
# (For win % use fair.sh; for the worked line use line.sh.)
# Usage: scoreprob.sh "<team or A vs B, or evt_… id>" [--top N(1-10)] [--sport] [--date] [--detailed]
source "$(dirname "$0")/_common.sh"

q= top=3 sport= date= detailed=
while [ $# -gt 0 ]; do case "$1" in
  --top)      top="${2:-}";   shift 2;;
  --sport)    sport="${2:-}"; shift 2;;
  --date)     date="${2:-}";  shift 2;;
  --detailed) detailed=--detailed; shift;;
  --*) _die "unknown arg: $1" 'scoreprob.sh "<query>" [--top N] [--sport] [--date] [--detailed]';;
  *) q="${q:+$q }$1"; shift;;
esac; done
[ -n "$q" ] || _die "no match query" 'pass a team or fixture, e.g. scoreprob.sh "Korea vs Czechia"'
case "$q" in evt_*)
  _trip=$(_resolve_id "$q") || exit 1
  _home="${_trip%%|*}"; _rest="${_trip#*|}"; _away="${_rest%%|*}"; _edate="${_rest##*|}"
  q="$_home vs $_away"; [ -n "$date" ] || date="$_edate";;
esac

body=$(python3 -c 'import json,re,sys
q,top,sport,date=sys.argv[1:5]
if not date:
    m=re.search(r"\b(\d{4}-\d{2}-\d{2})\b",q)
    if m:
        date=m.group(1); q=re.sub(r"\s*\b"+re.escape(date)+r"\b","",q)
        q=re.sub(r"\s+(on|,)\s*$","",q.strip()).strip()
o={"query":q,"top":int(top)}
if sport: o["sport"]=sport
if date:  o["date"]=date
print(json.dumps(o))' "$q" "$top" "$sport" "$date")

_call scoreprob POST /v1/mcp/score_prob "$body" | $FMT scoreprob $detailed
