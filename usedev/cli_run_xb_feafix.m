function cli_run_xb_feafix(motorFileArg)
% Headless runner: loads a motor (default: syreDefaultMotor), computes the
% (x,b) design plane, performs FEAfix, and saves the resulting map and figure.
%
% Usage (from anywhere on the MATLAB path; setupPath is run automatically):
%   cli_run_xb_feafix();                      % syreDefaultMotor
%   cli_run_xb_feafix('myMot.mat');           % file under <repo>/motorExamples/
%   cli_run_xb_feafix('C:\path\to\mot.mat');  % absolute path

% repoDir = parent of this script's folder (script lives in <repo>/usedev/)
repoDir = fileparts(fileparts(mfilename('fullpath')));
cd(repoDir);

addpath(repoDir);
setupPath(1);

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
fprintf('\n[1/4] Loading %s ...\n', motorFile);

S = load(fullfile(motorPath, motorFile));
if isfield(S, 'dataSet')
    dataSet = S.dataSet;
elseif isfield(S, 'motorModel')
    error('cli_run_xb_feafix:wrongFile', ...
        '%s unexpectedly holds a motorModel; expected a dataSet.', motorFile);
else
    error('cli_run_xb_feafix:noDataSet', 'No dataSet found in %s.', motorFile);
end

dataSet.currentpathname = motorPath;
dataSet.currentfilename = motorFile;

if isfield(S, 'geo') && isfield(S, 'per')
    [dataSet, ~, ~, ~] = back_compatibility(dataSet, S.geo, S.per, 1);
end

dataSet.FEAfixN = 5;

if ~isfield(dataSet, 'syrmDesignFlag') || ~isstruct(dataSet.syrmDesignFlag)
    dataSet.syrmDesignFlag = struct();
end
defaults = struct( ...
    'ks',      1, ...
    'gf',      0, ...
    'ichf',    0, ...
    'scf',     0, ...
    'demag0',  0, ...
    'demagHWC',0, ...
    'demagUGO',0, ...
    'Mech',    0, ...
    'mech',    0, ...
    'therm',   0);
fn = fieldnames(defaults);
for ii = 1:numel(fn)
    if ~isfield(dataSet.syrmDesignFlag, fn{ii})
        dataSet.syrmDesignFlag.(fn{ii}) = defaults.(fn{ii});
    end
end

fprintf('\n[2/4] Motor: %s | RotType: %s | p=%d | FEAfixN=%d\n', ...
    motorFile, dataSet.TypeOfRotor, dataSet.NumOfPolePairs, dataSet.FEAfixN);

fprintf('\n[3/4] Computing (x,b) plane and running FEAfix (this calls FEMM)...\n');
tStart = tic;
[dataSet, flagS, hfig, map] = eval_xbDesignPlane(dataSet, 1);  %#ok<ASGLU>
elapsed = toc(tStart);
fprintf('   done in %.1f s\n', elapsed);

resultsDir = fullfile(repoDir, 'results');
if ~exist(resultsDir, 'dir'); mkdir(resultsDir); end
stamp = datestr(now, 'yyyymmdd_HHMMSS'); %#ok<DATST,TNOW1>
mapFile = fullfile(resultsDir, sprintf('xbPlane_%s_%s.mat', erase(motorFile,'.mat'), stamp));
save(mapFile, 'map', 'dataSet');

if isgraphics(hfig)
    figFile = fullfile(resultsDir, sprintf('xbPlane_%s_%s.fig', erase(motorFile,'.mat'), stamp));
    pngFile = fullfile(resultsDir, sprintf('xbPlane_%s_%s.png', erase(motorFile,'.mat'), stamp));
    savefig(hfig, figFile);
    try
        exportgraphics(hfig, pngFile, 'Resolution', 150);
    catch
        saveas(hfig, pngFile);
    end
end

fprintf('\n[4/4] Summary\n');
fprintf('   x range: [%.3f, %.3f]\n', min(map.xx(:)), max(map.xx(:)));
fprintf('   b range: [%.3f, %.3f]\n', min(map.bb(:)), max(map.bb(:)));
Tvalid = map.T(~isnan(map.T));
if ~isempty(Tvalid)
    fprintf('   T  range: [%.2f, %.2f] Nm\n', min(Tvalid), max(Tvalid));
    [Tmax, idx] = max(Tvalid);
    xVec = map.xx(~isnan(map.T));
    bVec = map.bb(~isnan(map.T));
    fprintf('   Tmax  = %.2f Nm at (x=%.3f, b=%.3f)\n', Tmax, xVec(idx), bVec(idx));
end
if isfield(map,'PF')
    PFvalid = map.PF(~isnan(map.PF));
    if ~isempty(PFvalid)
        fprintf('   PF range: [%.3f, %.3f]\n', min(PFvalid), max(PFvalid));
    end
end
fprintf('   FEAfix raw points: %d\n', numel(map.xRaw));
fprintf('\nSaved: %s\n', mapFile);
end
