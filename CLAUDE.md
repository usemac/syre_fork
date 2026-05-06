# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

SyR-e (Synchronous Reluctance – evolution) is a MATLAB/Octave tool for designing, simulating, and optimizing electric machines (SyR, PM-SyR, IPM, SPM, IM, EESM, multi-three-phase). It drives the FEMM finite-element solver under the hood and offers two GUIs: machine design + a downstream MMM (Magnetic Model Manipulation) toolkit for post-processing flux maps, control trajectories, op-limit / efficiency maps, and Simulink/PLECS drive-model export.

The canonical upstream layout (SyR-e/syre_public on GitHub) keeps everything at the repository root: `mfiles/`, `syreDrive/`, `syreExport/`, `syreCustomFeatures/`, `motorExamples/`, `materialLibrary/`, `syreManual/`, `koil/`, plus the two `.mlapp` GUIs and `setupPath.m`. The `Readme/` folder of tutorials and PDFs is also tracked at root.

## Running it

There is no build step, no lint, and no automated test suite. SyR-e is launched interactively from MATLAB or Octave (UPM distribution).

1. From MATLAB started in `core/`, run `setupPath` once per session — it registers all subdirectories on the path, auto-discovers `syreCustomFeatures/*`, and creates `results/`, `tmp/`, and `syreDrive/PLECSModel/SimMatFiles/` if missing.
2. Then open one of the two app GUIs:
   - `GUI_Syre` — main design / FEA / optimization GUI.
   - `GUI_Syre_MMM` — magnetic-model manipulation GUI (post-design analysis).
3. Headless equivalents for scripting / Octave (no GUI): `OpenSaveOCT`, `OptimizeOCT`, `SimulateOCT`, plus direct calls to `eval_operatingPoint`, `eval_fluxMap`, `MMM_load`, `MMM_eval_AOA`, `MMM_scale`, `MMM_skew`, `MMM_eval_inverseModel_dq`, `MMM_eval_shortCircuitTransient`, `MMM_eval_OpLim`, `MMM_MaxTw`. Always load via these entry points so `back_compatibility.m` runs.

Run `checkReleases()` to validate the environment.

### Requirements

