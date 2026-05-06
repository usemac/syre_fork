% run_xb_plane.m
%
% Headless (x,b) design plane for the syreDefaultMotor (Seg, 1 layer with PMs).
% Builds dataSet from scratch via from_scratch_dataSet.m, runs back_compatibility
% to migrate any post-2014 field additions, then calls eval_xbDesignPlane in
% debug mode (no GUI prompts).

clear; clc; close all;

setupPath;

% 1. populate dataSet from scratch (values mirror motorExamples/syreDefaultMotor.mat)
from_scratch_dataSet;

% 2. ensure every field data0.m expects is present (adds defaults for fields
%    introduced after the snapshot was taken)
[dataSet,~,~,~] = back_compatibility(dataSet, [], [], 0);

% 3. xRange/bRange come from from_scratch_dataSet.m. Override here only if
%    you want to deviate. Wide sweeps can push nodes_rotor_Seg into infeasible
%    corners (oversize shaft radius, negative iron) and the geometry build
%    will throw - keep the window inside what the parametric design can fit.
dataSet.FEAfixN  = 4;       % 4/8/16 enables FEAfix; 0 = pure analytical.

% Coarsen the mesh so the per-FEAfix-point FEMM solves are tractable for the
% 2 m / p=20 machine. With default Mesh=5, each FEAfix solve takes 30+ min.
dataSet.Mesh      = 50;
dataSet.Mesh_MOOA = 50;

% Disable the heavier FEAfix sub-checks (ich iter, short-circuit, demag,
% mech, thermal). Keep only the basic torque/PF saturation correction.
dataSet.syrmDesignFlag.ichf     = 0;
dataSet.syrmDesignFlag.scf      = 0;
dataSet.syrmDesignFlag.demag0   = 0;
dataSet.syrmDesignFlag.demagHWC = 0;
dataSet.syrmDesignFlag.demagUGO = 0;
dataSet.syrmDesignFlag.Mech     = 0;
dataSet.syrmDesignFlag.therm    = 0;

% 4. run the analytical design plane. debug=1 suppresses the questdlg
%    that would otherwise ask the user to pick a motor.
[dataSet, flagS, hfig, map] = eval_xbDesignPlane(dataSet, 1);

% 5. persist the figure and the map alongside it (Octave-compatible)
outDir = fullfile(cd, 'results');
if ~exist(outDir,'dir'); mkdir(outDir); end
stamp  = datestr(now,'yyyymmdd_HHMMSS');
pngFile = fullfile(outDir, ['xb_plane_' stamp '.png']);
matFile = fullfile(outDir, ['xb_plane_' stamp '.mat']);
print(hfig, pngFile, '-dpng', '-r150');               % works in MATLAB and Octave
if isoctave()
    save('-mat7-binary', matFile, 'dataSet', 'map');  % MATLAB-readable .mat
else
    save(matFile, 'dataSet', 'map');
    saveas(hfig, fullfile(outDir, ['xb_plane_' stamp '.fig']));   % MATLAB only
end

fprintf('xb plane saved to %s\n', outDir);
