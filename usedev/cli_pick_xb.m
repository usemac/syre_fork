function dataSet = cli_pick_xb(mapFileArg, xArg, bArg, outName)
% Pick an (x,b) point from a saved analytical (x,b) plane and build the
% paired .mat + .fem files for the chosen machine.
%
% Headless counterpart of the syrmDesignExplorer's "Save" button:
% replicates SDE_saveMotor's interpolation block and calls
% DrawAndSaveMachine with explicit filename/pathname (no uiputfile prompt).
%
% Usage (from anywhere on the MATLAB path; setupPath is run automatically):
%   cli_pick_xb('results/xbAnalytical_cliMot_20260512_113440.mat', 0.65, 0.5);
%   cli_pick_xb('results/xbAnalytical_cliMot_xxx.mat', 0.65, 0.5, 'myMot_picked');
%
% mapFileArg : path to an xbAnalytical_*.mat (or xbPlane_*.mat) saved by
%              cli_run_xb / cli_run_xb_feafix. Relative paths resolve
%              under the repo root.
% xArg, bArg : the (x, b) coordinates to pick. Must fall inside the grid.
% outName    : optional output basename. Defaults to
%              '<mapBase>_x<x>_b<b>' under <repo>/motorExamples/.

repoDir = fileparts(fileparts(mfilename('fullpath')));
cd(repoDir);
addpath(repoDir);
setupPath(0);

if nargin < 1 || isempty(mapFileArg)
    error('cli_pick_xb:missingMapFile', 'Usage: cli_pick_xb(mapFile, x, b [, outName])');
end
if nargin < 2 || isempty(xArg)
    error('cli_pick_xb:missingX', 'Provide x.');
end
if nargin < 3 || isempty(bArg)
    error('cli_pick_xb:missingB', 'Provide b.');
end

