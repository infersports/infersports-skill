# InferSports edge-agent Skill

A lightweight, **portable** Agent Skill wrapping the InferSports REST API — live football &
basketball odds + scores for small-context / on-device agents. **Read-only, keyless.**

Eleven verbs as bundled scripts — `today` / `events` / `digest` / `match` / `preview` / `line` /
`fair` / `compare` / `scan` / `convert` / `result` — the agent picks a verb and passes args; each
prints one concise line (`digest` / `preview` / `scan` / `compare` package several reads / a de-vig
into one). `events` lists a specific day's schedule (timezone-aware), `today` lists today + live.
`fair` gives the sharp de-vigged fair probability; `compare` judges an external (e.g. Polymarket/Kalshi)
price against it. The agent never builds a URL. See `SKILL.md` for the full contract.

## Layout
- `SKILL.md` — the **agent-facing contract** (name + description always loaded; body read when a
  question matches).
- `scripts/` — one bash script per verb + `_common.sh` (HTTP/config) + `_fmt.py` (concise formatter).
- `references/full-api.md` — long-tail pointer (the full 16-tool MCP / REST surface) for asks beyond
  the twelve verbs.
- `fixtures/` — offline mock payloads (`INFERSPORTS_MOCK=1`).

## Install
Drop this folder where your agent loads skills (OpenClaw: `~/.openclaw/workspace/skills/`; Claude: a
skills directory). The agent discovers it by name + description and reads `SKILL.md` when a question
matches. Requires `bash`, `curl`, `python3` on `PATH`. Keyless by default; set `INFERSPORTS_API_KEY`
to raise limits.

## Portability & host-agent behavior (read this)
The skill has **two layers with very different guarantees**:

- **Deterministic layer — the scripts.** Same input → same output on every host. The scripts only ever
  call the InferSports API, return concise read-only data, and never recommend, size, or place a bet.
  This is identical whether the backbone is Claude, a GPT/Codex-class model, or a small local model.
- **Instructional layer — `SKILL.md` prose.** This is a *prompt* to whichever backbone runs the skill,
  and compliance **varies by model**. A skill cannot revoke its host agent's own tools (web search,
  shell), so it cannot *force* a backbone to stay inside the boundary — it can only ask clearly.

Observed across backbones (2026-06): a **Claude** backbone, given only this skill, respected the
read-only posture (relayed the numbers, declined to pick a bet) and did **not** web-search
out-of-scope questions. Some **other** backbones (e.g. a GPT/Codex-class agent) sometimes web-search an
out-of-scope sport, or append a betting "lean" on top of the clean script output. **These are
host-model behaviors layered on top of the skill, not the skill's output** — the script output is
clean in every case.

Practical implication: **treat behavior divergence across hosts as expected.** The skill's guarantees
live in the script layer; the prose nudges (scope = football + basketball only; not-found is terminal;
never add a pick) firm up compliant backbones but can't bind every host. A hard-deterministic path
(slash command → tool, bypassing the model) would require a **host-specific plugin** and is
deliberately out of scope here, to keep this skill portable across agents.

## Verify
```bash
INFERSPORTS_MOCK=1 scripts/today.sh     # offline, deterministic (bundled fixtures)
scripts/today.sh --limit 5              # live, keyless
```
