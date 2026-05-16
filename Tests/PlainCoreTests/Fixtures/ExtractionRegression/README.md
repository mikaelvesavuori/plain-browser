# Extraction Regression Fixtures

This directory collects small, deterministic HTML fixtures for pages Plain has struggled with or should keep handling well.

Each fixture should represent one real failure mode, not a full saved website. Keep enough structure to reproduce the extractor behavior and remove unrelated page noise.

Good fixture candidates:

- malformed or generic article markup
- search result pages Plain rewrites
- link-index pages where the useful content is a list, not an article
- marketing pages with decorative media shells
- decorative background/texture imagery that should not render as article images
- inline formatting/link spacing issues
- lazy images, `srcset`, figures, and captions
- navigation-heavy shells where the readable body is easy to miss

Add expectations in `ExtractionRegressionTests.swift` when adding a fixture.
