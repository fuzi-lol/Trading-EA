# Trading-EA — MetaTrader 5 Expert Advisors + their wiki

**Goal:** a lab of MT5 Expert Advisors (MQL5 trading robots), mostly for **XAUUSD (gold)** plus some forex
majors and NAS100, built to find a strategy that holds up in backtests (and is safe enough for a prop-firm
account such as FundingPips). Each EA turns a known retail idea (SMC order blocks/FVGs, session-range breakouts,
RSI/EMA/Bollinger scalps, YouTube strategies) into code. Then it gets backtested in the MT5 Strategy Tester.
**Status:** working / research. Nothing here has a proven live edge yet (see `wiki/overview.md`).

> Research and education only. These EAs *can* place real orders if attached to a live account.

**Start every session by reading `wiki/index.md`.** It lists every strategy in one table and answers
"what strategies do we have". Read `wiki/overview.md` for what works and what doesn't.

---

## How this folder is organised (LLM-wiki pattern)

This repo follows Karpathy's "LLM Wiki" idea (gist `karpathy/442a6bf555914893e9891c11519de94f`): the LLM
reads the raw material once, then writes and maintains a linked set of markdown pages. Future questions are
answered from those pages, not by re-reading 18,000 lines of MQL5 each time.

| Layer | What | Who edits it |
|-------|------|--------------|
| **Raw sources** | The EA code (`<EA>/<EA>.mq5`), parameter files (`*.set`), and backtest write-ups (`Backtest_Report_Oct2026.md`, `*/RESULTS.md`, `SMC_Confluence/backtest_results/`, `*/README.txt`) | The user / coding sessions. The wiki **never** changes these. |
| **Wiki** | `wiki/` (LLM-written markdown) | The LLM, following the rules below |
| **Schema** | this file (`AGENTS.md`; `CLAUDE.md` just loads it) | The user and the LLM together |

**One difference from Karpathy's version:** his raw sources never change, but ours are *code that does
change*. Every strategy page therefore records the commit it was written against (`source_commit` in the
frontmatter). If `git diff <source_commit> -- <files>` shows changes, the page is stale. Re-read the code
and update the page.

### Layout

```
Trading-EA/
├── AGENTS.md / CLAUDE.md        schema (this file)
├── README.md                    one-line repo readme
├── Backtest_Report_Oct2026.md   raw: 15-EA comparison, FundingPips sim, Oct 2026
├── SMC_V1..V8_*.set             raw: parameter sweeps for SMC_Confluence (kept at root)
├── DoubleTrap_V1.set            raw: params for DoubleTrapStrategy
├── <EA folder>/                 raw: one folder per EA — .mq5 source, .set files, sometimes RESULTS.md/README.txt
├── M1_MomentumScalper/L0rdtrey EAs/   THIRD-PARTY dump (552 files, 77 MB, many compiled .ex5 only).
│                                Not our code. Don't ingest; see wiki/third-party-l0rdtrey.md
└── wiki/
    ├── index.md                 catalog: every page, one line each + the strategy table  ← read first
    ├── overview.md              synthesis: what works, what doesn't, what to try next
    ├── log.md                   append-only history of ingests / queries / lint passes
    ├── strategies/<slug>.md     one page per EA family (versions of one idea share a page)
    ├── concepts/<slug>.md       ideas or traps shared by 2+ EAs (sizing, server time, SMC terms…)
    └── third-party-l0rdtrey.md  what the vendored folder is, which of "our" EAs came from it
```

### Strategy page template (`wiki/strategies/<slug>.md`)

```markdown
---
name: <EA name>
files: [<EA>/<EA>.mq5, <EA>/<x>.set]       # every raw file this page describes
market: XAUUSD | EURUSD,… | NAS100
timeframe: M1 | M5 | M15 | H1
family: smc | session-breakout | indicator | scalper | multi-strategy | pattern  (combine with +)
origin: own | youtube | third-party (L0rdTrey)
verdict: promising | marginal | no-edge | broken | untested | unproven   (unproven = results exist but are unreliable)
source_commit: <short sha of Trading-EA when the code was read>
last_reviewed: YYYY-MM-DD
---
# <EA name>
One-paragraph summary in plain words.

## Entry (as the code does it)      — with `file.mq5:line` refs
## Exit                            — SL, TP, break-even, trail, partials, time exits
## Sizing & risk                   — fixed lot / % risk, caps, daily limits
## Settings files                  — what each .set changes
## Backtest evidence               — headline numbers COPIED from the raw report, with a link to it
## Issues found in code            — each tagged [verified] / [from report] / [unverified]
## Verdict & next step
## Related                         — links to concept pages and sibling strategies
```

