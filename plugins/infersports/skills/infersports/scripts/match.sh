#!/usr/bin/env bash
# match.sh — casual basics for ONE match: who's favored / live score / kickoff. CONCISE.
# Usage: match.sh "<team or A vs B>" [--tz IANA_TZ] [--sport football|basketball]
#                 [--date YYYY-MM-DD] [--detailed]
source "$(dirname "$0")/_common.sh"

q= tz= sport= date= detailed=
while [ $# -gt 0 ]; do case "$1" in
  --tz)       tz="${2:-}";    shift 2;;
  --sport)    sport="${2:-}"; shift 2;;
  --date)     date="${2:-}";  shift 2;;
  --detailed) detailed=--detailed; shift;;
  --*) _die "unknown arg: $1" 'match.sh "<query>" [--tz] [--sport] [--date] [--detailed]';;
  *) q="${q:+$q }$1"; shift;;
esac; done
[ -n "$q" ] || _die "no match query" 'pass a team or fixture, e.g. match.sh "Brazil vs Argentina"'
# An evt_… id (from today.sh) is resolved to its team name here, so drilling by id just works.
case "$q" in evt_*)
  _trip=$(_resolve_id "$q") || exit 1
  _home="${_trip%%|*}"; _rest="${_trip#*|}"; _away="${_rest%%|*}"; _edate="${_rest##*|}"
  q="$_home vs $_away"; [ -n "$date" ] || date="$_edate";;
esac

# A date written into the query ("Team A vs Team B 2026-06-07") is lifted into --date so it
# disambiguates same-name fixtures instead of polluting the name match.
body=$(python3 -c 'import json,re,sys
q,tz,sport,date=sys.argv[1:5]
if not date:
    m=re.search(r"\b(\d{4}-\d{2}-\d{2})\b",q)
    if m:
        date=m.group(1); q=re.sub(r"\s*\b"+re.escape(date)+r"\b","",q)
        q=re.sub(r"\s+(on|,)\s*$","",q.strip()).strip()
o={"query":q}
if tz:o["timezone"]=tz
if sport:o["sport"]=sport
if date:o["date"]=date
print(json.dumps(o))' "$q" "$tz" "$sport" "$date")

_call match POST /v1/mcp/match_info "$body" | $FMT match $detailed
