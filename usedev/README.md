# usedev — script-based SyR-e workflow

Headless / IDE-based SyR-e workflow that bypasses the App-Designer GUIs. Edit a single block of elemental machine parameters, then run the (x,b) preliminary design plane — first analytically (fast), then with FEAfix correction (slow, calls FEMM).

```
usedev/
├── define_machine.m       % the elemental parameter set + dataSet builder
├── cli_run_xb.m           % Part 1 — analytical (x,b) plane, no FEMM
├── cli_run_xb_feafix.m    % Part 2 — same plane with FEMM-based FEAfix
└── README.md
```

All three scripts compute the repo root as the parent directory of `usedev/` and call `setupPath` automatically, so they work from anywhere on the MATLAB path.

## 0. Development model — `usedev/` is a strict overlay

`usedev/` is the **only** place under-development local code lives. Everything outside it (`mfiles/`, `syreDrive/`, `syreExport/`, `syreCustomFeatures/`, `motorExamples/`, `materialLibrary/`, `GUI_Syre*.mlapp`, `setupPath.m`, ...) is **upstream SyR-e code** and should be kept pristine for clean upstream pull-requests.

**Two distinct change types — keep them on separate branches:**

| Change type | Where it goes | How to ship it |
|-------------|---------------|----------------|
| Personal scripts, custom workflows, experiments | `usedev/` only | Stays in your fork — never PR'd upstream |
| Bug fix in core SyR-e (e.g. something in `mfiles/`) | The original file, in-place | PR'd upstream to [SyR-e/syre_public](https://github.com/SyR-e) |
| New feature for upstream (rotor topology, exporter, ...) | New file under the appropriate upstream folder + edits to the integration points | PR'd upstream |

The principle: **never mix local-only code with upstream-bound code in the same commit or branch**. A reviewer at upstream should see only the focused fix or feature, with no `usedev/` clutter.

### Files that are local-only (do not commit to upstream PR branches)

- `usedev/` — this folder
- `CLAUDE.md` — Claude Code config at the repo root
- `.claude/` — Claude Code state
- `Readme/markdowns/` — locally-rendered manual (regenerable)
- `tmp/`, `results/` — runtime output (regenerable)

To make sure these never leak into an upstream PR, add them to `.git/info/exclude` (a local, never-committed ignore file):

```bash
cd <repo>
cat >> .git/info/exclude <<'EOF'
usedev/
CLAUDE.md
.claude/
Readme/markdowns/
tmp/
results/
EOF
```

### Recommended branch layout

```
main                 ← tracks upstream SyR-e (clean, no local changes)
local-dev            ← branched off main, contains usedev/ + CLAUDE.md + .claude/
fix/<short-desc>     ← branched off main for each upstream PR (no usedev/ content)
feat/<short-desc>    ← same, for upstream features
```

Day-to-day work happens on `local-dev`. When you spot a bug or want to contribute a feature upstream, branch off `main` (not `local-dev`) into a fresh `fix/` or `feat/` branch — that guarantees the PR contains nothing from `usedev/`.

### Submitting an upstream PR — checklist

