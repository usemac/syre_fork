# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

SyR-e (Synchronous Reluctance — evolution) is a MATLAB/Octave application for the design, FEA evaluation, optimization, and post-processing of synchronous machines (SyR, PM-SyR, IPM, SPM, EESM, multi-three-phase). It is not a library — there are no unit tests or build steps. Work is driven from two MATLAB App Designer GUIs and a set of `.m` functions invoked from them.

License: Apache 2.0. Active development on MATLAB R2025b. **Minimum MATLAB R2021b** (older is not supported because of AppDesigner). Octave is supported via the UPM (Politecnico de Madrid) build only — `.mlapp` GUIs do not run on Octave, so Octave use is script-based.

Run `checkRelease()` to verify the local environment satisfies the documented requirements.

Suggested toolboxes (per the manual):
- Simulink + Simscape Electrical — needed for `syreDrive` dynamic simulation;
- Parallel Computing Toolbox — FEA parallelism (used by default for AC-loss and several MMM routines);
- PDE Toolbox — structural analysis and mass computation;
- Curve Fitting Toolbox — control-trajectory fitting in MMM;
- Statistics and Machine Learning Toolbox — surrogate-model dataset generation.

## Repo layout: upstream vs local overlay — read this first

This repo is a **fork** of upstream SyR-e (`origin = usemac/syre_fork`, tracking `SyR-e/syre_public`). The user wants to keep upstream-bound work cleanly separable from personal development. Two zones:

**Upstream zone** (pristine — never modify lightly; changes here are PR candidates):
- `mfiles/`, `syreDrive/`, `syreExport/`, `syreCustomFeatures/`, `motorExamples/`, `materialLibrary/`, `koil/`, `Readme/` (except `Readme/markdowns/`)
- `GUI_Syre.mlapp`, `GUI_Syre_MMM.mlapp`, `setupPath.m`, `license.txt`, `README.md`

**Local overlay** (this user's, never PR'd to upstream):
- `usedev/` — script-based workflow (`define_machine.m`, `cli_run_xb.m`, `cli_run_xb_feafix.m`, `README.md`). This is where new user-facing scripts go.
- `CLAUDE.md` (this file) and `.claude/` — Claude Code config + state.
- `Readme/markdowns/` — locally-rendered manual (regenerable).
- `tmp/`, `results/` — runtime output.

**Operating rules for Claude:**
1. **New user-facing scripts, helpers, examples → put them under `usedev/`**. Never drop new `.m` files at the repo root or inside upstream folders unless the user explicitly asks for an upstream contribution.
2. **Bug fix in upstream code → edit the original file in place** (`mfiles/foo.m`, etc.). The user will branch off `main` to ship it as a PR. Do not move the fix into `usedev/` to "stay safe" — that defeats the PR.
3. **`usedev/` scripts are upstream consumers**: they may `addpath(repoDir)` and call any upstream function, but they do not write to upstream paths. If you find yourself wanting to modify upstream code from a `usedev/` script, that's a sign the change should be a separate upstream PR.
4. The user's local `.git/info/exclude` includes `usedev/`, `CLAUDE.md`, `.claude/`, `Readme/markdowns/`, `tmp/`, `results/` so they can't accidentally leak into a PR branch — verify with `git status` before committing on any branch named `fix/*` or `feat/*`.

For full development-model details (recommended branch layout, PR checklist), see `usedev/README.md` §0.

## Running it

There is no build/test harness. Typical session, from a MATLAB prompt opened in the repo root:

```matlab
setupPath          % adds all required paths and creates results/, tmp/, syreDrive/PLECSModel/SimMatFiles/
GUI_Syre           % main app: geometry, FEA, optimization
GUI_Syre_MMM       % "Magnetic Model Manipulation": flux-map post-processing + drive sim prep
```

`setupPath.m` hardcodes `C:\femm42\mfiles` on Windows. On non-Windows systems it warns that FEMM is unavailable — most workflows then break unless `XFEMM` is used. FEMM 4.2 (April 2019 build or later) is a required external dependency for the magnetic FEA backend (older than 25 Feb 2018 cannot be used at all).

