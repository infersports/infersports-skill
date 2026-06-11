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
    if d.get("note"):
        print(d["note"])
    if a.limit and len(matches) >= a.limit:
        print(f"… first {a.limit} only — more exist. Narrow with --sport/--status/--league, or use `match <team>`.")


def fmt_events(d, a):
    matches = d.get("matches", [])
    tz = d.get("timezone")
    head = f"{d.get('date', '?')}"
    if d.get("date_to"):
        head += f" → {d['date_to']}"
    head += f" ({tz})" if tz else " (UTC)"
    print(f"Events {head} — {len(matches)} shown")
    for m in matches:
        line = m.get("summary") or f"{m.get('home_team', '?')} vs {m.get('away_team', '?')}"
        print(f"{m.get('event_id', '?')} | {line}")
    if d.get("truncated"):
        print(f"… capped at {len(matches)} — more on this day. Narrow with --sport/--status/--league.")


def _alts(d, shown=""):
    # the BEST candidate rides in `match` (alternatives = the rest) — print it first or its id is lost
    m = d.get("match") or {}
    if m.get("event_id"):
        print(f"  {m.get('event_id')} | {m.get('home_team', '?')} vs {m.get('away_team', '?')} (best match)")
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
        if d.get("note"):
            print(d["note"])
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


def _opening_phrase(op, m):
    """'pre-match: X opened -N' from get_opening_line — the strength reference for a live match.

    Consensus = the most common opening AH line across books; ties go to the line whose opening
    prices are most balanced (a full-ladder book's 'opening' can be an off-centre rung like
    -1.5 @ 2.86/1.35 — the mode filters it out). Sign is normalised to a team name, so the reader
    never needs to know that a positive line means the away side.
    """
    if not op or op.get("status") != "ok":
        return None
    lines = [
        ln for ln in op.get("lines") or []
        if ln.get("market_type") == "asian_handicap" and ln.get("period") == "full_time"
        and ln.get("line") is not None and ln.get("opening")
    ]
    if not lines:
        return None
    counts = {}
    for ln in lines:
        counts[ln["line"]] = counts.get(ln["line"], 0) + 1
    top = max(counts.values())

    def balance(v):
        return min(
            abs((ln["opening"].get("home") or 0) - (ln["opening"].get("away") or 0))
            for ln in lines if ln["line"] == v
        )

    line = sorted((v for v, c in counts.items() if c == top), key=balance)[0]
    if line == 0:
        return "pre-match: opened level (pick'em)"
    who = m.get("home_team", "home") if line < 0 else m.get("away_team", "away")
    return f"pre-match: {who} opened {-abs(line):+g}"


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
    if m.get("status") == "live":
        # Live: score first; the % answers "who wins FROM HERE" (it prices the current score+clock,
        # NOT team strength); strength = the pre-match opening line. Books pull the 1x2 near full
        # time → no favorite → the from-here segment simply drops.
        bits.append(_when(info, m))
        if fav:
            bits.append(f"· from here: {fav.get('team') or fav.get('outcome', '?')} {pct(fav.get('win_probability'))}")
        opening = _opening_phrase(d.get("opening"), m)
        if opening:
            bits.append(f"· {opening}")
        print(" ".join(bits))
        return
    if fav:
        bits.append(f"{fav.get('team') or fav.get('outcome', '?')} favored ({pct(fav.get('win_probability'))})")
    else:
        probs = info.get("implied_probabilities") or {}
        if probs.get("home") is not None and probs.get("away") is not None:
            # priced but no favorite = a pick'em (server withholds the label on near-ties)
            bits.append(f"evenly matched ({pct(probs['home'])} / {pct(probs['away'])})")
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
    # live first, then marquee (book count = how much the market cares) — a 7-book World Cup
    # fixture at 19:00 outranks a 1-book youth friendly at 09:00; kickoff breaks ties.
    return (0 if e.get("status") == "live" else 1, -books, sa)


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


def _line_tag(mt, line):
    if line is None:
        return ""
    return f" {line:+g}" if mt == "asian_handicap" else f" {line:g}"


def fmt_compare(d, a):
    # is an external (prediction-market) probability good vs our sharp de-vigged fair line?
    status = d.get("status")
    if status != "ok":
        print(d.get("summary") or status or "?")
        if status == "ambiguous":
            _alts(d, d.get("summary", ""))
        return
    m = d.get("match") or {}
    mt = d.get("market_type", "")
    edge = d.get("edge_pp")
    edge_s = f"{edge:+g}pp" if edge is not None else "?"
    roi = d.get("ev_roi")
    roi_s = f" (ROI {roi:+.1%})" if isinstance(roi, (int, float)) else ""
    verdict = (d.get("verdict") or "").replace("_", " ").upper()
    label = d.get("external_label") or "your"
    src = d.get("fair_from")
    method = d.get("devig_method")
    src_s = (f" · de-vig {src}" + (f"/{method}" if method else "")) if src else ""
    print(
        f"{m.get('home_team', '?')} v {m.get('away_team', '?')} — "
        f"{_MKT.get(mt, mt)}{_line_tag(mt, d.get('line'))} {d.get('outcome', '?')}: "
        f"sharp fair {pct(d.get('fair_prob'))} vs {label} {pct(d.get('external_prob'))} "
        f"→ {edge_s}{roi_s} · {verdict}{src_s}"
    )
    for c in d.get("caveats", []):
        print(f"  ⚠ {c}")
    print("Detection only — the edge is information, not a pick. The call is yours.")


def fmt_fair(d, a):
    # the sharp de-vigged fair line as probabilities — the reference a PM/cross-venue trader checks against.
    status = d.get("status")
    if status != "ok":
        print(d.get("summary") or status or "?")
        if status == "ambiguous":
            _alts(d, d.get("summary", ""))
        return
    m = d.get("match") or {}
    comp = d.get("comparison") or {}
    fair = comp.get("fair_odds") or {}
    mt = comp.get("market_type", "")
    head = f"{m.get('home_team', '?')} v {m.get('away_team', '?')}"
    if not fair:
        print(f"{head} — no sharp {mt or 'fair'} line right now (try another market/period or a key with more books).")
        return
    legs = " / ".join(f"{k} {pct(1.0 / v)}" for k, v in fair.items() if v)
    tail = []
    if comp.get("fair_from"):
        tail.append(f"de-vig {comp['fair_from']}")
    if comp.get("stale"):
        tail.append("stale — confirm")
    tail_s = " · " + " · ".join(tail) if tail else ""
    print(f"{head} — sharp fair ({_MKT.get(mt, mt)}{_line_tag(mt, comp.get('consensus_line'))}): {legs}{tail_s}")


def fmt_scoreprob(d, a):
    # market-implied correct-score distribution — the market's numbers, never a pick.
    status = d.get("status")
    if status != "ok":
        print(d.get("summary") or status or "?")
        if status == "ambiguous":
            _alts(d, d.get("summary", ""))
        return
    m = d.get("match") or {}
    head = f"{m.get('home_team', '?')} v {m.get('away_team', '?')}"
    scores = " · ".join(f"{e['score']} {pct(e['prob'])}" for e in d.get("scores") or [])
    cum = d.get("top_cum")
    tail = []
    if cum is not None:
        tail.append(f"top {len(d.get('scores') or [])} = {pct(cum)} of all outcomes")
    if d.get("fair_from"):
        tail.append(f"from de-vig {d['fair_from']}")
    if d.get("stale"):
        tail.append("stale — confirm")
    print(f"{head} — market-implied scores: {scores} ({'; '.join(tail)}). Market's distribution, not a pick.")


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
