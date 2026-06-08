#!/usr/bin/env bash
# line.sh — ONE normalized sharp line for a match (consensus line, best price, de-vigged fair). CONCISE.
# Usage: line.sh "<team or A vs B>" [--market asian_handicap|1x2|totals]
#                [--period full_time|half_time]
#                [--format decimal|hk|malay|american|indonesian|probability]
#                [--sport football|basketball] [--date YYYY-MM-DD] [--detailed]
# --sport / --date disambiguate same-name fixtures (e.g. senior vs U21); they don't go in the query.
source "$(dirname "$0")/_common.sh"

q= market=asian_handicap period=full_time format=decimal sport= date= detailed= verbosity=terse
while [ $# -gt 0 ]; do case "$1" in
  --market)   market="${2:-}"; shift 2;;
  --period)   period="${2:-}"; shift 2;;
  --format)   format="${2:-}"; shift 2;;
  --sport)    sport="${2:-}";  shift 2;;
  --date)     date="${2:-}";   shift 2;;
  --detailed) detailed=--detailed; verbosity=full; shift;;
  --*) _die "unknown arg: $1" 'line.sh "<query>" [--market] [--period] [--format] [--sport] [--date] [--detailed]';;
  *) q="${q:+$q }$1"; shift;;
esac; done
[ -n "$q" ] || _die "no match query" 'pass a team or fixture, e.g. line.sh "Man City vs Arsenal"'
# An evt_… id (from today.sh) is resolved to its team name here, so drilling by id just works.
case "$q" in evt_*)
  _trip=$(_resolve_id "$q") || exit 1
  _home="${_trip%%|*}"; _rest="${_trip#*|}"; _away="${_rest%%|*}"; _edate="${_rest##*|}"
  q="$_home vs $_away"; [ -n "$date" ] || date="$_edate";;
esac

# A date written into the query ("Team A vs Team B 2026-06-07") is understood: it is lifted into
# --date so it disambiguates same-name fixtures instead of polluting the name match.
body=$(python3 -c 'import json,re,sys
q,market,period,fmt,verb,sport,date=sys.argv[1:8]
if not date:
    m=re.search(r"\b(\d{4}-\d{2}-\d{2})\b",q)
    if m:
        date=m.group(1); q=re.sub(r"\s*\b"+re.escape(date)+r"\b","",q)
        q=re.sub(r"\s+(on|,)\s*$","",q.strip()).strip()
o={"query":q,"market_type":market,"period":period,"format":fmt,"verbosity":verb}
if sport:o["sport"]=sport
if date:o["date"]=date
print(json.dumps(o))' \
  "$q" "$market" "$period" "$format" "$verbosity" "$sport" "$date")

_call line POST /v1/mcp/get_sharp_line "$body" | $FMT line $detailed