The supported "no-GUI" entry points are documented in chapter 7 of the manual. The relevant ones, in workflow order:

| Stage | Function | Purpose |
|-------|----------|---------|
| Setup | `setupPath` | add SyR-e + FEMM + custom-feature paths |
| Edit motor | `OpenSaveOCT` | load a .mat motor, edit dataSet fields, save back |
| Optimize | `OptimizeOCT` | run a MODE optimization (also valid for MATLAB) |
| FEA | `SimulateOCT` | run any of the FEA evaluation types |
| FEA | `eval_operatingPoint` | single (id,iq) point |
| FEA | `eval_fluxMap` | (id,iq) flux map |
| MMM | `MMM_load` | build the `motorModel` struct from a .mat |
| MMM | `MMM_eval_AOA` | control trajectories (MTPA / MTPV) |
| MMM | `MMM_scale`, `MMM_skew` | scale / skew the model |
| MMM | `MMM_eval_inverseModel_dq` | inverse flux maps for drive sim |
| MMM | `MMM_eval_OpLim` | operating limits |
| MMM | `MMM_MaxTw` | efficiency map |
| MMM | `MMM_eval_shortCircuitTransient` | ASC transient |

For the (x,b) preliminary design plane, `eval_xbDesignPlane(dataSet, debug)` with `debug=1` is the headless entry point (skips the "Open in design plane explorer?" dialog). Setting `dataSet.FEAfixN = 0` keeps it analytical-only (no FEMM); a non-zero value (1, 4, 5, 8, 16) requests that many FEA correction points.

## Architecture: the three structs

Almost every function operates on some combination of these:

- **`dataSet`** — flat struct produced by the GUI. The persistence format. Saved inside each motor's `.mat` file. Field names mirror GUI control labels (e.g. `dataSet.NumOfPolePairs`, `dataSet.RatedCurrent`, `dataSet.HCpu`).
- **`geo`** — geometry struct used by the drawing/FEA engine (e.g. `geo.p`, `geo.RotType`, `geo.win.avv`, `geo.RQnames`).
- **`per`** — performance/operating-point struct (`per.Loss`, `per.gamma`, `per.tempcu`, ...).
- **`mat`** — material assignments (iron, conductor, layer/PM, sleeve), populated by `assign_mat_prop`.

Direction of flow:

- `data0(dataSet)` translates `dataSet` → `(bounds, objs, geo, per, mat)`. This is the canonical entry point from GUI-land into engine-land.
- `build_dataSet(geo, per)` is the inverse, used for back-compatibility loading of legacy projects.
- `back_compatibility.m` migrates older saved structs to current field names and is called whenever a motor is loaded.

## Architecture: motor file format

A motor is two paired files sharing a basename:

- `name.fem` — FEMM model (regenerable).
- `name.mat` — saved `dataSet` plus, for projects already touched by MMM, a `motorModel` struct with flux maps, MTPA, inductance maps, etc.

The `.mat` is the source of truth for SyR-e; the `.fem` is rebuilt by `draw_motor_in_FEMM` whenever needed. **Important caveat from the manual:** `motorModel` is only persisted when *Save* is invoked from the MMM GUI; the main `GUI_Syre` does not write the `motorModel` field, so a motor edited there will lose unsaved MMM data.

Examples in `motorExamples/`:
- **`syreDefaultMotor`** — the current default; an IPM motor based on the Tesla Model 3 traction motor (this is what `GUI_Syre` loads on launch);
- `mot_01` — SyR motor; the previous default;
- `RAWP` — SyR motor designed from an induction-motor stator;
- `THOR` — PM-SyR with custom geometry (legacy parametrization);
- `TeslaModel3` — V-type IPM, custom geometry;
- `PEIC_PM_V12` — V-type IPM with asymmetric 12-phase winding.

Additional examples are listed on Zenodo and accessible from the *Utilities* tab of `GUI_Syre`.

## Architecture: the FEA pipeline

Single core path used by both single-machine evaluation and the optimizer:

