<div align="center">
  <img src="assets/logo.svg" width="76" alt="InferSports" />

# InferSports Skill

Live Asian-priced football & basketball odds, scores, and de-vigged fair lines —
packaged as an [Agent Skill](https://code.claude.com/docs/en/skills) for Claude Code,
Codex, OpenClaw, or any agent that can run a shell script.

**Read-only · Keyless · 11 verbs · one line of output per answer**

[![License](https://img.shields.io/github/license/infersports/infersports-skill)](LICENSE)
[![Skill](https://img.shields.io/badge/skill-v1.1.4-1E2A24)](plugins/infersports/skills/infersports/SKILL.md)
[![MCP server](https://img.shields.io/badge/MCP%20server-16%20tools-E0683C)](https://api.infersports.dev/mcp)
[![API docs](https://img.shields.io/badge/OpenAPI-api.infersports.dev-blue)](https://api.infersports.dev/docs)

</div>

---

You ask in plain English; the agent picks a verb and relays one concise line back:

```console
# "anything worth watching today?"
$ scripts/digest.sh --sport football --limit 3
Worth watching today (2026-06-12) — top 3 of 64
  evt_… | Brazil vs Argentina    | LIVE 1-0 1h 36 | 5 books · value
  evt_… | Mexico vs South Africa | 19:00 UTC      | 7 books
  evt_… | Korea Rep. vs Czechia  | 10:00 UTC      | 6 books

# "Polymarket has Mexico at 52¢ to beat South Africa — good price?"
$ scripts/compare.sh "Mexico vs South Africa" --prob 0.52 --outcome home --label polymarket
Mexico v South Africa — 1x2 home: sharp fair 55.6% vs polymarket 52.0% → +3.6pp (ROI +6.9%) · GOOD · de-vig pinnacle/power

# "what's the score in the Brazil game?"
$ scripts/match.sh "Brazil vs Argentina" --tz America/Sao_Paulo
Brazil vs Argentina — LIVE 1h 12 1-0.
  favorite: Brazil (61.4%)
```

No account, no API key, no payment. It serves two crowds equally well: people
who just want to know what's worth watching tonight, and prediction-market
traders (Polymarket, Kalshi) who want a sharp, de-vigged reference price before
taking a side.

## Why this exists

- **Asian market data, normalized.** Asian handicap, totals, and 1x2 (full-time
  *and* half-time) from 7 curated books, every quote convertible between decimal,
  Hong Kong, Malay, Indonesian, American, and implied probability — quarter-line
  math handled correctly.
- **Built for small context windows.** Every verb returns one line per item,
  capped (a busy weekend never floods the context). `--detailed` opts into full
  JSON only when you actually need it.
- **Deterministic by design.** The scripts own the endpoints; the agent never
  hand-builds an API call, guesses a URL, or web-searches a score. Ambiguity
  comes back as an explicit `ask:` with candidates — never a silent guess.
- **Read-only, no betting advice.** It reports lines, prices, and detected edges
  as data. It never places, recommends, or sizes a bet — and instructs the agent
  not to either.

## Install

### The one-liner (any agent)

```text
Read https://infersports.dev/skill.md and follow the instructions to connect to InferSports.
```

The agent fetches the guide and picks the right surface for its host — this skill,
the remote MCP server, or plain REST. Prefer an exact recipe? Use one below.

### Claude Code — plugin (recommended)

```
/plugin marketplace add infersports/infersports-skill
/plugin install infersports@infersports
```

### Prefer MCP? One line

```
claude mcp add --transport http infersports https://api.infersports.dev/mcp
```

The remote MCP server carries 16 tools (everything the skill does, plus per-book
depth, arbitrage detection, and opening lines). Skill and MCP server coexist fine.

### Any agent (Codex · OpenClaw · others) — one prompt

Paste this whole block to your agent:

```text
Install the "InferSports" sports-odds skill for me, verify it works, then show me what to ask.

1. Find where your agent loads Agent Skills and create it if missing:
   • Claude Code → ~/.claude/skills/   (or ./.claude/skills/ for this project only)
   • OpenClaw (lobster) → ~/.openclaw/workspace/skills/
   • Codex / other → your skills (agent-skills) directory
2. Clone this repo to a temp folder:
   git clone --depth 1 https://github.com/infersports/infersports-skill /tmp/infersports-skill
3. Find the folder containing SKILL.md (it's plugins/infersports/skills/infersports) and copy
   that whole folder — named `infersports` — into your skills directory.
4. chmod +x <skills_dir>/infersports/scripts/*.sh
5. Verify offline:  INFERSPORTS_MOCK=1 <skills_dir>/infersports/scripts/today.sh --limit 3   (→ 3 demo matches)
6. Verify live (KEYLESS — no key, no signup):  <skills_dir>/infersports/scripts/today.sh --limit 3   (→ real matches)
7. Reload skills if needed, then confirm install and give me 3 example questions.

Read-only & keyless — never needs an account, API key, or payment. Needs bash, curl, python3.
```

No git? Swap step 2 for: download **https://infersports.dev/skill.tgz** and extract
(`tar xzf skill.tgz`) so the `infersports/` folder lands in your skills directory.

**Requirements:** `bash`, `curl`, `python3` on PATH (already present on macOS/Linux).
The skill talks only to the public InferSports API at `https://api.infersports.dev`.

## The 11 verbs

| Verb | Answers | Example |
|---|---|---|
| `today` | what's on today — live and scheduled, capped; filter a competition by name | `today.sh --league "World Cup"` |
| `events` | a specific day's schedule, in *your* timezone | `events.sh --date 2026-06-12 --tz Asia/Shanghai --league "World Cup"` |
| `digest` | today's highlights, ranked, top-N | `digest.sh --sport football --limit 5` |
| `match` | score, favorite, kickoff for one match | `match.sh "Brazil vs Argentina"` |
| `preview` | one-line brief — pre-match: favored % + line; live: score + from-here % + the pre-match opening line ("which team is stronger?") | `preview.sh "France vs Argentina" --tz Europe/Paris` |
| `line` | the sharp consensus line + best price, any odds format | `line.sh "Man City vs Arsenal" --format hk` |
| `fair` | de-vigged fair probabilities (the sharp reference) | `fair.sh "France vs Argentina" --market 1x2` |
| `compare` | judge an external (Polymarket/Kalshi) price vs fair | `compare.sh "France vs Argentina" --prob 0.52 --outcome home` |
| `scan` | today's value spots — where a book beats the fair line | `scan.sh --market asian_handicap --min-edge 1 --limit 5` |
| `convert` | odds-format conversion + handicap explainer | `convert.sh 2.08 decimal hk,malay,american` · `convert.sh --handicap -0.75` |
| `result` | finished-match score (30-day cache) | `result.sh "Myanmar" --date 2026-06-06` |

`digest`, `preview`, `scan`, and `compare` are **packaged**: each folds several
API reads (and the de-vig math) into a single capped answer, so the agent doesn't
burn context orchestrating the fan-out itself.

Match arguments accept a team name, `"A vs B"`, or an `evt_…` id straight from
`today`/`events` output. Ambiguous names (senior vs U21, two same-day fixtures)
return an `ask:` list to pin down with `--date` / `--sport`.

## What the data covers

| | |
|---|---|
| Sports | football + basketball — nothing else, by design |
| Markets | Asian handicap · totals (over/under) · 1x2, full-time **and** half-time |
| Books | 7 curated bookmakers; keyless Free tier covers the core set, an `isk_…` key unlocks the full catalogue and higher limits |
| Odds formats | decimal · Hong Kong · Malay · Indonesian · American · implied probability |
| Fair lines | power-method de-vig over the sharp book — the reference `fair`, `compare`, and `scan` are built on |
| Results | 30-day rolling cache of finished-match scores |

## Design notes

Things the skill does that a thin API wrapper wouldn't:

- **Concise-by-default contract.** One line per item, hard caps everywhere
  (`today` defaults to 20, max 50; `digest` ≤ 12). The skill is written for
  agents where every token of output competes with the user's actual task.
- **`ask:` / `ERROR:`+`FIX:` protocol.** Ambiguity and failures come back as
  structured, actionable lines the agent can act on mechanically — re-run with
  the suggested flag, or put the choice to the user. `not found` is documented
  as a *final* answer, not a cue to go scrape the web.
- **Offline mode for CI.** `INFERSPORTS_MOCK=1` answers every verb from bundled
  `fixtures/` — deterministic, no network. That's how you test an agent that
  uses this skill without flaky live data.
- **No-pick policy, enforced in the prompt.** SKILL.md instructs the agent to
  relay numbers and detected edges as printed and to decline "which bet should I
  place?" — detection is information, not advice.

## Repo layout

```
plugins/infersports/skills/infersports/
  SKILL.md          # the manifest the agent reads: verbs, rules, examples
  VERSION           # release version — sent as User-Agent infersports-skill/<version>
  scripts/          # the 11 verbs + shared _common.sh / _fmt.py
  references/       # full-api.md — the complete REST + MCP surface
  fixtures/         # offline mock responses (INFERSPORTS_MOCK=1)
```

## Beyond the skill

The skill wraps the highest-frequency reads. The full API adds per-book odds
depth, cross-book line comparison, arbitrage detection, opening-line snapshots,
and the bookmaker catalogue:

- REST: https://api.infersports.dev · OpenAPI: https://api.infersports.dev/docs
- MCP (16 tools): `claude mcp add --transport http infersports https://api.infersports.dev/mcp`
- In-repo reference: [`references/full-api.md`](plugins/infersports/skills/infersports/references/full-api.md)

## Configuration (all optional)

| Variable | Effect |
|---|---|
| `INFERSPORTS_API_KEY` | an `isk_…` key — higher rate limits, full book catalogue. Default keyless Free tier is enough for these verbs |
| `INFERSPORTS_API_BASE` | override the API host (default `https://api.infersports.dev`) |
| `INFERSPORTS_MOCK=1` | answer from bundled fixtures instead of the network |

## License

MIT — see [LICENSE](LICENSE).
