% eval_xb_point_femm.m
%
% Pick (x,b) = (0.9, 0.5) on the analytical (x,b) plane, translate to a
% concrete dataSet (mirrors SDE_saveMotor.m), draw the geometry in FEMM via
% DrawAndSaveMachine, then run a single-point FEMM simulation via FEMMfitness.

clear; clc; close all;
setupPath;

%% 1. Build dataSet from scratch (the 2 m, p=20 machine)
from_scratch_dataSet;
[dataSet,~,~,~] = back_compatibility(dataSet, [], [], 0);
dataSet.FEAfixN = 0;

%% 2. Compute the analytical (x,b) plane (no FEMM, no plot)
map = xbPlane_analyticalDesign(dataSet);

%% 3. Pick the design point and translate map -> dataSet (cf. SDE_saveMotor.m)
x = 0.9;
b = 0.5;

dataSet.AirGapRadius    = x * dataSet.StatorOuterRadius;
dataSet.ShaftRadius     = interp2(map.xx, map.bb, map.Ar,    x, b);
dataSet.ToothLength     = interp2(map.xx, map.bb, map.lt,    x, b);
dataSet.ToothWidth      = interp2(map.xx, map.bb, map.wt,    x, b);
dataSet.GammaPP         = interp2(map.xx, map.bb, map.gamma, x, b);
dataSet.ThermalLoadKj   = interp2(map.xx, map.bb, map.kj,    x, b);
dataSet.CurrentDensity  = interp2(map.xx, map.bb, map.J,     x, b);
dataSet.AdmiJouleLosses = dataSet.ThermalLoadKj * ...
    (2*pi*dataSet.StatorOuterRadius/1000 * dataSet.StackLength/1000);

if isfield(map,'Ns')
    dataSet.TurnsInSeries = interp2(map.xx, map.bb, map.Ns, x, b);
else
    dataSet.TurnsInSeries = map.geo.win.Ns;
end

% magnet sign convention (SDE_saveMotor.m:59-61)
dataSet.PMdim = -dataSet.PMdimPU ./ dataSet.PMdimPU;
dataSet.PMdim(isnan(dataSet.PMdim)) = 0;
dataSet.PMdim = dataSet.kPM * dataSet.PMdim;

% per-layer barrier hc and dx (single layer here, but generic loop)
hc_pu = zeros(1,dataSet.NumOfLayers);
dx    = zeros(1,dataSet.NumOfLayers);
[m,n] = size(map.xx);
hcTmp = zeros(m,n);
dxTmp = zeros(m,n);
for ii=1:dataSet.NumOfLayers
    for mm=1:m
        for nn=1:n
            hcTmp(mm,nn) = map.hc_pu{mm,nn}(ii);
            dxTmp(mm,nn) = map.dx{mm,nn}(ii);
        end
    end
    hc_pu(ii) = interp2(map.xx, map.bb, hcTmp, x, b);
    dx(ii)    = interp2(map.xx, map.bb, dxTmp, x, b);
end
dataSet.HCpu           = round(hc_pu*100)/100;
dataSet.DepthOfBarrier = round(dx*100)/100;
dataSet.PMdimBouCheck  = 0;

% re-migrate now that fields changed
[dataSet,~,~,~] = back_compatibility(dataSet, [], [], 0);

fprintf('--- Design point (x=%.2f, b=%.2f) ---\n', x, b);
fprintf('  StatorOuterRadius = %.0f mm\n', dataSet.StatorOuterRadius);
fprintf('  AirGapRadius      = %.1f mm\n', dataSet.AirGapRadius);
fprintf('  ShaftRadius       = %.1f mm\n', dataSet.ShaftRadius);
fprintf('  ToothWidth        = %.2f mm\n', dataSet.ToothWidth);
fprintf('  ToothLength       = %.2f mm\n', dataSet.ToothLength);
fprintf('  HCpu              = %s\n', mat2str(dataSet.HCpu,3));
fprintf('  GammaPP           = %.2f deg\n', dataSet.GammaPP);
fprintf('  CurrentDensity    = %.2f A/mm^2\n', dataSet.CurrentDensity);
fprintf('  TurnsInSeries     = %.2f\n', dataSet.TurnsInSeries);
fprintf('  AdmiJouleLosses   = %.0f W\n', dataSet.AdmiJouleLosses);