```
dataSet → data0 → (geo, per, mat)
       → DrawAndSaveMachine → draw_motor_in_FEMM (writes .fem)
       → simulate_xdeg (runs FEMM at gamma sweep / rotor positions)
       → SOL struct (id, iq, fluxes, torque, losses, ...)
       → eval_fluxMap / eval_operatingPoint / etc.
```

`build_matrix_<RotType>.m` per rotor type (`Circ`, `Seg`, `ISeg`, `SPM`, `SPM_Halbach`, `Spoke`, `Vtype`, `Vtype_v2`, `Vtype_v3`, `Fluid`, `EESM`) is what specializes the geometry construction. When adding or modifying a rotor topology, this is the file to start from, paired with the matching `PMdefinition_*.m` and `calc_ribs_rad_*.m` helpers.

**Rotor type status (per the manual):**
- Active: `Circular`, `Seg`, `Fluid`, `SPM`, `IM`, `EESM` (EESM is still under development — single-point sims only at present);
- Deprecated: `ISeg` and `Vtype` — new V-type designs should use `Seg` with `CentralShrink = ones(1, nlay)` (see the `TeslaModel3` and `syreDefaultMotor` examples).

**Axis convention** is a property of the rotor type:
- `SR` axis (PM flux along −q): `Circular`, `Seg`, `ISeg`, `Fluid`, `EESM`;
- `PM` axis (PM flux along +d): `SPM`, `Vtype`, `Spoke-type`.

This affects which quadrant means what in flux maps:
- SyR-axis types: 1Q is `id>0, iq>0`; 2Q is `id>0`; 4Q is full plane;
- PM-axis types: 1Q is `id<0, iq>0`; 2Q is `iq>0`; 4Q is full plane.

The convention is overridable from the GUI's *Simulation* tab (`dataSet.axisType`).

