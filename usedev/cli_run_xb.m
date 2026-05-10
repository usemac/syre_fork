function cli_run_xb(motorFileArg)
% Analytical-only (x,b) design plane — fast, no FEMM.
%
% Forces FEAfixN=0, so all FEAfix correction factors are 1 and the plane
% comes purely from xbPlane_analyticalDesign. Use this to validate the
% machine parameters and MATLAB toolchain before running the slower
% FEMM-based correction (cli_run_xb_feafix).
%
% Usage (from anywhere on the MATLAB path; setupPath is run automatically):
%   cli_run_xb();                      % syreDefaultMotor
%   cli_run_xb('myMot.mat');           % file under <repo>/motorExamples/
%   cli_run_xb('C:\path\to\mot.mat');  % absolute path

% repoDir = parent of this script's folder (script lives in <repo>/usedev/)
repoDir = fileparts(fileparts(mfilename('fullpath')));
cd(repoDir);

addpath(repoDir);
setupPath(0);

if nargin < 1 || isempty(motorFileArg)
    motorPath = fullfile(repoDir, 'motorExamples', filesep);
    motorFile = 'syreDefaultMotor.mat';
else
    [d, n, e] = fileparts(motorFileArg);
    if isempty(e); e = '.mat'; end
    if isempty(d)
        motorPath = fullfile(repoDir, 'motorExamples', filesep);
    else
        motorPath = [d, filesep];
    end
    motorFile = [n, e];
end

fprintf('\n[1/3] Loading %s ...\n', fullfile(motorPath, motorFile));
S = load(fullfile(motorPath, motorFile));
if ~isfield(S, 'dataSet')
    error('cli_run_xb:noDataSet', 'No dataSet found in %s.', motorFile);
end
dataSet = S.dataSet;
dataSet.currentpathname = motorPath;
dataSet.currentfilename = motorFile;
if isfield(S, 'geo') && isfield(S, 'per')
    dataSet = back_compatibility(dataSet, S.geo, S.per, 0);
end

% --- force analytical-only ---
dataSet.FEAfixN = 0;

% syrmDesignFlag fields used downstream (safe defaults)
if ~isfield(dataSet, 'syrmDesignFlag') || ~isstruct(dataSet.syrmDesignFlag)
    dataSet.syrmDesignFlag = struct();
end
defaults = struct('ks',1,'gf',0,'ichf',0,'scf',0, ...
    'demag0',0,'demagHWC',0,'demagUGO',0, ...
    'Mech',0,'mech',0,'therm',0);
fn = fieldnames(defaults);
for ii = 1:numel(fn)
    if ~isfield(dataSet.syrmDesignFlag, fn{ii})
        dataSet.syrmDesignFlag.(fn{ii}) = defaults.(fn{ii});
    end
end

fprintf('\n[2/3] Motor: %s | RotType: %s | p=%d | q=%d | R=%g mm | l=%g mm | g=%g mm\n', ...
    motorFile, dataSet.TypeOfRotor, dataSet.NumOfPolePairs, dataSet.NumOfSlots, ...
    dataSet.StatorOuterRadius, dataSet.StackLength, dataSet.AirGapThickness);

tStart = tic;
[dataSet, ~, hfig, map] = eval_xbDesignPlane(dataSet, 1);  %#ok<ASGLU>
elapsed = toc(tStart);
fprintf('   analytical (x,b) plane done in %.2f s\n', elapsed);

resultsDir = fullfile(repoDir, 'results');
if ~exist(resultsDir, 'dir'); mkdir(resultsDir); end
stamp   = datestr(now, 'yyyymmdd_HHMMSS'); %#ok<DATST,TNOW1>
baseStr = sprintf('xbAnalytical_%s_%s', erase(motorFile,'.mat'), stamp);
mapFile = fullfile(resultsDir, [baseStr '.mat']);
save(mapFile, 'map', 'dataSet');

if isgraphics(hfig)
    savefig(hfig, fullfile(resultsDir, [baseStr '.fig']));
    try
        exportgraphics(hfig, fullfile(resultsDir, [baseStr '.png']), 'Resolution', 150);
    catch
        saveas(hfig, fullfile(resultsDir, [baseStr '.png']));
    end
end

fprintf('\n[3/3] Summary\n');
fprintf('   x range : [%.3f, %.3f]   (%d points)\n', min(map.xx(:)), max(map.xx(:)), size(map.xx,2));
fprintf('   b range : [%.3f, %.3f]   (%d points)\n', min(map.bb(:)), max(map.bb(:)), size(map.bb,1));
Tvalid = map.T(~isnan(map.T));
if ~isempty(Tvalid)
    fprintf('   T  range: [%.2f, %.2f] Nm\n', min(Tvalid), max(Tvalid));
    [Tmax, idx] = max(Tvalid);
    xVec = map.xx(~isnan(map.T));
    bVec = map.bb(~isnan(map.T));
    fprintf('   Tmax    = %.2f Nm at (x=%.3f, b=%.3f)\n', Tmax, xVec(idx), bVec(idx));
end
if isfield(map,'PF')
    PFv = map.PF(~isnan(map.PF));
    if ~isempty(PFv)
        fprintf('   PF range: [%.3f, %.3f]\n', min(PFv), max(PFv));
    end
end
fprintf('\nSaved: %s\n', mapFile);
end