Rules for page content:
- **Describe what the code does, not what its comments or name promise.** Cite `file.mq5:line`.
- **Tag every claim about a bug or result** `[verified]` (you opened the line), `[from report]`
  (copied from a raw backtest file), `[inference]` (reasoned from numbers or assumptions, not seen directly), or `[unverified]`
  (someone said so, nobody checked).
- **Numbers come from raw files, copied exactly**, with a link to the file. Never round, and never paraphrase
  them from a summary. Say which period, model ("every tick" vs "1-minute OHLC"), deposit and server.
- A strategy with no backtest on record says **"no backtest on record"**. Don't leave the section blank.
- Keep pages short: a page someone can read in two minutes. Link out instead of repeating.
- Links are relative markdown links (e.g. from a strategy page to `../concepts/position-sizing.md`) so they work on GitHub.

---

## Workflows

### Ingest — a new or changed EA
1. Read the `.mq5` **in full** plus its `.set` files.
2. Create or update `wiki/strategies/<slug>.md` from the template; set `source_commit` (`git rev-parse --short HEAD`)
   and `last_reviewed`.
3. If it shares a trap or idea with another EA, update the matching `wiki/concepts/` page (create one only
   when 2+ EAs share it) and link both ways.
4. Update the row in `wiki/index.md` and, if the big picture changed, `wiki/overview.md`.
5. Append to `wiki/log.md`: `## [YYYY-MM-DD] ingest | <EA name>` + 1–3 lines.

### Ingest — a new backtest result
1. Save the raw result first (a `RESULTS.md` in the EA folder or a dated report at the root). Never only in the wiki.
2. Copy the headline numbers into the strategy page's *Backtest evidence*, with a link and the test conditions.
3. If the result contradicts an earlier one, say so explicitly on the page ("Oct report said X; this run says Y").
4. Update the `verdict` and the index row if it changed, and log it.

### Query — "which strategy does X / what do we know about Y"
1. Read `wiki/index.md`, then the pages it points to. Open `.mq5` only to confirm a detail or when a page is stale.
2. Answer with links to wiki pages (and `file:line` for code facts).
3. If the answer is a useful new comparison or analysis, file it as a wiki page and log it as `query`.

### Lint — health check (run when asked, or after several ingests)
- Every own `.mq5` outside `L0rdtrey EAs/` is listed in exactly one strategy page's `files:`.
- Every strategy page appears in `index.md`; every relative link resolves.
- Stale pages: `git diff <source_commit> --stat -- <files>` is non-empty → re-ingest.
- `file:line` refs still point at the right code.
- Contradictions between pages, or between a page and the raw reports.
- Log it: `## [YYYY-MM-DD] lint | <summary>`.

A quick script for the first two checks lives in the log entry of the first lint pass (`wiki/log.md`).

---

## Working on the code (not the wiki)

- **Language:** MQL5 (MetaTrader 5). Compile in MetaEditor; there's no build tool in this repo.
  Backtests run in the MT5 Strategy Tester. Earlier sessions drove it through an `mt5-quant` MCP server (see
  the footer of `Backtest_Report_Oct2026.md`).
- **Server time:** the session hours in these EAs are **broker server time**, assumed (not verified) to be UTC+2/+3
  (FundingPips). Check `wiki/concepts/server-time.md` before changing any hour input.
- **`.set` files must list every input in declaration order** or MT5 silently ignores the overrides (found
  during the YT_GoldScalpers tuning; see `wiki/concepts/backtesting-method.md`).
- **FundingPips tester bug:** `SYMBOL_TRADE_TICK_VALUE` can return 0 for XAUUSD. Risk-based sizing then gives
  lot = 0. See `wiki/concepts/position-sizing.md`.
- New EA → new folder `<EAName>/<EAName>.mq5`, then run the *Ingest* workflow above in the same change.

## Git

- This folder is **its own git repo**. Its remote is `git@github.com:fuzi-lol/Trading-EA.git` (not the
  `Dhanesh-Pottekula` account), and it is **not** registered as a submodule of the `learning-os` workspace yet.
- Commit wiki changes together with the code change they describe. Commit or push only when the user asks.
- `.gitignore` only covers `.DS_Store`. The 77 MB third-party folder is tracked.
