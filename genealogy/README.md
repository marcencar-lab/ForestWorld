# Genealogy research: the Muñasque family of Opon (Lapu-Lapu City), Cebu

Reconstruction of the descendants of **Fernando Umpad Muñasque** from the family spreadsheet
`FERNANDO VALIENTE MUÑASQUE.xlsx`, with independent web research. Report date: 28 October 2026.

Start with **`REPORT.md`** (full written report: summary, method, lineage, profiles, evidence
matrix, discrepancies, next steps, bibliography). The same content with an interactive tree
explorer is in `report_page.html` (open in a browser; the explorer needs internet access to load
the D3 library).

## What is here

| Path | Content |
|---|---|
| `REPORT.md` | The research report. |
| `report_page.html` | Same report as a web page with an interactive, searchable family-tree explorer and all charts. |
| `registers/people.csv` | 1,788 people: ID, names, generation, parents, spouses, children, residence, variants, notes, confidence. |
| `registers/relationships.csv` | Every parent-child and spouse link with the spreadsheet cell it came from, the naming-convention check and a confidence label. |
| `registers/sources.csv` | Bibliography (S1–S43) with record type and URL. |
| `registers/research_facts.csv` | Facts found outside the spreadsheet, linked to people and sources. |
| `registers/discrepancies.csv` | Curated conflict log plus automatic row-level flags. |
| `registers/overrides.csv`, `registers/variant_map.csv` | Every editorial decision that moved a person or merged a spelling variant, with the reason. |
| `valiente_munasque.ged` | GEDCOM 5.5.1 export for genealogy programs (see limits in REPORT.md §12). |
| `data.json` | The whole tree as structured data. |
| `charts/` | Editable SVG charts: pedigree, overview, nine branch charts, map, timeline, evidence diagram, generation sizes. |
| `sources/` | Copy of the supplied spreadsheet and a plain-text dump of every cell. |
| `research/` | The four web-research reports (every query tried, every URL found). |
| `scripts/` | The parser and generators. Re-run them if the spreadsheet is corrected. |
| `research_log.md` | Questions, searches, findings and next steps in date order. |

## Regenerating

```
python3 scripts/parse_tree.py "sources/FERNANDO VALIENTE MUÑASQUE.xlsx" out
python3 scripts/finalize.py out
python3 scripts/charts.py out
python3 scripts/build_site.py out
```
Needs Python 3 with `openpyxl`. `overrides.csv` and `variant_map.csv` must sit next to the scripts.

## Privacy

Most people in generations 5–10 are living. Nothing beyond the family's own spreadsheet and
published facts about public figures was recorded. Keep the report page private to the family.
