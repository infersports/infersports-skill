#!/usr/bin/env python3
"""CONCISE formatter for the InferSports skill.

Reads the API JSON on stdin and prints a compact, plain-text, one-line-per-item view (token-frugal
for small-context agents). `--detailed` re-emits the raw JSON instead. It NEVER dumps a raw list by
default — that is the whole point: a busy weekend slate must not flood the model's context.
"""
from __future__ import annotations

import argparse
import json
import sys


def pct(x):
    try:
        return f"{round(float(x) * 100, 1)}%"
    except Exception:
        return "?"


def fmt_today(d, a):
    matches = d.get("matches", [])
    print(f"Today {d.get('date', '?')} — {len(matches)} shown")
    for m in matches:
        line = m.get("summary") or f"{m.get('home_team', '?')} vs {m.get('away_team', '?')}"
        print(f"{m.get('event_id', '?')} | {line}")
    if a.limit and len(matches) >= a.limit:
        print(f"… first {a.limit} only — more exist. Narrow with --sport/--status/--league, or use `match <team>`.")


def _alts(d, shown=""):
    for alt in d.get("alternatives", []):
        print(f"  {alt.get('event_id', '?')} | {alt.get('label', '?')} ({alt.get('confidence', '?')})")
    au = d.get("ask_user")
    if au and au != shown:  # the summary already carried the question — don't print it twice
        print(f"ask: {au}")


def fmt_match(d, a):
    summary = d.get("summary", "")
    print(summary)
    fav = d.get("favorite")
    if fav:
        who = fav.get("team") or fav.get("outcome", "?")
        print(f"favorite: {who} ({pct(fav.get('win_probability'))})")
    if d.get("status") == "ambiguous":
        _alts(d, summary)


def fmt_line(d, a):
    summary = d.get("summary", "")
    print(summary)
    if d.get("status") == "ambiguous":
        _alts(d, summary)


def fmt_convert(d, a):
    # response = source format + requested targets, e.g. {"decimal":2.08,"hk":1.08,...}
    print(" ".join(f"{k}={v}" for k, v in d.items()))


def fmt_handicap(d, a):
    line = d.get("handicap_decimal", d.get("handicap_raw", "?"))
    out = f"AH {line}: {d.get('explanation', '')}".rstrip()
    comp = d.get("handicap_components")
    if comp:
        out += f" [components {comp}]"
    print(out)


def _result_line(r):
    sc = r.get("score") or {}
    score = f"{sc.get('home', '?')}-{sc.get('away', '?')}" if sc else "?-?"
    rc = r.get("red_cards") or {}
    rcs = f" (RC {rc.get('home')}-{rc.get('away')})" if rc and (rc.get("home") or rc.get("away")) else ""
    when = (r.get("finished_at") or r.get("scheduled_at") or "")[:10]
    return f"{r.get('event_id', '?')} | {r.get('home_team', '?')} {score} {r.get('away_team', '?')}{rcs} | {r.get('league') or '?'} | {when}"


def fmt_result(d, a):
    if "results" in d:  # list response {count, results[]}
        rs = d.get("results", [])
        print(f"Results — {d.get('count', len(rs))} shown")
        for r in rs:
            print(_result_line(r))
        if a.limit and len(rs) >= a.limit:
            print(f"… first {a.limit} only — narrow with --date/--team/--league.")
    elif d.get("status") == "not_found":
        print(f"not found: {d.get('event_id', '?')} is not in the 30-day results cache.")
    else:  # single MatchResult (GET /v1/results/{id})
        print(_result_line(d))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("verb")
    ap.add_argument("--detailed", action="store_true")
    ap.add_argument("--limit", type=int, default=0)  # requested cap, for the "more exist" footer
    a = ap.parse_args()
    raw = sys.stdin.read()
    try:
        d = json.loads(raw)
    except Exception:
        sys.stdout.write(raw)
        return
    if a.detailed:
        print(json.dumps(d, ensure_ascii=False, indent=2))
        return
    fn = globals().get("fmt_" + a.verb)
    if fn is None:
        print(json.dumps(d, ensure_ascii=False))
        return
    fn(d, a)


if __name__ == "__main__":
    main()