- **MATLAB ≥ 2021b** (AppDesigner compatibility — the README's 2016b note is outdated; the manual is authoritative). Current dev target is 2025b.
- **FEMM 4.2 (Apr 21 2019 or later)** installed at `C:\femm42` on Windows — mandatory for FEA. `setupPath.m` hardcodes `addpath('C:\femm42\mfiles')` for `ispc` and only warns on non-Windows. From v26.1, `syreCustomFeatures/xfemm` provides partial XFEMM support (simulation of an existing `.fem` only — no model creation).
- **Toolboxes** for the corresponding features: Simulink + Simscape + Simscape Electrical (`syreDrive`); Parallel Computing Toolbox (parallel FEA); PDE Toolbox (`StructuralPDE` + mass); Curve Fitting Toolbox; Statistics and Machine Learning Toolbox (surrogate-model datasets).

## Architecture in one breath

A motor on disk is **two files that travel together**: `<name>.mat` (geometry, ratings, materials, results) and `<name>.fem` (FEMM model). Don't move one without the other.

There are two conceptual halves of the codebase that share files but pivot on different data structures:

**Design / FEA half** (main GUI, `mfiles/`) — five plain structs passed around by every function:

- `dataSet` — flat struct populated by the GUI (or manually by `manual_dataSet.m`). The on-disk save format.
- `geo` — geometry (radii, slots, barriers, winding, mesh, material assignments).
- `per` — performance / simulation targets (currents, losses, temperatures, optimization goals/penalties).
- `mat` — material properties resolved from the material library.
- `out` / `SOL` — simulation results from FEMM.

The pivot function `data0(dataIn)` translates a `dataSet` into `(bounds, objs, geo, per, mat)`. `build_dataSet(geo, per)` is the inverse, used when loading legacy projects. `back_compatibility.m` runs on load to migrate old files forward — when adding new fields to `dataSet`/`geo`/`per`, also add the migration there or old motor files break.

**MMM half** (`GUI_Syre_MMM`, `mfiles/syreMMM/`) — pivots on a single struct **`motorModel`**, written into the same `.mat` file but **only by the MMM GUI** (the main GUI does not save it). Substructures, any of which may be empty: `data` (ratings), `FluxMap_dq`, `FluxMap_dqt`, `IronPMLossMap_dq`, `acLossFactor`, `DemagnetizatioLimit` (note the typo — it's the field name on disk), `controlTrajectories` (MTPA / MTPV), `IncInductanceMap_dq`, `AppInductanceMap_dq`, `FluxMapInv_dq`, `FluxMapInv_dqt`, `TnSetup`, `SyreDrive`, `WaveformSetup`, `tmpScale`, `tmpSkew`, `Thermal`, `PMtempModels` (alternate-temperature flux/loss maps; one primary temperature is hot-swapped into the top-level fields). `MMM_back_compatibility.m` is the parallel migration hook for this struct.

### Simulation pipeline

`FEMMfitness(RQ, geo, per, mat, eval_type, filenameIn)` is the universal entry to a FEMM run:

1. `createTempDir()` — every simulation gets its own scratch folder under `tmp/`.
2. If `RQ` is non-empty (optimization mode), `interpretRQ(RQ, geo, mat)` decodes the optimizer's design vector into geometry, then `draw_motor_in_FEMM` writes the `.fem`. Otherwise, the existing `.fem` is copied in.
3. `simulate_xdeg(...)` (or `simulate_FOC_IM` for induction motors) steps through rotor positions, calls FEMM via `callfemm_parfor` / `mi_loadsolution_parfor`, and assembles `SOL`.
4. `eval_operatingPoint` / `evalParetoFront` / etc. reduce `SOL` to objectives.
5. Results are saved as `.mat` next to the `.fem` in the temp dir.

### Optimization

`mfiles/MODE/` holds a Multi-Objective Differential Evolution optimizer (jMODE.m). The MOOA loop calls `FEMMfitness` with `eval_type='MO_OA'` and an `RQ` vector; bounds and objectives come from `data0`. `restartOptimization.m` resumes interrupted runs. `evalParetoFront.m` post-processes Pareto fronts; `FastParetoEstimation` / `FEAfix` accelerate via analytical-then-corrected design.

Two operation conventions worth knowing:
- **Penalization-limit sign encodes direction**: a *negative* limit means the objective is maximized (e.g. minimize `-Tmax`); a *positive* limit means it is minimized (e.g. torque ripple).
- **`per.flag_OptCurrConst`** picks the current constraint: `0` = constant thermal loading (`per.kj` fixed, `Loss`/`J` set NaN), `1` = constant current density (`per.J` fixed), `2` = constant phase current. `FEMMfitness` and `calc_i0` branch on this — preserve the NaN sentinel pattern when adding new constraint modes.
- Optimization mode = `Design` (explore full bounds) vs `Refine` (perturb around current motor). Mesh during optimization uses `Mesh_MOOA` (coarser); post-processing uses `Mesh` (finer). See the table in §3.6 of `syreManual/syreManual.md` for exact airgap/general resolution formulas.

### Geometry generation per rotor type

Rotor geometry is split across pairs of files: `nodes_rotor_<Type>.m` (computes node coordinates) + `build_matrix_<Type>.m` (assembles the line/arc matrix that `draw_motor_in_FEMM` consumes). Variants: `Circ`, `Seg`, `ISeg`, `Fluid`, `SPM`, `SPM_Halbach`, `Spoke`, `Vtype` (and `_v2`, `_v3` revisions), `EESM`. When adding a rotor topology, both files plus a branch in `data0`/`build_dataSet`/`back_compatibility` are required.

**Deprecated rotor types**: `ISeg` and `Vtype` are explicitly "not recommended for new projects — use `Seg` with adjusted parameters (e.g. `CentralBarrierShrink=ones(1,nlay)` for a V-type)." They remain for back-compatibility only. Don't propose them for new geometries; the canonical V-type examples (`TeslaModel3_custom`, `syreDefaultMotor`) use `Seg`.

**Custom geometry** is a supported workflow: design the closest parametric equivalent in SyR-e to seed FEMM blocks/boundaries/winding, edit the `.fem` directly in FEMM, then click "Import from FEMM" in the main tab. Examples: `THOR`, `TeslaModel3_custom`. Don't expect parametric tools (FEAfix, optimization) to work after import.

### Axis-convention split

Two dq conventions coexist and rotor type drives the default:

- **SR convention** (PMs along −q axis): `Circular`, `Seg`, `ISeg`, `Fluid`. Flux-map quadrant 1Q means `id>0, iq>0`.
- **PM convention** (PMs along +d axis): `SPM`, `Vtype`. Flux-map quadrant 1Q means `id<0, iq>0`.

Convention is overridable per-simulation from the Simulation tab. When reading or writing flux-map post-processing, check which convention is active before assuming sign of `id`.

### Drive-model export (`syreDrive/`)

Four targets, each with its own `init_sim*.m` bootstrap that reads `motorModel.mat`:
- `AVGModel/` — Simulink, average inverter model, includes `inverter.mexw64`.
- `INSTModel/` — Simulink, instantaneous switching.
- `MultiThreePhase/` — multi-3φ machines; templates in `User_functions/` are concatenated by `Generate_MultiThreePhase_Simulink.m`.
- `PLECSModel/` — PLECS via JSON-RPC bridge in `matlab-jsonrpc-main/`; launched by `Launch_PLECS_Simulation.m`.

### FEA exporters (`syreExport/`)

Each subfolder mirrors `syreExport/<tool>/` and provides a `<tool>fitness.m` and `draw_motor_in_<tool>.m` analogous to the FEMM pair. Targets: `syre_AnsysMaxwell` (Python-driven via `.py` scripts), `syre_COMSOL`, `syre_Dxf`, `syre_JMAG`, `syre_MagNet`, `syre_MotorCAD`.

### MMM (`mfiles/syreMMM/`)

Downstream of FEMM: takes flux maps and produces inductance maps, MTPA/MTPV trajectories, op-limit curves, efficiency maps, demag maps, scaling/skewing, and Simulink/PLECS code generation. All entry points are prefixed `MMM_*`. Has its own `MMM_back_compatibility.m`.

### Custom features (`syreCustomFeatures/`)

Auto-loaded by `setupPath.m`: every subdirectory is `genpath`'d. This is the supported extension point — drop a self-contained folder here (e.g. `auto_SyR-e`, `syrmDesignExplorer`, `xfemm`, `postProcessing`) and it appears on the path next session. Don't reach into the core `mfiles/` to add features when a custom-feature folder will do.

### Material library (`materialLibrary/`)

Built-in `.mat` files: `iron_material.mat`, `layer_material.mat`, `conductor_material.mat`, `sleeve_material.mat`. `setupPath.m` also creates empty `custom_*.mat` companions for user additions. CRUD via `mfiles/MaterialLibraryFunctions/`.

## Conventions worth knowing

- Italian and English are mixed in identifiers and comments (e.g. `calc_distanza_punti`, `Disegna_Arco`, `racc_retteoblique`). Don't "fix" them; downstream code references the existing names.
- Filenames encode topology and revision (`build_matrix_Vtype_v3.m`). New revisions ship as `_v<N>` rather than rewriting the previous version, since old motor files dispatch by name via `geo.RotType`.
- Headers are Apache-2.0 boilerplate from 2014; preserve when editing.
- Path-syntax helpers (`checkPathSyntax.m`, `checkPathSyntax`) handle Windows/Unix separators — use them rather than building paths manually when interfacing with FEMM, which is path-sensitive.
- `tmp/` and `results/` are created on demand and are throwaway. Don't rely on their contents across sessions.
- `koil/koil_syre.exe` is an external winding-factor calculator invoked from `koil.m`; the DLLs next to it are its runtime — keep them together.
- Result-folder names encode the run: `T_eval_<I>A<ang>_<temp>deg` for single point, `senseOut_<timestamp>` for swept single-point, `F_map_<I>A<n>x<n>A<n>_<temp>deg_<n>Q` for flux maps, with `_ironLoss` suffix for iron-loss runs. Match this when writing scripts that consume results.

## Reference

The full user manual is checked in at `syreManual/syreManual.md` (with `syreManual_meta.json` and figures). It is the authoritative spec for GUI behavior, simulation types, MMM data structures, and design workflow — when in doubt about intent, prefer it over inference from code.

## Recent work in this fork (continuity log)

This is a personal fork of `SyR-e/syre_public`. The local additions and one core-code edit are summarised below so a fresh Claude session can pick up where the previous one left off.

### Goal

Headless workflow (no `.mlapp`) for designing, plotting, and FEMM-simulating a **direct-drive PM machine: 2 m diameter, 20 pole pairs, x = r/R ≈ 0.9, Seg topology with one barrier filled with magnets** — sized for ~1 MNm of torque (multi-MW direct-drive PMSG class).

### Local files (this fork only — never PR upstream)

- **`from_scratch_dataSet.m`** — populates `dataSet` from scratch, mirroring `motorExamples/syreDefaultMotor.mat` then mutated for the 2 m / p=20 target. Every field is materialised so a fresh MATLAB workspace can rebuild the struct without `load()`. Runs as a script; ~232 fields. Notes:
  - `PMdim`, `PMdimPU`, `PMNc`, `PMclear` must be **column vectors** (e.g. `[0; 20.63]`) — row-vector form crashes `PMdefinition_Seg.m:59`.
  - Stale path overridden at the bottom: `dataSet.currentpathname = checkPathSyntax(fullfile(cd,'motorExamples',filesep))`.
- **`run_xb_plane.m`** — runner: `setupPath` → `from_scratch_dataSet` → `back_compatibility(dataSet,[],[],0)` → `eval_xbDesignPlane(dataSet, 1)` → save `xb_plane_<stamp>.{png,fig,mat}` to `results/`. The `1` second-arg is the explicit "outside GUI" debug flag (suppresses the `questdlg` and `xbDesignPlaneExplorer` handoff). Octave-compatible (uses `print` + `isoctave()` branching for the figure save).
- **`eval_xb_point_femm.m`** — picks `(x, b) = (0.9, 0.5)` on the analytical map, interpolates a concrete `dataSet` via `interp2` (mirrors `syreCustomFeatures/syrmDesignExplorer/mfiles/SDE_saveMotor.m`), draws via `DrawAndSaveMachine`, then calls `FEMMfitness([], geo, per, mat, 'singt', femFile)` for a single-point sim. Saves `machine_x09_b05.{fem,mat}` and `torque_x09_b05_<stamp>.png`.

### Modified core code (this is the upstream-PR candidate)

- **`mfiles/syrmDesign/FEAfixSimulation.m`** — patched the `if flagPM ... else ... end` block (originally at lines 230-234) so that **`OUT.fM` is set for PM machines via a no-load FEMM run**. The original branch was empty for PMs; the no-load computation was already present commented out at lines 196-208. Without this fix, FEAfix on Seg+PM crashes at line 263 (`Unrecognized field name "fM"`) and at `FEAfix.m:455`. The patch:

  ```matlab
  if flagPM || strcmp(geo.RotType,'EESM')
      perNL = per; perNL.overload = 0;
      RQnl = RQ;
      if strcmp(geo.axisType,'PM'), RQnl(end) = 0; else, RQnl(end) = 90; end
      [~,~,~,out_nl,~] = FEMMfitness(RQnl,geo,perNL,mat,eval_type,filemot);
      nFEA = nFEA+1;
      if strcmp(geo.axisType,'PM'), OUT.fM = out_nl.fd; else, OUT.fM = -out_nl.fq; end
  else
      OUT.fM = 0;
  end
  ```

  Costs one extra FEMM solve per FEAfix sample point. **This is the only file in `mfiles/` that should go in the upstream PR.**

### Workflow learnings (the gotchas a fresh session should know)

1. **`FEMMfitness([], ...)` doesn't recompute `i0` from `kj`.** `data0` reads `per.i0 = dataSet.RatedCurrent` directly. Inside `FEMMfitness`, `calc_i0` is only called when `RQ` is non-empty (optimization path). For post-processing, you must call `per = calc_i0(geo, per, mat)` yourself before `FEMMfitness`, after setting `per.J = NaN; per.Loss = NaN; per.flag_OptCurrConst = 0;` so it dispatches to the `kj` branch. Without this, a 2 m machine simulated with the seed motor's 802 A peak instead of the design's actual ~35 kA — torque comes out 1700× too low.
2. **The (x,b) plane uses linear iron**; FEMM doesn't. At aggressive operating points (high `kj`, thin teeth from `kt=1`), the analytical torque can be ~17× higher than reality. **FEAfix is mandatory** for trustworthy contour maps in saturated designs. With `FEAfixN=4` the corrected torque at (0.9, 0.5) was ~200 kNm; without FEAfix the analytical map said ~800 kNm; FEMM single-point said 46 kNm. Increase `FEAfixN` to 8 or 16 to tighten the gap.
3. **Mesh sizing for D=2 m machines**: defaults `Mesh=5, Mesh_MOOA=10` are far too fine — a single FEMM solve takes 30+ minutes. `Mesh=50, Mesh_MOOA=50` gives ~5 s/position with acceptable accuracy for design exploration. Tighten to `Mesh=20-30` only after `Ns` and `kj` are settled.
4. **Wide `xRange` causes `nodes_rotor_Seg` to throw** at infeasible corners (oversize shaft, negative iron). For x ≈ 0.9 keep the window inside `[0.85, 0.95]`.
5. **Per-rotor-type axis convention**: `Seg` with PMs typically uses `axisType='PM'` (PMs along +d). The analytical `gamma` from `map.gamma` follows that convention; pass it through to `per.gamma` unchanged.

### Open questions / next steps

- Run `FEAfixN = 16` (~40 min) for a saturation-corrected map dense enough to interpolate accurately at any single (x, b) point.
- Pick a design point that the FEAfix-corrected map predicts ≥ 1 MNm (likely lower x, e.g. 0.6-0.7, where stator copper area is larger and saturation is less aggressive).
- Use `SDE_targetDesign(map, struct('T',1e6,'Vdc',690,'Imax',2000,'Ns',[5:30],...))` to set a target torque + DC voltage and let the framework pick a feasible `(x, b, Ns)` triple — this also fixes the `TurnsInSeries=21` artefact that was inherited from the `syreDefaultMotor` seed.
- Sweep an `(id, iq)` flux map at the chosen design point via `eval_fluxMap` for control-side use (then load into `GUI_Syre_MMM` headless equivalents `MMM_load`, `MMM_eval_AOA`, etc.).

### Branch layout (target)

- `main` — tracks `upstream/main` (SyR-e/syre_public).
- `fix/feafix-fm-seg-pm` — single commit: the `FEAfixSimulation.m` patch. PR'd to `SyR-e:main`.
- `experiments/2m-direct-drive` — adds `from_scratch_dataSet.m`, `run_xb_plane.m`, `eval_xb_point_femm.m`, this `CLAUDE.md`, `.gitignore` (excludes `results/`, `tmp/`, `syreDrive/PLECSModel/SimMatFiles/`). Fork-only; never PR'd.

