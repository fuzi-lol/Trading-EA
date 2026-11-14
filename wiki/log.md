# Wiki log (append-only)

Each entry starts with `## [YYYY-MM-DD] <ingest|query|lint> | <title>` so `grep "^## \[" wiki/log.md | tail -5` shows recent activity.

## [2026-11-14] ingest | Initial build of the wiki (all 30 own EAs, commit 25e734f)
- Read every own `.mq5` (~18k lines), `.set`, README and RESULTS file. Four parallel code reviews, then high-impact claims checked by hand (tagged
  `[verified]` on the pages).
- Created `AGENTS.md` (schema), 20 strategy pages, 5 concept pages, the third-party page, `overview.md` and `index.md`.
- Main findings:
  - MultiSession (#1 in the Oct report) is third-party L0rdTrey code, and its report numbers don't fit the stated $10k deposit.
  - The trailing in SMC_Confluence and MultiTF never runs.
  - GoldenTime's partial close never runs.
  - NAS100_ORB counts ticks as bars.
  - YT_Strategies Supertrend + 200 EMA on gold is the most robust result.

## [2026-11-14] lint | First pass
- Checked that every own `.mq5` appears in exactly one page's `files:`, that every relative link resolves, and that cited line numbers exist. Script used:

```bash
cd projects/Trading-EA
# 1. every own .mq5 is listed in exactly one strategy page
for f in $(find . -name '*.mq5' -not -path '*L0rdtrey*' | sed 's|^\./||'); do
  n=$(grep -l "^files:.*$f" wiki/strategies/*.md | wc -l); [ "$n" -ne 1 ] && echo "COVERAGE $n $f"; done
# 2. every relative link resolves
python3 - <<'PY'
import re,os,glob
for p in glob.glob('wiki/**/*.md',recursive=True):
    for l in re.findall(r'\]\(([^)#]+)\)',open(p).read()):
        if l.startswith('http'): continue
        if not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(p),l))): print('BROKEN',p,l)
PY
# 3. stale pages
git diff 25e734f --stat -- '*.mq5' '*.set'
```
