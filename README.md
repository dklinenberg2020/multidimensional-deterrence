# Multidimensional Deterrence

Research repository for extending empirical deterrence response curves to multiple damage dimensions and conflict actors.

- [Theory manuscript and Northern Ireland application](Multidimensional_Deterrence_Theory_Northern_Ireland.md)
- [Research log and country assessments](research/research-log.md)
- [Conflict data inventory and limitations](research/conflict-data-review.md)
- [Incident data dictionary](research/data-dictionary.md)
- [Acquired source inventory and SHA-256 checksums](research/sources.csv)
- [Source and incident audits](research/audits/)
- [Tasks requiring collaborator involvement](research/collaborator-tasks.md)

## Reproduce the historical incident extracts

Run from the repository root with Python 3.12 and curl.

```sh
python -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements.txt
python scripts/acquire.py ../deterrence-source-files
python scripts/standardize.py ../deterrence-source-files ../deterrence-incidents
```

Use `--verify-only` with the acquisition script to check an existing source directory. Both scripts accept repeated `--country` flags. Some publishers serve changing files from the same address. The acquisition script verifies the pinned SHA-256 checksums and rejects a changed snapshot.

The `data/` directory includes the redistributable Iraq and Yemen extracts. The provenance manifest links to the publisher files. Colombia and Vietnam extracts can be rebuilt from the acquired snapshots. These are historical incident records for assessing coverage and measurement before any move–countermove coding.

### Tidy Vietnam and Colombia tables

After running the acquisition and standardization steps, run:

```sh
python scripts/tidy.py ../deterrence-source-files ../deterrence-incidents ../deterrence-tidy
```

This creates one incident table per country, a separate linked Colombia victim table and a build audit. The [tidy table dictionary](research/tidy-data.md) documents identifiers, date precision and missing values.
