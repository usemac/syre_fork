function dataSet = define_machine(saveAs)
% define_machine — Elemental parameter set for a SyR-e machine.
%
% SyR-e's dataSet has ~200 fields. Most are toolchain configuration
% (mesh density, optimization bounds, MOOA flags, slot conductor sub-model,
% IM rotor, EESM rotor, custom current waveforms, ...). The truly
% elemental design parameters — the ones a designer chooses up front before
% the (x,b) plane fills in the rest — are collected in `M` below.
%
% Strategy: load motorExamples/syreDefaultMotor.mat as a baseline so all
% non-design fields are sensibly populated, then override only the
% elemental ones. Mapping to the canonical dataSet field names follows
% data0.m and xbPlane_analyticalDesign.m.
%
% Usage (from anywhere on the MATLAB path; setupPath must have been run once):
%   dataSet = define_machine();                       % returns dataSet, no save
%   dataSet = define_machine('motorExamples/myMot');  % saves myMot.mat under <repo>/motorExamples
%   dataSet = define_machine('C:\path\to\myMot.mat'); % saves at an absolute path
%
% Pair with cli_run_xb / cli_run_xb_feafix to compute the (x,b) plane.

% ---------------------------------------------------------------------
% ELEMENTAL DESIGN PARAMETERS  — edit this block to define your machine
% ---------------------------------------------------------------------
% Default values mirror motorExamples/syreDefaultMotor.mat — a Seg-rotor
% V-IPM modeled on the Tesla Model 3 traction motor. Override what you
% need; everything else falls back to the baseline.
M = struct();

% --- Topology ---------------------------------------------------------
M.RotType    = 'Seg';        % 'Circular' | 'Seg' | 'Fluid' | 'SPM' | 'Spoke-type' | 'EESM' | 'IM'
                              %   ('ISeg' and 'Vtype' are deprecated — use 'Seg' instead)
M.p          = 3;            % pole pairs (6 poles)
M.q          = 3;            % stator slots per pole per phase (54 slots total)
M.n3ph       = 1;            % number of independent 3-phase sets (NaN -> 5-phase)
M.nlay       = 2;            % rotor flux-barrier layers (forced to 1 for SPM/Spoke-type)

% --- Main dimensions [mm] / [rpm] ------------------------------------
M.R          = 112.5;        % stator outer radius
M.l          = 134;          % stack length
M.g          = 0.7;          % airgap thickness
M.Ar         = 34.75;        % shaft radius
M.nmax       = 18100;        % overspeed [rpm]
M.pont0      = 0.4;          % min mechanical tolerance / rib thickness [mm]

% --- Operating point --------------------------------------------------
M.Vdc        = 400;          % DC bus voltage [V] (not in baseline — drive-side field)
M.nbase      = 4000;         % evaluation / base speed [rpm]
M.kj         = 170987;       % thermal loading [W/m^2 of stator outer surface] (aggressive cooling)
M.J          = 36;           % slot current density [Apk/mm^2] (peak)
M.tempcu     = 120;          % target copper temperature [degC]
M.temphous   = 70;           % housing temperature [degC]
M.tempPM     = 80;           % PM temperature for FEA postproc [degC]

% --- Winding ----------------------------------------------------------
M.Ns         = 21;           % turns in series per phase
M.kcu        = 0.38;         % slot fill factor (net Cu / slot area)
M.kracc      = 1;            % pitch-shortening factor (1 = full pitch)

% --- Materials --------------------------------------------------------
% Names must match entries in materialLibrary/{iron,layer,conductor,sleeve}_material.mat
M.StatorMaterial      = 'M270-35A';
M.RotorMaterial       = 'M270-35A';
M.FluxBarrierMaterial = 'BMN-52UH';   % 'Air' for pure SyR; PM grade name for PM-SyR/IPM/SPM
M.SlotMaterial        = 'Copper';
M.ShaftMaterial       = 'Air';        % non-magnetic shaft

% --- Magnetic loading targets (analytical (x,b) design) --------------
M.Bfe        = 1.5;          % yoke flux density target [T]
M.kt         = 1;            % tooth saturation factor (wt / wt_unsat)
M.ky         = 1;            % stator yoke factor (ly / ly_ideal)
M.kyr        = 1;            % rotor yoke factor (lyr / lys)

% --- Rotor barrier shape (length must equal nlay) --------------------
M.ALPHApu        = [0.50, 0.30];     % barrier angular positions [pu]
M.HCpu           = [0.35, 0.25];     % barrier widths [pu]
M.DepthOfBarrier = zeros(1, M.nlay); % radial offset / dx per layer

% --- PM (relevant when FluxBarrierMaterial != 'Air') -----------------
M.Br         = 1.45;             % PM remanence at design temperature [T]
M.kPM        = 1;                % PM filling factor (per-unit barrier area filled by PM)
M.PMdimPU    = [0, 0; 1, 1];     % per-unit PM dimensions per layer (rows: outer/inner segments)

% --- (x,b) design plane sweep ----------------------------------------
M.xRange     = [0.5 0.7];    % rotor/stator split sweep range
M.bRange     = [0.4 0.6];    % p.u. magnetic loading sweep range
M.FEAfixN    = 16;           % FEAfix correction points: 0,1,4,5,8,16

% ---------------------------------------------------------------------
% APPLY TO BASELINE dataSet
% ---------------------------------------------------------------------
% repoDir = parent of this script's folder (script lives in <repo>/usedev/)
repoDir = fileparts(fileparts(mfilename('fullpath')));
if exist('GUI_Syre.mlapp', 'file') ~= 4
    addpath(repoDir);
    setupPath(0);
