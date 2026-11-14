# Third-party folder: `M1_MomentumScalper/L0rdtrey EAs/`

**Not our code, and not ingested into this wiki.** It's a dump of someone else's EAs ("L0rdTrey" / "TREY"), stored inside the M1_MomentumScalper folder but
unrelated to [M1_MomentumScalper](strategies/m1-momentum-scalper.md).

- About 77 MB, **552 files** (303 `.mq5`; the rest are mostly compiled `.ex5`). The top level holds 120 files (`Ultimate_Grid_EA_*`, `PULSE_MATRIX_*`,
  `PhantomFlux_*`, `QUANTUM GRID`, …) plus a `GoldSurgeon Elite v1/` folder. `EAs by TREY/` holds more: 244 loose files (130 `.mq5` + 114 `.ex5`) plus `MY EAs/` (100 files), `trey bots/` (54),
  `GoldSurgeon Elite v1/` (4) and `TESTING EAs/` (1). All of it is tracked in git.
- 140 of the 303 `.mq5` files mention grid, martingale or lot multipliers. **Grid/martingale is how XANDER_Grid blew a $10k test account**
  ([from report]: -$10,172, max DD 101.5%).
- `.ex5` files are compiled binaries. They can't be read or reviewed, so don't run them on a real account.

## Links into our results
| Name in our files | Where its source lives | Note |
|---|---|---|
| [MultiSession_MajorPairs_EA](strategies/multi-session-major-pairs.md) | `EAs by TREY/MY EAs/MultiSession_MajorPairs_EA.mq5` | **byte-identical** to our `MultiSession_MajorPairs_EA/` copy; `#property copyright "L0rdTrey Systems"` |
| NightScalper (Oct report: -$807, PF 0.97, DD 26.7%, USDCAD) | `EAs by TREY/MY EAs/NightScalper.mq5` | no folder of its own |
| XANDER_Grid_XAUUSD (Oct report: -$10,172, DD 101.5%) | `EAs by TREY/MY EAs/XANDER_Grid_XAUUSD.mq5` | grid; the report says to delete it |
| EliteScalper2 (Oct report: -$852, PF 0.82, 4,839 trades) | `EAs by TREY/trey bots/EliteScalper2.mq5` | the report notes its "account lock" was removed for testing |

If one of these needs proper analysis, copy it into its own top-level folder first. Then run the *Ingest* workflow in `AGENTS.md`.
