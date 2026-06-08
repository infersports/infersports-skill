# InferSports skill

A portable [Agent Skill](https://code.claude.com/docs/en/skills) for live **Asian-priced
football & basketball odds + scores** — over the [InferSports](https://infersports.dev) REST API.
**Read-only. Keyless.** No account, no API key, no payment.

Ask your agent things like:
- *Who's favored in Brazil vs Argentina?* · *What's the score?* · *When do they kick off?*
- *What's the sharp Asian handicap for Man City vs Arsenal?*
- *What games are on today?* · *Convert 2.08 decimal to Hong Kong odds* · *What was the Myanmar result?*

Five bundled verbs (`today` · `match` · `line` · `convert` · `result`) — the agent picks a verb
and passes arguments; each prints one concise line. The agent never hand-builds an API call.

---

## Install

### Claude Code — two lines (recommended)
```
/plugin marketplace add infersports/infersports-skill
/plugin install infersports@infersports
```
Then ask away.

### Any agent (Claude Code · Codex · OpenClaw / lobster) — one prompt
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

### No git?
Swap step 2 of the prompt for: download **https://infersports.dev/skill.tgz** and extract it
(`tar xzf skill.tgz`) so the `infersports/` folder lands in your skills directory.

### Requirements
`bash`, `curl`, `python3` on PATH (already present on macOS/Linux). The skill talks only to the
public InferSports API at `https://api.infersports.dev`.

---

## What it is (and isn't)
- **Read-only & informational.** It reports odds, lines, scores, and results. It **never** places,
  recommends, or sizes a bet.
- **Keyless Free tier** by default. Set `INFERSPORTS_API_KEY` (an `isk_…` key) to raise rate limits.
- Wraps the **highest-frequency** reads. For value/arbitrage detection, opening-line movement,
  per-book breakdowns, batch slate scans, or the bookmaker catalogue, see
  [`plugins/infersports/skills/infersports/references/full-api.md`](plugins/infersports/skills/infersports/references/full-api.md)
  (the full REST docs + the MCP server). The MCP server is also one-line installable:
  `claude mcp add --transport http infersports https://api.infersports.dev/mcp`.

## Links
- Site & docs: https://infersports.dev
- API: https://api.infersports.dev · OpenAPI: https://api.infersports.dev/docs

## License
MIT — see [LICENSE](LICENSE).
