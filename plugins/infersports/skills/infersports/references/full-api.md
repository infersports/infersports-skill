# InferSports — full API (the long tail this skill doesn't wrap)

The [`infersports`](../SKILL.md) skill wraps the twelve highest-frequency verbs (today / events /
digest / match / preview / line / fair / scoreprob / compare / scan / convert / result). Everything below is the
same read-only API — reach for it when a request falls outside those twelve.

## Two ways in
- **REST** — base `https://api.infersports.dev`, keyless Free tier.
  Docs: https://docs.infersports.dev · interactive/OpenAPI: https://api.infersports.dev/docs ·
  agent map: https://api.infersports.dev/llms.txt (full appendix: `/llms-full.txt`).
- **Remote MCP** (for MCP-capable hosts) — one line:
  `claude mcp add --transport http infersports https://api.infersports.dev/mcp`
  (keyless Free tier, 16 tools).

## The full 16-tool surface — POST `/v1/mcp/<tool>`, JSON body
**Wrapped by this skill already:** `list_today_matches` (today.sh), `list_events` (events.sh = ONE
specific day's schedule, timezone-aware), `scan_slate` (scan.sh = today's value top-N; digest.sh =
today's highlights), `match_info` (match.sh; also preview.sh), `get_sharp_line` (line.sh; fair.sh =
fair as probabilities; also preview.sh), `score_prob` (scoreprob.sh = market-implied correct-score probabilities), `compare_prob` (compare.sh = judge an external/prediction-market
price vs the sharp fair line), `convert/odds` + `convert/handicap`/`explain_handicap` (convert.sh),
`list_results` + `get_result` / `GET /v1/results` (result.sh).

**The long tail — call REST/MCP directly (NOT in this skill):**
- `find_match` — resolve a fixture name → event id + confidence + alternatives.
- `get_match_odds` — every quote for a match across books, in any odds format.
- `compare_lines` — one market across books: best price per outcome, consensus line, per-book overround, de-vigged fair odds.
- `get_opening_line` — each book's TRUE opening odds (初盘) paired with its current price = line movement. The Asian edge.
- `find_value` — one fixture's outcomes that beat the sharp de-vigged fair line, with edge % (scan.sh covers the slate-wide top-N; this is the per-fixture deep dive). Detection only.
- `find_arbitrage` — cross-book price inefficiencies + guaranteed margin % + which book holds each leg. Detection only.
- `scan_slate` (raw) — the whole slate's per-fixture value/arb signal in ONE heavy payload; scan.sh/digest.sh already wrap the capped top-N, so reach here only for the full uncapped slate on a big-context host.
- `list_bookmakers` — the bookmaker catalogue available on your tier.

## Conventions
- Odds formats: `decimal` · `hk` · `malay` · `american` · `indonesian` · `probability`.
- Coverage: football & basketball; markets 1x2 / Asian handicap / totals; full-time & half-time.
- Free tier excludes the sharp book (Pinnacle) + select books; an `isk_…` key (header
  `Authorization: Bearer isk_…`) unlocks more and raises rate limits.
- Every odds payload carries `as_of` (freshness) + `stale`. Intent-complete tools also carry a
  `decision` block (`safe_to_proceed` / `ask_user` / `next_action`) and a ready-to-read `summary`.
- IDs are opaque `evt_…` (Sqids). Get them from `today.sh` / `find_match` / `GET /v1/events` — never construct one.
- No bet placement, ever. Read-only, informational.
