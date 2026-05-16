# Plainview Benchmark Comparison

- Generated: 2026-05-14T18:08:26.837Z
- Browser baseline: chromium
- Claim policy: marketing
- Claim gate: passed
- Environment: macOS 26.3, arm64, Mac14,2

## Summary

| Metric | Plainview Text-Only | Chromium Pair | Plainview Images | Chromium Pair |
| --- | ---: | ---: | ---: | ---: |
| Runs | 60 | 60 | 60 | 60 |
| Median load/render time | 557ms | 1.44s | 506ms | 1.44s |
| Median transfer bytes | 104.0 KB | 393.3 KB | 104.0 KB | 393.3 KB |
| Median requests | 1.0 | 18.0 | 1.0 | 18.0 |
| Median script bytes | 0 B | 37.4 KB | 0 B | 37.4 KB |
| Median resident memory after load | 126.79 MB | 345.12 MB | 118.17 MB | 345.12 MB |

## Evidence

- Required: 20+ URLs, 3+ iterations, 95%+ success rate
- Plainview text-only: 20 URL(s), 3 iteration(s), 60/60 successful (100%)
- Plainview images: 20 URL(s), 3 iteration(s), 60/60 successful (100%)
- Browser: 20 URL(s), 3 iteration(s), 60/60 successful (100%)
- Paired text-only comparison: 20 URL(s), 3 iteration(s), 60/60 successful (100%)
- Paired image comparison: 20 URL(s), 3 iteration(s), 60/60 successful (100%)
- Plainview/browser capture skew: 0.0 hours
- Corpus: 20 URL(s), SHA-256 19f73cf74d3b260f683a4c63f587fb88f11da2c547f73f017b70c09a4cc5bcb7

## Environment

- Host: macOS 26.3, arm64, Mac14,2
- CPU: Apple M2 (8 logical cores)
- Memory: 8589.93 MB
- Node: v25.6.1
- Swift: Apple Swift version 6.3.2 (swiftlang-6.3.2.1.108 clang-2100.1.1.101)
- Browser: chromium 148.0.7778.96
- Active network interfaces: en0
- Power: Now drawing from 'AC Power'

## Claim Readiness

Approved:
- Across paired successful runs in this benchmark set, Plainview text-only downloaded 74% fewer bytes than the 60-run Chromium baseline median.
- Across paired successful runs in this benchmark set, Plainview text-only made 94% fewer requests than the Chromium baseline median.
- Across paired successful runs in this benchmark set, Plainview text-only reached a rendered native document 61% sooner than Chromium full page load.
- Across paired successful runs in this benchmark set, Plainview text-only used 63% less resident memory than Chromium after load.
- Across paired successful runs in this benchmark set, Plainview with images downloaded 74% fewer bytes than the Chromium baseline median.
- Across paired successful runs in this benchmark set, Plainview with images reached a rendered native document 65% sooner than Chromium full page load.
- Across paired successful runs in this benchmark set, Plainview with images used 66% less resident memory than Chromium after load.
- Plainview executed 0 page JavaScript by design.

Avoid broad unqualified claims such as "green," "eco-friendly," or "always faster." Use only claims approved by the gate, and cite benchmark URL set, date, machine, network, browser, and median values.