**Result folder naming** (under the working directory's `results/`):
- `T_eval_<I>A<gamma>_<temp>deg` — single operating point;
- `senseOut_<yyyymmddTHHMMSS>` — sensitivity over current vector;
- `F_map_<Imax>A<n>x<n>_<temp>deg_<n>Q` — flux map;
- any of the above with `_ironLoss` suffix when iron-loss evaluation is enabled.

## Architecture: optimization

`mfiles/MODE/` is a Multi-Objective Differential Evolution implementation (`mode_optim`, `jMODE`, `MODE2`, plus Pareto helpers). The objective function it calls is **`FEMMfitness(RQ, geo, per, mat, eval_type, filenameIn)`**.

The design vector `RQ` is mapped to `geo` fields via the names listed in `geo.RQnames`; `interpretRQ.m` does the assignment. Bounds and objective list come from `data0`. Anyone changing what is optimizable touches `data0`, `interpretRQ`, and `geo.RQnames`.

`FEMMfitness` always runs in a per-evaluation temp directory created by `createTempDir`. Don't assume the working directory in functions called from inside fitness.

**Penalization-limit sign convention** (per the manual): negative values mean *maximize* the objective (e.g., torque enters as `-MaxTorque`), positive values mean *minimize* it (e.g., torque ripple, copper mass). Mode `Design` explores the search space; mode `Refine` perturbs around the current motor.

**Mesh control** uses two parameters: `Mesh` (post-processing, manual design) and `Mesh_MOOA` (during optimization). The airgap mesh resolution is computed differently between the two phases — see the table in §3.6 of the manual.

## Architecture: (x,b) preliminary design

`eval_xbDesignPlane` produces a 2-D map of motor performance (torque, PF, characteristic current, demag, mech stress, ...) over `x = r/R` (rotor/stator split) and `b` (per-unit magnetic loading). The pure-analytical version (`xbPlane_analyticalDesign`) follows Vagati's closed-form SyRM equations; **FEAfix** (`FEAfixN ∈ {1, 4, 5, 8, 16}`) corrects the analytical map with that many FEMM evaluations and stores per-cell scaling factors `kd, kq, km, k0, kg, ...` that are multiplied into the analytical results. The plane was extended over time from SyR to PM-SyR/IPM/SPM — different rotor types apply different post-correction formulas in `eval_xbDesignPlane.m`.

`syrmDesignExplorer` (in `syreCustomFeatures/`) is the interactive picker for navigating the resulting map; the headless equivalent is to inspect the saved `map` struct directly.

## Architecture: MMM (post-processing & drive prep)

`mfiles/syreMMM/` is a parallel pipeline focused on flux-map manipulation, control-trajectory derivation (MTPA, MTPV, AOA), thermal/efficiency maps, and short-circuit/demag analysis. It operates on a `motorModel` struct (loaded by `MMM_load`) rather than on `geo/per/mat` directly, although it can call back into the FEMM pipeline to compute new maps. **MMM does not run FEA itself** — it only loads pre-computed simulation results.

`motorModel` substructures (each may be empty if not yet computed):
`data` (ratings), `FluxMap_dq` / `FluxMap_dqt`, `FluxMapInv_dq` / `FluxMapInv_dqt`, `IronPMLossMap_dq`, `acLossFactor`, `DemagnetizatioLimit`, `controlTrajectories` (MTPA/MTPV/AOA), `IncInductanceMap_dq`, `AppInductanceMap_dq`, `TnSetup` (operating limits + efficiency map setup), `SyreDrive` (drive-export setup), `WaveformSetup`, `tmpScale` / `tmpSkew` (scratch for in-progress scaling/skewing), `Thermal`, `PMtempModels` (cached flux/loss maps at additional PM temperatures).

The PM temperature selector in the GUI swaps the active map in/out from `PMtempModels` — useful for sensitivity studies without recomputing.

MMM also generates the artifacts consumed by `syreDrive/`:
- `MMM_createSimulinkModel` and `MMM_createPLECSmodel` build the runtime testbench.
- `MMM_print_MotorDataH` writes `MotorData.h`, the auto-generated C header that the firmware-style code in `syreDrive/*/User_functions/` includes.

## Architecture: external simulation exporters

`syreExport/` contains one subdirectory per third-party tool, each mirroring the same surface as the FEMM path:

| Tool | Export driver | Operating point | Sweep |
|------|---------------|-----------------|-------|
| Ansys Maxwell | `draw_motor_in_ansys` | `eval_operatingPointAM` | `simulate_xdeg_AM` |
| COMSOL | `draw_motor_in_COMSOL` | `eval_operatingPointCOMSOL` | `simulate_xdeg_COMSOL` |
| JMAG | `draw_motor_in_JMAG` | `eval_operatingPointJMAG` | `simulate_xdeg_JMAG` |
| MagNet | `draw_motor_in_MN` | `eval_operatingPointMN` | `simulate_xdeg_MN` |
| Motor-CAD | `draw_motor_in_MCAD` | `eval_operatingPointMCAD` | `simulate_xdegMCAD` |
| DXF | `syreToDxf` (geometry only) | — | — |

Plus `*fitness.m` in each (e.g. `MCADfitness`, `JMAGfitness`) — these are drop-in replacements for `FEMMfitness` when optimizing through the corresponding solver.

## Architecture: syreDrive

`syreDrive/` is a separate output domain: it generates motor-control firmware-style C code plus a Simulink/PLECS testbench around it.

- Variants: `AVGModel/`, `INSTModel/`, `MultiThreePhase/`, `PLECSModel/`. Each contains its own `Motor_ctrl*.slx` (or `.plecs`) and an `init_sim*.m` that loads `motorModel.mat` from the working directory and pre-computes initial conditions.
- The User_functions layout (`Inc/`, `Src/`) inside each variant is a fixed convention that the auto-generation in MMM writes into; treat the headers `MotorData.h`, `User_Variables.h`, etc. as code generation outputs.
- `PLECSModel/matlab-jsonrpc-main/` is a vendored helper for talking to PLECS over JSON-RPC.

## Custom features and add-ons

`syreCustomFeatures/` is auto-discovered by `setupPath`: any subdirectory is added recursively to the path, and its name is printed when `setupPath(1)` is called. Notable ones:

- `syrmDesignExplorer/` — interactive (x,b) design plane explorer.
- `sleeveDesigner/` — SPM rotor sleeve sizing.
- `xfemm/` — alternative cross-platform FEMM build.
- `auto_SyR-e/`, `postProcessing/`, `plotMotorGeometry/`, `NormalizedPMSMplane/`, `ThermalUniPD_GalFerContest/` — independent tooling, not part of the core workflow.

These are the right place to add new analyses *that should ship upstream*. For local-only / experimental analyses, prefer `usedev/` instead — see the upstream-vs-local overlay rules near the top of this file.

## Local overlay: `usedev/`

`usedev/` is the user's personal scratch space for script-based workflows. It is **never** PR'd upstream. Current contents:

- `define_machine.m` — defines a `M` struct of elemental machine parameters (~30 fields), loads `motorExamples/syreDefaultMotor.mat` as a baseline, applies overrides, optionally saves a new motor `.mat`. The reference for which `dataSet` fields are "elemental design choices" vs "toolchain configuration".
- `cli_run_xb.m` — Part 1: analytical-only (x,b) plane (`FEAfixN=0`, no FEMM). Fast sanity check.
- `cli_run_xb_feafix.m` — Part 2: same plane with FEAfix correction (calls FEMM, slow).
- `README.md` — full user-facing docs: how to edit `M`, run the workflow, run from CLI (`matlab -batch`), the development model, and the upstream-PR checklist.

When the user asks for a new workflow script, runner, helper, or example, **add it under `usedev/`** unless they explicitly say it's for upstream. The runners compute the repo root as the parent of `usedev/` and call `setupPath` automatically.

## Octave compatibility

`mfiles/OctaveFunctions/` (`MODEstart`, `OptimizeOCT`, `SimulateOCT`, `OpenSaveOCT`) provides the shims that the GUI code calls when running on Octave. App-Designer `.mlapp` files do not run on Octave — Octave use is script-based via these wrappers, which is also the documented "without GUI" workflow for advanced MATLAB users (manual §7). The UPM Octave distribution is the tested target.

## Things that bite

- `setupPath` must be re-run after switching working directory: it creates `results/`, `tmp/`, and `syreDrive/PLECSModel/SimMatFiles/` *in `cd`*, not in the repo root.
- Material library: `materialLibrary/{iron,layer,conductor,sleeve}_material.mat` are the shipped libraries; `custom_*.mat` siblings are auto-created empty by `setupPath` for user additions. Don't edit the shipped ones in place — the material library functions in `mfiles/MaterialLibraryFunctions/` add to the custom files.
- `koil/koil_syre.exe` is a Windows-only compiled winding-factor tool; the bundled DLLs (`libgcc_s_dw2-1.dll`, `libstdc++-6.dll`) must stay alongside it. Functionality that calls `koil` will fail on Linux/macOS unless the user has built an equivalent.
- When editing rotor-topology code, always check whether `back_compatibility.m` needs an entry so older saved `.mat` projects continue to load.
- The `RQ` design vector is *positional* — its meaning comes from `geo.RQnames`. Reordering or extending it requires synchronized updates in `data0` (bounds), `interpretRQ` (assignment), and any custom `*fitness.m` files.
- **Don't drop new `.m` files at the repo root.** Either `usedev/` (local development) or under the appropriate upstream folder (`mfiles/`, `syreCustomFeatures/`, `syreExport/<tool>/`) — the root is reserved for the GUIs, `setupPath`, and license/readme files.
- `matlab -batch` and `matlab -r` may hang at startup on this Windows install due to a license-checkout dialog rendered invisibly when launched non-interactively (~0.3 s CPU then nothing). When this happens, the workaround is to run from inside an already-open MATLAB IDE Command Window. See `usedev/README.md` §4.3 for diagnostics.

## Documentation pointers

The authoritative manual is `Readme/syreManual.pdf`, with a markdown rendering at `Readme/markdowns/syreManual/syreManual.md` (preferred for grepping). Topic-specific design notes are in `Readme/Documentation/` (mostly `.pptx`/`.docx`, dated). The GitHub Wiki of the upstream `syre_public` repository is referenced by the README for installation/first-run instructions. SyR-e was started in 2009 (Politecnico di Bari) and is currently maintained by PEIC at Politecnico di Torino.
