#!/usr/bin/env bash
# convert.sh — odds-format conversion OR Asian-handicap explanation. Pure functions, tiny output.
# Odds:     convert.sh <value> <from> <to[,to2,...]>
#           e.g. convert.sh 2.08 decimal hk,malay,american,probability
# Handicap: convert.sh --handicap <line>          e.g. convert.sh --handicap -0.75
# Formats: decimal | hk | malay | american | indonesian | probability
source "$(dirname "$0")/_common.sh"

if [ "${1:-}" = "--handicap" ]; then
  line="${2:-}"
  [ -n "$line" ] || _die "no handicap line" "convert.sh --handicap -0.75 (line is a multiple of 0.25)"
  body=$(python3 -c 'import json,sys;print(json.dumps({"line":float(sys.argv[1])}))' "$line") \
    || _die "handicap line must be a number" "e.g. convert.sh --handicap -0.75"
  _call convert_handicap POST /v1/convert/handicap "$body" | $FMT handicap
  exit 0
fi

val="${1:-}" from="${2:-}" tos="${3:-}"
{ [ -n "$val" ] && [ -n "$from" ] && [ -n "$tos" ]; } \
  || _die "usage: convert.sh <value> <from> <to[,to2,...]>" \
          'e.g. convert.sh 2.08 decimal hk,malay,american,probability — formats: decimal hk malay american indonesian probability'
body=$(python3 -c 'import json,sys
val,frm,tos=sys.argv[1:4]
print(json.dumps({"value":float(val),"from":frm,"to":[t for t in tos.split(",") if t]}))' \
  "$val" "$from" "$tos") \
  || _die "value must be a number" "e.g. convert.sh 2.08 decimal hk"

_call convert POST /v1/convert/odds "$body" | $FMT convert
