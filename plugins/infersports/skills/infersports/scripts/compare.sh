#!/usr/bin/env bash
# compare.sh — is an EXTERNAL probability (e.g. a Polymarket/Kalshi price) good vs our sharp de-vigged
# fair line? Give a fixture + outcome + your probability → sharp fair %, the edge in pp, ROI, a verdict,
# and caveats. DETECTION ONLY (read-only): we never ingest prediction-market data, size a stake, or
# pick — the edge is information, the call is yours. You pre-net the PM price for its fee/spread.
# Usage: compare.sh "<team or A vs B, or evt_… id>" --prob <0..1>
#                   [--outcome home|draw|away|over|under] [--market 1x2|asian_handicap|totals]
#                   [--period full_time|half_time] [--label polymarket] [--sport] [--date] [--detailed]
source "$(dirname "$0")/_common.sh"

q= prob= outcome=home market=1x2 period=full_time label= sport= date= detailed=
while [ $# -gt 0 ]; do case "$1" in
  --prob)     prob="${2:-}";    shift 2;;
  --outcome)  outcome="${2:-}"; shift 2;;
  --market)   market="${2:-}";  shift 2;;
  --period)   period="${2:-}";  shift 2;;
  --label)    label="${2:-}";   shift 2;;
  --sport)    sport="${2:-}";   shift 2;;
  --date)     date="${2:-}";    shift 2;;
  --detailed) detailed=--detailed; shift;;
  --*) _die "unknown arg: $1" 'compare.sh "<query>" --prob 0.55 [--outcome] [--market] [--period] [--label] [--sport] [--date]';;
  *) q="${q:+$q }$1"; shift;;
esac; done
[ -n "$q" ] || _die "no match query" 'pass a team or fixture, e.g. compare.sh "France vs Argentina" --prob 0.55'
[ -n "$prob" ] || _die "no --prob" 'pass the external (prediction-market) probability in (0,1), e.g. --prob 0.55'
# An evt_… id (from today.sh/scan.sh) is resolved to its team name here, so drilling by id just works.
case "$q" in evt_*)
  _trip=$(_resolve_id "$q") || exit 1
  _home="${_trip%%|*}"; _rest="${_trip#*|}"; _away="${_rest%%|*}"; _edate="${_rest##*|}"
  q="$_home vs $_away"; [ -n "$date" ] || date="$_edate";;
esac

# A date written into the query is lifted into --date (disambiguation), exactly like line.sh.
body=$(python3 -c 'import json,re,sys
q,prob,outcome,market,period,label,sport,date=sys.argv[1:9]
if not date:
    m=re.search(r"\b(\d{4}-\d{2}-\d{2})\b",q)
    if m:
        date=m.group(1); q=re.sub(r"\s*\b"+re.escape(date)+r"\b","",q)
        q=re.sub(r"\s+(on|,)\s*$","",q.strip()).strip()
try: p=float(prob)
except Exception: sys.exit("prob must be a number in (0,1)")
o={"query":q,"external_prob":p,"market_type":market,"period":period,"outcome":outcome}
if label: o["external_label"]=label
if sport: o["sport"]=sport
if date:  o["date"]=date
print(json.dumps(o))' \
  "$q" "$prob" "$outcome" "$market" "$period" "$label" "$sport" "$date") \
  || _die "bad arguments" 'e.g. compare.sh "France vs Argentina" --prob 0.55 --outcome home'

_call compare POST /v1/mcp/compare_prob "$body" | $FMT compare $detailed
