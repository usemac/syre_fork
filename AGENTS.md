# AGENTS.md

SyR-e — MATLAB/Octave motor design app (Apache 2.0). No tests, no build, no formatter. Requires FEMM 4.2.

## Upstream vs local overlay

This is a **fork** tracking `SyR-e/syre_public`. Two zones:

| Zone | Paths | What goes here |
|------|-------|----------------|
| Upstream (PR candidates) | `mfiles/`, `syreDrive/`, `syreExport/`, `syreCustomFeatures/`, `motorExamples/`, `materialLibrary/`, `koil/`, `Readme/` (excl. `markdowns/`), `GUI_Syre*.mlapp`, `setupPath.m` | Bug fixes and new features for upstream |
| Local overlay (never PR'd) | `usedev/`, `AGENTS.md`, `CLAUDE.md`, `.claude/`, `Readme/markdowns/`, `tmp/`, `results/` | Personal scripts, experiments, config |

**Rules:**
- New scripts/helpers → `usedev/`
- Bug fix in upstream code → edit the original file in place
- Never mix local and upstream code in same commit/branch
- `.git/info/exclude` already lists the local overlay paths

## Starting a session

```matlab
setupPath          % adds paths, creates results/ tmp/ syreDrive/PLECSModel/SimMatFiles/ in cd
GUI_Syre           % main app
GUI_Syre_MMM       % flux-map post-processing + drive sim
checkRelease()     % verify environment meets requirements
```

`setupPath` hardcodes `C:\femm42\mfiles` (Windows only). `results/` and `tmp/` are created **in `cd`**, not the repo root — re-run after `cd`.

## No-GUI entry points (manual §7)

| Function | Purpose |
|----------|---------|
| `OpenSaveOCT` | edit `dataSet` fields in a saved motor `.mat` |
| `OptimizeOCT` | run MODE optimization |
| `SimulateOCT` | run FEA evaluations |
| `eval_fluxMap` / `eval_operatingPoint` | single (id,iq) point / flux map |
| `MMM_load` | build `motorModel` struct from a `.mat` |
| `MMM_eval_*` | control trajectories, inverse model, efficiency map, etc. |
| `eval_xbDesignPlane(dataSet,1)` | (x,b) design plane (debug=1 skips dialog) |

## `usedev/` local scripts

| Script | Purpose |
|--------|---------|
| `define_machine.m` | edit elemental params in `M` struct, saves motor `.mat` |
| `cli_run_xb.m` | analytical-only (x,b) plane (fast, no FEMM) |
| `cli_run_xb_feafix.m` | same plane with FEAfix FEMM correction (slow) |

## Core architecture — three structs

- **`dataSet`** — flat persistence struct, field names mirror GUI labels.
- **`geo`** / **`per`** / **`mat`** — geometry, performance, material. Produced from `dataSet` by `data0(dataSet)`.
- **`dataSet → data0 → (geo, per, mat) → draw_motor_in_FEMM → simulate_xdeg → SOL`** is the canonical FEA pipeline.
- Inverse: `build_dataSet(geo, per)` for legacy loading.
- `back_compatibility.m` migrates old saved structs — always check it when changing field names.
- `motorModel` is an extra struct in `.mat` files (MMM output). **Only persisted when Save is used from MMM GUI** — `GUI_Syre` does not write it.

## Gotchas

- **RQ is positional.** The design vector `RQ` maps via `geo.RQnames`; changing the set of optimizable params requires synced edits in `data0` (bounds), `interpretRQ` (assignment), and any `*fitness.m`.
- **matlab -batch / -r may hang** on this Windows install (invisible license dialog). Workaround: run from MATLAB IDE Command Window. See `usedev/README.md` §4.3.
- **Don't drop `.m` files at repo root.** Root is reserved for GUIs, `setupPath.m`, license, readme.
- **FEMMfitness** creates a temp dir per evaluation — don't assume working directory in fitness functions.
- **koil/koil_syre.exe** is Windows-only (bundled DLLs) — will fail on Linux/macOS.
- **Manual:** `Readme/markdowns/syreManual/syreManual.md` (preferred over `.pdf` for grepping).
