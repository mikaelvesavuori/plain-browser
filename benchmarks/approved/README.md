# Approved Benchmark Evidence

This directory contains tracked evidence artifacts that passed Plain's marketing claim gate, including optional memory-use claims when the approved comparison contains resident-memory samples.

- `latest/` is the current approved evidence set used by `README.md`.
- Date-stamped directories preserve the approved evidence at the time it was published.

Regenerate and publish approved evidence with:

```sh
make bench-marketing
```

Power evidence is measured separately because `powermetrics` requires superuser privileges:

```sh
sudo make bench-power-measure
make bench-power-postprocess
```

The publishing steps refuse to write approved artifacts unless the relevant marketing gate passes.