%% 4. Coarsen mesh and reduce rotor positions for a 2 m machine
%    Default Mesh=5, Mesh_MOOA=10 -> general element ~Mesh/p = 0.25 (way
%    too fine for D=2 m). Default NumOfRotPosPP=15 -> 15 separate solves.
%    Use a feasibility-check single-point sweep instead.
dataSet.Mesh           = 50;   % element size in mm; for D=2 m this gives
                               %   a tractable ~5 s/position solve. Use 20-30
                               %   for design-grade accuracy (slow).
dataSet.Mesh_MOOA      = 2;    % airgap divisor
dataSet.NumOfRotPosPP  = 15;   % 15 positions for a real ripple figure
dataSet.AngularSpanPP  = 60;   % electrical degrees

outDir = checkPathSyntax(fullfile(cd,'results',filesep));
if ~exist(outDir,'dir'); mkdir(outDir); end
motorName = 'machine_x09_b05';
dataSet.currentpathname = outDir;
dataSet.currentfilename = [motorName '.mat'];

fprintf('\n--- Drawing geometry in FEMM ---\n');
dataSet = DrawAndSaveMachine(dataSet, [motorName '.mat'], outDir);
femFile = [outDir motorName '.fem'];
matFile = [outDir motorName '.mat'];
fprintf('Geometry saved to %s\n', femFile);

%% 5. Single-point FEMM simulation
fprintf('\n--- Running FEMMfitness (singt) ---\n');
S = load(matFile,'geo','per','mat');
geo = S.geo; per = S.per; mat = S.mat;

% FEMMfitness with RQ=[] does NOT call calc_i0, so per.i0 would stay at the
% seed-motor RatedCurrent (way too small for a 2 m machine). Recompute i0
% from kj here so the simulated current matches the analytical (x,b) design.
per.flag_OptCurrConst = 0;          % constant kj
per.J    = NaN;                     % force calc_i0 to use kj
per.Loss = NaN;
per      = calc_i0(geo, per, mat);
fprintf('  recomputed i0 from kj=%.0f W/m^2 -> i0 = %.0f Apk (was %.0f Apk)\n', ...
        per.kj, per.i0, dataSet.RatedCurrent);

% knobs for the single point: keep the analytical-design current/gamma
per.overload = 1;
per.gamma    = dataSet.GammaPP;

t0 = tic;
[cost, geoOut, matOut, out, ~] = FEMMfitness([], geo, per, mat, 'singt', femFile);
fprintf('FEMM run time: %.1f s\n', toc(t0));

%% 6. Report
T  = out.SOL.T;
fd = out.SOL.fd;
fq = out.SOL.fq;
fprintf('\n=== FEMM single-point results ===\n');
fprintf('  Rotor positions simulated : %d\n', numel(T));
fprintf('  Mean torque               : %.2f Nm\n', mean(T));
fprintf('  Torque ripple (pk-pk)     : %.2f Nm  (%.1f %% of mean)\n', ...
        max(T)-min(T), 100*(max(T)-min(T))/abs(mean(T)));
fprintf('  Mean fd, fq               : %.4f, %.4f Wb\n', mean(fd), mean(fq));
fprintf('  |Flux linkage|            : %.4f Wb\n', abs(mean(fd)+1i*mean(fq)));
fprintf('  Mean id, iq               : %.2f, %.2f A\n', mean(out.SOL.id), mean(out.SOL.iq));

%% 7. Plot torque vs rotor position
hfig = figure(); figSetting(15,8);
plot(out.SOL.th, T, '-o','LineWidth',1.2);
xlabel('rotor position [elt deg]'); ylabel('Torque [Nm]');
title(sprintf('Single point @ (x=%.2f, b=%.2f), Tavg=%.0f Nm', x, b, mean(T)));
stamp = datestr(now,'yyyymmdd_HHMMSS');
print(hfig, [outDir 'torque_x09_b05_' stamp '.png'], '-dpng', '-r150');
fprintf('\nTorque waveform saved to %storque_x09_b05_%s.png\n', outDir, stamp);
