# Server time, IST and DST

Every EA here reads hours from `TimeCurrent()`, which is **broker server time**. **None** has a GMT-offset input or daylight-saving handling. The hours were
chosen by people thinking in **IST** (UTC+5:30, no DST) or UK time, then converted by hand.

**[unverified assumption]** FundingPips (the backtest server) is assumed to run the usual "New York close" clock: **UTC+2 in winter, UTC+3 in summer** (US DST).
Nobody has checked this: `YT_Strategies/RESULTS.md` says the offset "wasn't checked", and the READMEs assume UTC+2, UTC+3 and UTC+0 in different places.
If the assumption holds, a fixed server hour moves by one hour of IST and UTC twice a year. **First task before trusting any hour:** compare `TimeCurrent()` with
`TimeGMT()` in the tester for a winter date and a summer date, and record the result here. The repo's own conversions assume UTC+2:

| Idea | Server hours in code | Real meaning (UTC+2 / UTC+3) | EA |
|---|---|---|---|
| IST 12:30–17:30 range, 19:00 entry | range 09–14, entry 15:30 | entry = 19:00 / 18:00 IST = **08:30 New York** both ways | [RangeEngulf](../strategies/range-engulf.md) |
| IST 18:45 zone | 13:15 (V5) / 18:45 (1845) | V5 is 18:45 IST only on UTC+0 | [GoldenTime](../strategies/golden-time.md) |
| IST 04:30–05:30 Asian range | 02–03 | assumes UTC+3 | [AsianRangeOB](../strategies/asian-range-ob.md) |
| London open H1 candle | 10:00 | London 08:00 (both, since London and NY shift together) | [GoldLondon](../strategies/gold-london.md) |
| UK 00–08 Asian range | UK+2 assumed | breaks in the weeks when US and UK DST differ | [YT_Strategies S3](../strategies/yt-strategies.md) |
| "Asian range 00–07, London open 07" | 00–07 | 07:00 server = 05:00 UTC, about **3 h before** London opens | [MultiSession](../strategies/multi-session-major-pairs.md) |
| NY cash open | 16:30 (code) / 15:30 (.set) | 09:30 vs 08:30 New York | [NAS100_ORB](../strategies/nas100-orb.md) |
| Kill zones | 10–13 / 11–13 + 15–21 | London morning and New York session | [SMC_Confluence](../strategies/smc-confluence.md), [GoldElite](../strategies/gold-elite-scalper.md), [DoubleTrap](../strategies/double-trap.md) |

If the server clock follows New York DST (see above), **times tied to New York** (data releases at 08:30 ET, the cash open at 09:30 ET) stay fixed in server time all year.
**Times tied to IST** don't. For setups described in IST, the code is right for only part of the year.

**Rule for new code:** add an `InpServerGMTOffset` input (or detect the offset from `TimeGMT()`), and state in the strategy page which real-world event the hour is
meant to hit.
