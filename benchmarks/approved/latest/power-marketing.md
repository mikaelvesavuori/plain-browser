# Plainview Power Measurement

- Generated: 2026-05-14T12:58:42.593Z
- Claim gate: passed
- Tool: powermetrics
- Caveat: powermetrics average power values are estimated and may be inaccurate; use them to help optimize app energy efficiency, not for broad cross-device comparisons.

## Summary

| Metric | Plainview | Chromium | Reduction |
| --- | ---: | ---: | ---: |
| Idle-adjusted estimated SoC energy | 49.38 J | 76.56 J | 36% |
| Gross estimated SoC energy | 60.67 J | 107.67 J | 44% |
| Average estimated SoC power | 1.43 W | 920 mW | - |
| Duration | 42.45s | 116.98s | - |
| Samples | 42 | 116 | - |

## Evidence

- Corpus: 20 URL(s), 3 iteration(s), SHA-256 5476da60afa9c0b6d2a1b8d7a18ae324ddd41a4bd836941131c5c81f250f4668
- Idle baseline: 15 samples, 266 mW
- Browser: chromium 148.0.7778.96
- Host: macOS 26.3, arm64, Mac14,2
- Power: Now drawing from 'AC Power'

## Claim Readiness

Approved:
- In this measured local run, Plainview used 36% less idle-adjusted estimated SoC energy than the Chromium baseline.

Do not convert this into an unqualified "green" or "eco-friendly" claim. Use only the qualified estimated-energy language above.