1. `git checkout main && git pull --ff-only` — sync with upstream.
2. `git checkout -b fix/<short-desc>` — fresh branch, no local clutter.
3. Make the fix in the original SyR-e file (`mfiles/...`, `syreExport/...`, etc.). **Do not** import any code from `usedev/` — if the fix needs a helper, the helper goes upstream too.
4. Test the fix from `usedev/cli_run_xb*` (those still work — they `addpath` upstream). The runners are local *consumers* of upstream code; they prove the fix works without polluting the PR.
5. `git status` — verify only the upstream files you intended are modified. **No `usedev/` paths should appear.**
6. Commit, push, open the PR against [SyR-e/syre_public](https://github.com/SyR-e).

---

## 1. Edit the elemental parameters

Open `usedev/define_machine.m` and edit the `M` struct at the top of the file. Everything below the `APPLY TO BASELINE dataSet` comment line is plumbing — leave it alone.

The `M` struct is grouped into sections. Change the values you care about; defaults are set to a sensible 2-pole-pair, 3-slots/pole/phase, 3-layer SyR machine.

| Section | Fields | Notes |
|---------|--------|-------|
| **Topology** | `RotType`, `p`, `q`, `n3ph`, `nlay` | `RotType ∈ {'Circular','Seg','Fluid','SPM','Spoke-type','EESM','IM'}`. (`'ISeg'` and `'Vtype'` are deprecated by upstream — use `'Seg'` and adjust `CentralShrink` for V-type designs.) `nlay` is forced to 1 for `'SPM'` / `'Spoke-type'`. |
| **Sizing** | `R`, `l`, `g`, `Ar`, `nmax`, `pont0` | All [mm] except `nmax` [rpm]. `pont0` is the minimum mechanical bridge thickness used by the rib design. |
| **Operating point** | `Vdc`, `nbase`, `kj`, `J`, `tempcu`, `temphous`, `tempPM` | `kj` [W/m²] is thermal loading; `J` [Apk/mm²] is slot current density; one drives the rated current calculation, the other is informational. `RatedCurrent` is reset to NaN so SyR-e recomputes it from `kj` on the next `data0()` call. |
| **Winding** | `Ns`, `kcu`, `kracc` | `Ns` = turns in series per phase. `kcu` = slot fill factor. `kracc` = pitch shortening (1 means full pitch). |
| **Materials** | `StatorMaterial`, `RotorMaterial`, `FluxBarrierMaterial`, `SlotMaterial`, `ShaftMaterial` | Names must exist in `materialLibrary/{iron,layer,conductor,sleeve}_material.mat`. Use `'Air'` as `FluxBarrierMaterial` for pure SyR; a PM grade name (e.g. `'BMN-38EH'`) for PM-SyR / IPM / SPM. |
| **Magnetic loading targets** | `Bfe`, `kt`, `ky`, `kyr` | `Bfe` is the yoke flux-density target [T]. `kt` is the tooth saturation factor (1 = no saturation accounted). `ky`/`kyr` scale stator/rotor yoke length. |
| **Rotor barrier shape** | `ALPHApu`, `HCpu`, `DepthOfBarrier` | All three are vectors of length `nlay`. The script auto-pads/trims if you give a wrong-length vector. |
| **PM** | `Br`, `kPM`, `PMdimPU` | Only relevant when `FluxBarrierMaterial != 'Air'`. `Br` [T] at design temperature; `kPM` is the per-unit barrier area filled by PM; `PMdimPU` is a `2 × nlay` matrix of per-unit PM segment sizes. |
| **(x,b) sweep + FEAfix** | `xRange`, `bRange`, `FEAfixN` | `xRange` and `bRange` are 2-element `[min max]` vectors. `FEAfixN ∈ {0, 1, 4, 5, 8, 16}`. |

### How the override works

`define_machine` loads `motorExamples/syreDefaultMotor.mat` as a baseline so all of SyR-e's ~200 dataSet fields (mesh density, optimization bounds, MOOA flags, slot conductor sub-model, EESM/IM-specific data, custom current waveforms, ...) are pre-populated with sensible values. Only the fields listed above are overridden from `M`. The mapping `M.foo → dataSet.SyreEquivalentName` follows `mfiles/data0.m` and `mfiles/syrmDesign/xbPlane_analyticalDesign.m`.

---

## 2. Run the workflow

From the MATLAB Command Window:

```matlab
% one-time, after starting MATLAB:
cd('C:\Users\sim-intel\workspace\usemac\syre_fork')
setupPath
addpath(fullfile(pwd, 'usedev'));   % put the runner scripts on the path
```

After that, you can re-run the workflow at will:

```matlab
% A) generate the motor file from your edited M struct:
dataSet = define_machine('motorExamples/myMot');     % saves myMot.mat

% B) Part 1 — analytical only (seconds, no FEMM):
cli_run_xb('myMot.mat')

% C) Part 2 — once Part 1 looks good, add FEAfix (minutes, calls FEMM):
cli_run_xb_feafix('myMot.mat')
```

Without arguments, the runners use the bundled `syreDefaultMotor` example:

```matlab
cli_run_xb()             % syreDefaultMotor, analytical only
cli_run_xb_feafix()      % syreDefaultMotor, with FEAfix
```

### Why two parts?

- **Part 1** (`cli_run_xb`) forces `FEAfixN=0` and exercises only `xbPlane_analyticalDesign` — pure scalar math from the elemental parameters. It validates that the parameter set is consistent (no NaNs, materials resolve, vector lengths match `nlay`) and produces the analytical T / PF contour map. Useful as a fast iteration loop while tuning `M`.
- **Part 2** (`cli_run_xb_feafix`) keeps `FEAfixN=5` and runs five FEMM evaluations (corners + center of the (x,b) plane), then scales the analytical map cell-by-cell by the `kd, kq, km, k0, kg, ...` correction factors. Run only after Part 1 is happy.

---

## 3. Outputs

Both runners write under `<repo>/results/`:

| Runner | Filename pattern |
|--------|------------------|
| `cli_run_xb` | `xbAnalytical_<motor>_<yyyymmdd_HHMMSS>.{mat,fig,png}` |
| `cli_run_xb_feafix` | `xbPlane_<motor>_<yyyymmdd_HHMMSS>.{mat,fig,png}` |

The `.mat` file holds the `map` struct (full grid of T, PF, fluxes, geometry choices, FEAfix factors, ...) and the final `dataSet`. To pick a single design from the plane, load the `.mat` and inspect `map`, or use `syrmDesignExplorer` interactively:

```matlab
load('results\xbPlane_myMot_20260510_142233.mat')
syrmDesignExplorer(map)
```

The MATLAB Command Window prints a brief summary at the end (x/b grid sizes, T range, Tmax point, PF range, FEAfix raw points).

---

## 4. Running MATLAB from the CLI (headless / shell)

You can drive the entire workflow from a Windows shell — useful for batch jobs, CI, or remote sessions. There are two MATLAB invocation flavors. **Both block until MATLAB finishes; the figures are still saved as `.fig` / `.png` under `results/` and can be opened later.**

### 4.1 `matlab -batch` (recommended for one-shot runs)

The modern, scriptable invocation. MATLAB starts, runs the command, exits with a non-zero code on error, and writes everything stdout/stderr to your terminal.

```powershell
# PowerShell — set REPO once per session
$matlab = 'C:\Program Files\MATLAB\R2024b\bin\matlab.exe'
$REPO   = 'C:\Users\sim-intel\workspace\usemac\syre_fork'

# Part 1 — analytical (x,b) plane on the default motor
& $matlab -batch "cd('$REPO'); setupPath; addpath(fullfile('$REPO','usedev')); cli_run_xb"

# Build a custom motor + run Part 1 on it:
& $matlab -batch "cd('$REPO'); setupPath; addpath(fullfile('$REPO','usedev')); define_machine('motorExamples/myMot'); cli_run_xb('myMot.mat')"

# Part 2 — analytical + FEAfix (calls FEMM, takes minutes)
& $matlab -batch "cd('$REPO'); setupPath; addpath(fullfile('$REPO','usedev')); cli_run_xb_feafix('myMot.mat')"
```

`cmd.exe` equivalent (use `^` for line continuation if you want to wrap):

```cmd
"C:\Program Files\MATLAB\R2024b\bin\matlab.exe" -batch "cd('C:\Users\sim-intel\workspace\usemac\syre_fork'); setupPath; addpath(fullfile(pwd,'usedev')); cli_run_xb"
```

Adjust the MATLAB executable path for your version (`R2025b`, `R2023a`, ...). Use `where matlab` (cmd) or `Get-Command matlab` (PowerShell) to locate it if MATLAB is on the system PATH.

### 4.2 `matlab -nodesktop -nosplash -r ... -logfile`

The older interface — useful when `-batch` isn't producing output. `-r` is non-blocking unless paired with `-wait`; `-logfile` writes MATLAB's full diary to a file you can `tail -f`.

```powershell
$matlab = 'C:\Program Files\MATLAB\R2024b\bin\matlab.exe'
$REPO   = 'C:\Users\sim-intel\workspace\usemac\syre_fork'
$cmd    = "try, cd('$REPO'); setupPath; addpath(fullfile('$REPO','usedev')); cli_run_xb; catch e, disp(getReport(e)); end, quit force"

& $matlab -nodesktop -nosplash -minimize -wait -logfile "$REPO\tmp\cli.log" -r $cmd
Get-Content "$REPO\tmp\cli.log" -Tail 50
```

Notes:
- Always wrap the `-r` body in `try/catch ... quit force`, otherwise an error keeps MATLAB alive forever.
- `-minimize` hides the (otherwise visible) MATLAB window without disabling Java — App-Designer figures still render off-screen so the `.fig` / `.png` outputs work.
- `-wait` blocks the shell until MATLAB exits; without it, MATLAB launches asynchronously.

### 4.3 Pitfall — license-checkout hangs

On some Windows installs (corporate FlexLM, network license, expired activation) `matlab -batch` and `-r` will hang at startup with **no stdout output**, ~0.3 s of CPU consumed, and never reach your script. Symptoms: process running for many minutes, `tmp/cli.log` never appears, no FEMM process spawned.

This is a license-side issue, not a SyR-e issue. Diagnostic steps:

```powershell
# 1) probe with the simplest possible command — does even disp() work?
& $matlab -batch "disp('alive'); disp(version)"
# expected: prints "alive" + version string within ~30-90s on a healthy install

# 2) check which MATLAB processes are alive and whether they're actually working
Get-Process matlab,MATLAB -EA SilentlyContinue | Select Id,ProcessName,CPU,@{n='WS_MB';e={[int]($_.WS/1MB)}},StartTime
# CPU stuck at <1s after several minutes = hung at license / activation prompt
```

If the trivial probe hangs, fix MATLAB's license configuration before bothering with our scripts. Workarounds: launch MATLAB once interactively to clear any pending license dialog, or check `C:\Users\<you>\AppData\Roaming\MathWorks\MATLAB\R<version>\licenses\` for stale license files.

When CLI launching is broken, fall back to running everything from the MATLAB IDE Command Window — see §2 above.

---

## 5. Troubleshooting

- **"Undefined function `setupPath`"** — you launched the runner from outside the repo; either `cd` into the repo first or add it to the path manually. The runners do this automatically once they've located their parent folder.
- **"No dataSet found in ..."** — the `.mat` you pointed at doesn't contain a `dataSet` variable. SyR-e motor files always do; check the path.
- **`define_machine` says `Defined ...` but the figure looks wrong** — verify the rotor type matches the `ALPHApu`/`HCpu` length and that `FluxBarrierMaterial` is consistent with `Br` (set `Br=0` and material `'Air'` for SyR; otherwise use a real PM grade).
- **FEAfix hangs or errors** — that's FEMM. Check that `C:\femm42\mfiles\` exists and `openfemm` works in a fresh MATLAB session. `cli_run_xb` (Part 1) is the FEMM-free check.