end

base = load(fullfile(repoDir, 'motorExamples', 'syreDefaultMotor.mat'));
dataSet = base.dataSet;
if isfield(base, 'geo') && isfield(base, 'per')
    dataSet = back_compatibility(dataSet, base.geo, base.per, 0);
end

% Topology
dataSet.TypeOfRotor       = M.RotType;
dataSet.NumOfPolePairs    = M.p;
dataSet.NumOfSlots        = M.q;
dataSet.Num3PhaseCircuit  = M.n3ph;
if any(strcmp(M.RotType, {'SPM','Spoke-type'}))
    dataSet.NumOfLayers   = 1;
else
    dataSet.NumOfLayers   = M.nlay;
end

% Sizing
dataSet.StatorOuterRadius = M.R;
dataSet.StackLength       = M.l;
dataSet.AirGapThickness   = M.g;
dataSet.ShaftRadius       = M.Ar;
dataSet.OverSpeed         = M.nmax;
dataSet.MinMechTol        = M.pont0;

% Operating point
dataSet.DCVoltage         = M.Vdc;
dataSet.EvalSpeed         = M.nbase;
dataSet.ThermalLoadKj     = M.kj;
dataSet.CurrentDensity    = M.J;
dataSet.TargetCopperTemp  = M.tempcu;
dataSet.HousingTemp       = M.temphous;
dataSet.tempPP            = M.tempPM;

% Winding
dataSet.TurnsInSeries     = M.Ns;
dataSet.SlotFillFactor    = M.kcu;
dataSet.PitchShortFac     = M.kracc;

% Materials
dataSet.StatorMaterial      = M.StatorMaterial;
dataSet.RotorMaterial       = M.RotorMaterial;
dataSet.FluxBarrierMaterial = M.FluxBarrierMaterial;
dataSet.SlotMaterial        = M.SlotMaterial;
dataSet.ShaftMaterial       = M.ShaftMaterial;

% Analytical (x,b) targets
dataSet.Bfe              = M.Bfe;
dataSet.kt               = M.kt;
dataSet.StatorYokeFactor = M.ky;
dataSet.RotorYokeFactor  = M.kyr;

% Rotor barrier shape — validate cardinality
nl = dataSet.NumOfLayers;
dataSet.ALPHApu        = padOrTrim(M.ALPHApu,        nl, 1/nl);
dataSet.HCpu           = padOrTrim(M.HCpu,           nl, 1/nl);
dataSet.DepthOfBarrier = padOrTrim(M.DepthOfBarrier, nl, 0);

% Resize baseline per-layer arrays the user didn't override. The baseline
% syreDefaultMotor.mat carries these at its own nlay; if M.nlay differs,
% data0 iterates 1:geo.nlay over each and would index out-of-bounds.
% Replicate the first existing element when extending (matches back_compatibility.m).
perLayerFields = { ...
    'betaPMshape', 'RadRibEdit', 'TanRibEdit', 'CentralShrink', 'RadShiftInner', ...
    'RotorFilletTan1', 'RotorFilletTan2', 'RotorFilletIn', 'RotorFilletOut'};
for k = 1:numel(perLayerFields)
    fn = perLayerFields{k};
    if isfield(dataSet, fn) && ~isempty(dataSet.(fn))
        dataSet.(fn) = padOrTrim(dataSet.(fn), nl, dataSet.(fn)(1));
    end
end

% PM
dataSet.Br      = M.Br;
dataSet.kPM     = M.kPM;
dataSet.PMtemp  = M.tempPM;
dataSet.PMdimPU = M.PMdimPU;

% Resize PMdim and PMNc from baseline to match current nlay
nl = dataSet.NumOfLayers;
if size(dataSet.PMdim, 2) ~= nl
    dataSet.PMdim = repmat(dataSet.PMdim(:,1), 1, nl);
end
if size(dataSet.PMNc, 2) ~= nl
    dataSet.PMNc = repmat(dataSet.PMNc(:,1), 1, nl);
end

% (x,b) sweep + FEAfix
dataSet.xRange  = M.xRange;
dataSet.bRange  = M.bRange;
dataSet.FEAfixN = M.FEAfixN;

% Reset RatedCurrent so it gets recomputed from kj at next data0() call
dataSet.RatedCurrent = NaN;

% ---------------------------------------------------------------------
% OPTIONAL SAVE
% ---------------------------------------------------------------------
if nargin >= 1 && ~isempty(saveAs)
    [outDir, outName] = fileparts(saveAs);
    if isempty(outDir); outDir = fullfile(repoDir, 'motorExamples'); end
    if ~exist(outDir, 'dir'); mkdir(outDir); end
    outFile = fullfile(outDir, [outName '.mat']);
    dataSet.currentpathname = [outDir filesep];
    dataSet.currentfilename = [outName '.mat'];
    save(outFile, 'dataSet');
    fprintf('Saved machine definition to %s\n', outFile);
end

fprintf('Defined %s machine: p=%d, q=%d, R=%g mm, l=%g mm, g=%g mm, nlay=%d, FluxBarrier=%s\n', ...
    M.RotType, M.p, M.q, M.R, M.l, M.g, dataSet.NumOfLayers, M.FluxBarrierMaterial);
end

% ---------------------------------------------------------------------
function v = padOrTrim(v, n, fill)
v = v(:).';
if numel(v) < n
    v = [v, repmat(fill, 1, n - numel(v))];
elseif numel(v) > n
    v = v(1:n);
end
end