% Resolve mapFile (relative to repoDir unless absolute)
[d, n, e] = fileparts(mapFileArg);
if isempty(e); e = '.mat'; end
isAbs = ~isempty(d) && (contains(d, ':') || startsWith(d, '/') || startsWith(d, '\'));
if isAbs
    mapFile = fullfile(d, [n, e]);
else
    mapFile = fullfile(repoDir, d, [n, e]);
end
if ~exist(mapFile, 'file')
    error('cli_pick_xb:noMap', 'Map file not found: %s', mapFile);
end

fprintf('\n[1/4] Loading map from %s ...\n', mapFile);
S = load(mapFile);
if ~isfield(S, 'map') || ~isfield(S, 'dataSet')
    error('cli_pick_xb:badMap', '%s must contain ''map'' and ''dataSet''.', mapFile);
end
map = S.map;
dataSet = S.dataSet;

xMin = min(map.xx(:)); xMax = max(map.xx(:));
bMin = min(map.bb(:)); bMax = max(map.bb(:));
if xArg < xMin || xArg > xMax
    error('cli_pick_xb:xOutOfRange', 'x=%g outside grid [%g, %g].', xArg, xMin, xMax);
end
if bArg < bMin || bArg > bMax
    error('cli_pick_xb:bOutOfRange', 'b=%g outside grid [%g, %g].', bArg, bMin, bMax);
end
map.xSelect = xArg;
map.bSelect = bArg;

fprintf('\n[2/4] Interpolating geometry at (x=%.3f, b=%.3f) ...\n', xArg, bArg);
dataSet.AirGapRadius    = xArg * dataSet.StatorOuterRadius;
dataSet.ShaftRadius     = interp2(map.xx, map.bb, map.Ar,    xArg, bArg);
dataSet.ToothLength     = interp2(map.xx, map.bb, map.lt,    xArg, bArg);
dataSet.ToothWidth      = interp2(map.xx, map.bb, map.wt,    xArg, bArg);
dataSet.GammaPP         = interp2(map.xx, map.bb, map.gamma, xArg, bArg);
dataSet.ThermalLoadKj   = interp2(map.xx, map.bb, map.kj,    xArg, bArg);
dataSet.CurrentDensity  = interp2(map.xx, map.bb, map.J,     xArg, bArg);
dataSet.AdmiJouleLosses = dataSet.ThermalLoadKj * ...
    (2*pi*dataSet.StatorOuterRadius/1000 * dataSet.StackLength/1000);
if isfield(map, 'Ns')
    dataSet.TurnsInSeries = interp2(map.xx, map.bb, map.Ns, xArg, bArg);
else
    dataSet.TurnsInSeries = map.geo.win.Ns;
end

% PMdim — same recipe as SDE_saveMotor (zero-fill for Air barriers)
dataSet.PMdim = -dataSet.PMdimPU ./ dataSet.PMdimPU;
dataSet.PMdim(isnan(dataSet.PMdim)) = 0;
dataSet.PMdim = dataSet.kPM * dataSet.PMdim;

if strcmp(dataSet.TypeOfRotor, 'EESM')
    dataSet.YokeWidth         = interp2(map.xx, map.bb, map.lyr,        xArg, bArg);
    dataSet.PoleBodyHeight    = interp2(map.xx, map.bb, map.hpb,        xArg, bArg);
    dataSet.PoleHeadHeight    = interp2(map.xx, map.bb, map.hph,        xArg, bArg);
    dataSet.PoleWidth         = interp2(map.xx, map.bb, map.wp,         xArg, bArg);
    dataSet.CoilWidth         = interp2(map.xx, map.bb, map.wb,         xArg, bArg);
    dataSet.CoilHeight        = interp2(map.xx, map.bb, map.hb,         xArg, bArg);
    dataSet.PoleRotHeadAngle  = interp2(map.xx, map.bb, map.thHead_deg, xArg, bArg);
    dataSet.PoleRotHeadFillet = interp2(map.xx, map.bb, map.r_fillet,   xArg, bArg);
else
    nl = dataSet.NumOfLayers;
    [m, n] = size(map.xx);
    hc_pu = zeros(1, nl);
    dx    = zeros(1, nl);
    for ii = 1:nl
        hcTmp = zeros(m, n);
        dxTmp = zeros(m, n);
        for mm = 1:m
            for nn = 1:n
                hcTmp(mm, nn) = map.hc_pu{mm, nn}(ii);
                dxTmp(mm, nn) = map.dx{mm, nn}(ii);
            end
        end
        hc_pu(ii) = interp2(map.xx, map.bb, hcTmp, xArg, bArg);
        dx(ii)    = interp2(map.xx, map.bb, dxTmp, xArg, bArg);
    end
    dataSet.HCpu           = round(hc_pu*100)/100;
    dataSet.DepthOfBarrier = round(dx   *100)/100;
end

% Headless safety: suppress prompts inside DrawAndSaveMachine
dataSet.PMdimBouCheck = 0;
dataSet.custom        = 0;
if ~isfield(dataSet, 'XFEMMcreation'); dataSet.XFEMMcreation = 0; end

% Same back_compat call as SDE_saveMotor; empty geo/per/mat is tolerated.
[dataSet, ~, ~, ~] = back_compatibility(dataSet, [], [], 0);

% Output location
if nargin < 4 || isempty(outName)
    [~, mapBase] = fileparts(mapFile);
    xStr = strrep(sprintf('%.3f', xArg), '.', 'p');
    bStr = strrep(sprintf('%.3f', bArg), '.', 'p');
    outName = sprintf('%s_x%s_b%s', mapBase, xStr, bStr);
end
[outDir, outBase, outExt] = fileparts(outName);
outBase = [outBase, outExt];   % preserve any '.' in user-supplied name
if isempty(outDir)
    outDir = fullfile(repoDir, 'motorExamples');
end
if ~exist(outDir, 'dir'); mkdir(outDir); end
pathName = [outDir filesep];
femName  = [outBase, '.fem'];

dataSet.currentpathname = pathName;
dataSet.currentfilename = [outBase, '.mat'];

fprintf('\n[3/4] Drawing motor in FEMM -> %s ...\n', fullfile(pathName, femName));
tStart = tic;
dataSet = DrawAndSaveMachine(dataSet, femName, pathName);
fprintf('   FEMM model written in %.2f s\n', toc(tStart));

fprintf('\n[4/4] Done.\n');
fprintf('   .fem : %s\n', fullfile(pathName, femName));
fprintf('   .mat : %s\n', fullfile(pathName, [outBase, '.mat']));

if nargout() == 0
    clear dataSet
end
end
