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


_MKT = {"asian_handicap": "AH", "totals": "OU", "1x2": "1x2"}


def _value_line(e):
    bv = e.get("best_value") or {}
    mt = bv.get("market_type", "")
    line = bv.get("line")
    if line is None:
        lt = ""
    elif mt == "asian_handicap":
        lt = f" {line:+g}"  # handicaps carry a sign
    else:
        lt = f" {line:g}"   # totals line has no sign
    st = e.get("status", "")
    clk = e.get("clock")
    tag = f"LIVE {clk}" if (st == "live" and clk) else st
    edge = bv.get("edge_pct")
    edge_s = f"+{round(float(edge), 1)}%" if edge is not None else "?"
    return (
        f"{e.get('event_id', '?')} | {e.get('home_team', '?')} v {e.get('away_team', '?')} | "
        f"{bv.get('bookmaker', '?')} {_MKT.get(mt, mt or '?')}{lt} {bv.get('outcome', '?')} "
        f"@{bv.get('price', '?')} | fair {bv.get('fair_price', '?')} | {edge_s}"
        + (f" | {tag}" if tag else "")
    )


def fmt_scan(d, a):
    # scan is value-first: show the fixtures carrying a +EV signal, top-N already capped server-side.
    val = [e for e in d.get("entries", []) if e.get("best_value")]
    print(f"Value scan {d.get('date', '?')} — {len(val)} shown (scanned {d.get('count', '?')})")
    for e in val:
        print(_value_line(e))
    if not val:
        print("no value at this threshold — lower --min-edge or widen --sport/--market.")
    elif d.get("truncated"):
        print(f"… top {a.limit or len(val)} only — narrow --sport/--market or raise --min-edge.")
    if val:
        print("Detection only — the edge is information, not a pick. The call is yours.")


def _when(info, m):
    if m.get("status") == "live":
        sc = m.get("score") or {}
        clk = m.get("clock")
        return f"LIVE {sc.get('home', '?')}-{sc.get('away', '?')}" + (f" {clk}" if clk else "")
    loc = info.get("scheduled_at_local")
    if loc and len(loc) >= 16:
        return f"kicks off {loc[11:16]}" + (f" {info.get('timezone')}" if info.get("timezone") else "")
    utc = m.get("scheduled_at")
    if utc and len(utc) >= 16:
        return f"kicks off {utc[11:16]} UTC on {utc[5:10]}"
    return ""


def fmt_preview(d, a):
    info = d.get("info") or {}
    status = info.get("status")
    if status != "ok":
        print(info.get("summary") or f"not found: {info.get('query', '?')}")
        if status == "ambiguous":
            _alts(info, info.get("summary", ""))
        return
    m = info.get("match") or {}
    bits = [f"{m.get('home_team', '?')} vs {m.get('away_team', '?')} —"]
    fav = info.get("favorite")
    if fav:
        bits.append(f"{fav.get('team') or fav.get('outcome', '?')} favored ({pct(fav.get('win_probability'))})")
    else:
        bits.append("no clear favorite priced")
    cmp = ((d.get("line") or {}).get("comparison")) or {}
    cl = cmp.get("consensus_line")
    if cl is not None:
        bits.append(f"· AH {cl:+g}")
    when = _when(info, m)
    if when:
        bits.append(f"· {when}")
    print(" ".join(bits))


def _digest_when(e):
    if e.get("status") == "live":
        sc = e.get("score") or {}
        clk = e.get("clock")
        return f"LIVE {sc.get('home', '?')}-{sc.get('away', '?')}" + (f" {clk}" if clk else "")
    sa = e.get("scheduled_at") or ""
    return f"{sa[11:16]} UTC" if len(sa) >= 16 else "time TBD"


def _digest_key(e):
    books = e.get("book_count") or 0
    sa = e.get("scheduled_at") or "9999"
    # live first (marquee = more books first); then soonest kickoff (marquee breaks ties).
    return (0, -books, sa) if e.get("status") == "live" else (1, sa, -books)


def fmt_digest(d, a):
    entries = [e for e in d.get("entries", []) if e.get("status") != "finished"]
    entries.sort(key=_digest_key)
    n = a.limit or 6
    top = entries[:n]
    print(f"Worth watching today ({d.get('date', '?')}) — top {len(top)} of {len(entries)}")
    for e in top:
        bc = e.get("book_count", 0)
        flag = " · value" if (e.get("value_count") or 0) > 0 else ""
        fav = e.get("favorite")
        fav_seg = ""
        if fav:
            who = fav.get("team") or fav.get("outcome", "")
            fav_seg = f" | {who} {pct(fav.get('win_probability'))}"
        print(
            f"{e.get('event_id', '?')} | {e.get('home_team', '?')} v {e.get('away_team', '?')} | "
            f"{_digest_when(e)}{fav_seg} | {bc} book{'' if bc == 1 else 's'}{flag}"
        )
    if len(entries) > n:
        print(f"… {len(entries) - n} more on — raise --limit, or use today.sh for the full list.")


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
