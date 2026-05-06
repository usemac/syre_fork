% from_scratch_dataSet.m
% Builds the dataSet of motorExamples/syreDefaultMotor.mat from scratch.
% Run as a script: it populates `dataSet` in the workspace.
% After running, call back_compatibility(dataSet,[],[],0) to migrate.

%% Main data
% 2 m-diameter machine, 20 pole pairs, target x = r/R ~= 0.9
dataSet.NumOfPolePairs                 = 20;
dataSet.NumOfSlots                     = 3;     % q (slots/pole/phase)
dataSet.NumOfStatorSlots               = 360;   % Q = 6*p*q*n3ph
dataSet.Num3PhaseCircuit               = 1;
dataSet.AirGapThickness                = 2;     % mm  (was 0.7; too tight for D=2 m)
dataSet.StatorOuterRadius              = 1000;  % mm  (D = 2 m)
dataSet.AirGapRadius                   = 900;   % mm  (r/R = 0.9)
dataSet.ShaftRadius                    = 700;   % mm  (< analytical max ~832 at p=20, x=0.9)
dataSet.StackLength                    = 1000;
dataSet.TypeOfRotor                    = 'Seg';
dataSet.axisType                       = 'PM';

%% Parametric design ranges
dataSet.xRange                         = [0.85 0.95];   % bracket target x = 0.9
dataSet.bRange                         = [0.4 0.6];
dataSet.CurrOverLoad                   = 2;
dataSet.Bfe                            = 1.5;
dataSet.kt                             = 1;
dataSet.RotorYokeFactor                = 1;
dataSet.StatorYokeFactor               = 1;
dataSet.FEAfixN                        = 16;
dataSet.ThermalLoadKj                  = 170987.35528772694;
dataSet.CurrentDensity                 = 36;
dataSet.kPM                            = 1;

%% Stator geometry
dataSet.ToothLength                    = 18.85;
dataSet.ToothWidth                     = 4.35;
dataSet.SlotWidth                      = 4.6;
dataSet.YokeLength                     = 17.999999999999993;
dataSet.ParallelSlotCheck              = 0;
dataSet.StatorSlotOpen                 = 0.275;
dataSet.ToothTangDepth                 = 1;
dataSet.ToothTangAngle                 = 15;
dataSet.FilletCorner                   = 2.5;
dataSet.LinerThickness                 = 0;
dataSet.MagLoadingYoke                 = 0.5;
dataSet.MagLoadingTooth                = 1;

%% Winding
dataSet.SlotFillFactor                 = 0.38000000000000006;
dataSet.SlotLayerPosCheck              = 0;
dataSet.TurnsInSeries                  = 21;
dataSet.Qs                             = 9;
dataSet.PitchShortFac                  = 1;
dataSet.WinMatr                        = [1 1 1 -3 -3 -3 2 2 2; 1 1 1 -3 -3 -3 2 2 2];
dataSet.DefaultWinMatr                 = [1 1 -3 -3 2 2; 1 1 -3 -3 2 2];
dataSet.WinFlag                        = [1 1 1];
dataSet.Active3PhaseSets               = 1;

%% Slot conductor model
dataSet.SlotConductorType              = 'Round';
dataSet.SlotConductorInsulation        = 0.12;
dataSet.SlotConductorParallel          = 18;
dataSet.SlotConductorRadius            = 0.5278443356604071;
dataSet.SlotConductorWidth             = 1.0556886713208142;
dataSet.SlotConductorHeight            = 1.0556886713208142;
dataSet.SlotConductorNumber            = 42;
dataSet.SlotConductorBottomGap         = -1.5;
dataSet.SlotConductorFrequency         = [1 10 50 100 200 300 400 500 600 700 800 900 1000 1100 1200 1300 1400 1500];
dataSet.SlotConductorTemperature       = [20 40 60 80 100 120 140 160 180 200];
dataSet.SlotConductorShape             = 1;

%% Rotor
dataSet.NumOfLayers                    = 1;
dataSet.ALPHApu                        = 0.77;
dataSet.ALPHAdeg                       = 23.1;
dataSet.HCpu                           = 0.45;
dataSet.HCmm                           = 6.64;
dataSet.DepthOfBarrier                 = 0;
dataSet.RadRibCheck                    = 0;
dataSet.RadRibEdit                     = 5.08;
dataSet.RadRibSplit                    = 0;
dataSet.TanRibCheck                    = 0;
dataSet.TanRibEdit                     = 1;
dataSet.CentralShrink                  = 1;
dataSet.RadShiftInner                  = 3.5;
dataSet.NarrowFactor                   = 1;
dataSet.thetaFBS                       = 0;
dataSet.pontRangEdit                   = 0;
dataSet.RotorFilletTan1                = NaN;
dataSet.RotorFilletTan2                = NaN;
dataSet.RotorFilletIn                  = 2.5;
dataSet.RotorFilletOut                 = 1;
dataSet.RotorFilletRadEdit             = 0.4;
dataSet.betaPMshape                    = 0;

%% Induction-motor rotor (used only when TypeOfRotor=IM)
dataSet.NumOfRotorBars                 = 66;
dataSet.RotorToothLength               = 18.85;
dataSet.RotorToothWidth                = 4.35;
dataSet.RotorToothTangDepth            = 1;
dataSet.RotorSlotOpen                  = 0.275;
dataSet.RotorSlotFilletTop             = 2.5;
dataSet.RotorSlotFilletBottom          = 2.5;
dataSet.BarMaterial                    = 'Aluminium';

%% Magnets
dataSet.Br                             = 1.45;
dataSet.Hc                             = 0;
dataSet.BrPP                           = 1.34995;
dataSet.PMtemp                         = 20;
dataSet.tempPP                         = 80;
dataSet.PMdim                          = [0; 20.63];           % column vec: [tang ; vert]
dataSet.PMdimBou                       = [0 1];
dataSet.PMdimBouCheck                  = 0;
dataSet.PMdimPU                        = [0; 0.999736661837046]; % column vec
dataSet.PMNa                           = 1;
dataSet.PMNc                           = [2; 1];                 % column vec
dataSet.PMclear                        = [0.2; 0.2];             % column vec
dataSet.PMdesign.geo.rotor      = [];
dataSet.PMdesign.geo.stator     = [];
dataSet.SimulatedCurrent               = 1604.2852959321187;
dataSet.CurrPM                         = 1;
dataSet.SimIth0                        = NaN;
dataSet.SimIthpk                       = NaN;

%% Sleeve
dataSet.SleeveMaterial                 = 'DW235';
dataSet.SleeveThickness                = 0;
dataSet.SleeveTemperature              = 20;
dataSet.SleeveInterference             = 0;

%% Materials
dataSet.SlotMaterial                   = 'Copper';
dataSet.StatorMaterial                 = 'M270-35A';
dataSet.RotorMaterial                  = 'M270-35A';
dataSet.FluxBarrierMaterial            = 'BMN-52UH';
dataSet.ShaftMaterial                  = 'Air';
dataSet.RotorCondMaterial              = 'Copper';

%% Operating / thermal
dataSet.AdmiJouleLosses                = 16195.754469744425;
dataSet.TargetCopperTemp               = 120;
dataSet.HousingTemp                    = 70;
dataSet.EstimatedCopperTemp            = 874.8758551249515;
dataSet.TempCuLimit                    = 180;
dataSet.TemperatureRiseAbove20         = 0;
dataSet.AmbTemp                        = 50;
dataSet.InitTemp                       = 45;
dataSet.InletTemperature               = 40;
dataSet.HousingType                    = 'Water Jacket (Spiral)';
dataSet.Fluid                          = 'W/G 50/50';
dataSet.FlowRate                       = 6;
dataSet.OverSpeed                      = 18100;
dataSet.RatedCurrent                   = 802.1426479660594;
dataSet.Rs                             = 0.016780570064052373;
dataSet.Lend                           = 6.633035341307349e-06;
dataSet.EndWindingsLength              = 126.79033166805057;
dataSet.MinMechTol                     = 0.4;
dataSet.Mesh                           = 5;
dataSet.Mesh_MOOA                      = 10;
dataSet.mesh_kpm                       = 1;
dataSet.slidingGap                     = 1;

%% Optimization
dataSet.MaxGen                         = 60;
dataSet.XPop                           = 60;
dataSet.SimPoMOOA                      = 5;
dataSet.RotPoMOOA                      = 30;
dataSet.SimPoFine                      = 20;
dataSet.RotPoFine                      = 60;
dataSet.optType                        = 'Design';
dataSet.flag_OptCurrConst              = 0;
dataSet.RMVTmp                         = 'ON';
dataSet.Dalpha1BouCheck                = 0;
dataSet.DalphaBouCheck                 = 0;
dataSet.hcBouCheck                     = 0;
dataSet.DxBouCheck                     = 0;
dataSet.GapBouCheck                    = 0;
dataSet.BrBouCheck                     = 0;
dataSet.AirgapRadiusBouCheck           = 0;
dataSet.ToothWidthBouCheck             = 0;
dataSet.ToothLengthBouCheck            = 0;
dataSet.StatorSlotOpenBouCheck         = 0;
dataSet.ToothTangDepthBouCheck         = 0;
dataSet.GammaBouCheck                  = 0;
dataSet.BetaPMshapeBouCheck            = 0;
dataSet.CentralShrinkBouCheck          = 0;
dataSet.FilletTan1BouCheck             = 0;
dataSet.FilletTan2BouCheck             = 0;
dataSet.FilletRad1BouCheck             = 0;
dataSet.FilletRad2BouCheck             = 0;
dataSet.RadRibBouCheck                 = 0;
dataSet.TanRibBouCheck                 = 0;
dataSet.RadShiftInnerBouCheck          = 0;
dataSet.ThetaFBSBouCheck               = 0;
dataSet.Alpha1Bou                      = [0.25 0.5];
dataSet.DeltaAlphaBou                  = [0.17 0.5];
dataSet.hcBou                          = [0.2 1];
dataSet.DfeBou                         = [-0.75 0.75];
dataSet.GapBou                         = [0.4 0.8];
dataSet.BrBou                          = [0.3 0.38];
dataSet.GapRadiusBou                   = [52 78];
dataSet.ToothWiBou                     = [3.8 6.3];
dataSet.ToothLeBou                     = [15 22.5];
dataSet.StatorSlotOpenBou              = [0.2 0.3];
dataSet.ToothTangDepthBou              = [0.8 1.2];
dataSet.PhaseAngleCurrBou              = [40 75];
dataSet.BetaPMshapeBou                 = [10 89];
dataSet.CentralShrinkBou               = [0 0];
dataSet.FilletTan1Bou                  = [0.4 0.8];
dataSet.FilletTan2Bou                  = [0.4 0.8];
dataSet.FilletRad1Bou                  = [0.4 0.8];
dataSet.FilletRad2Bou                  = [0.4 0.8];
dataSet.RadRibBou                      = [0 0];
dataSet.TanRibBou                      = [0 0];
dataSet.RadShiftInnerBou               = [0 0];
dataSet.ThetaFBSBou                    = [0 15];
dataSet.TorqueOptCheck                 = 0;
dataSet.TorRipOptCheck                 = 0;
dataSet.MassCuOptCheck                 = 0;
dataSet.MaxCuMass                      = 0;
dataSet.MassPMOptCheck                 = 0;
dataSet.MaxPMMass                      = 1.58;
dataSet.PowerFactorOptCheck            = 0;
dataSet.MinExpPowerFactor              = 0;
dataSet.NoLoadFluxOptCheck             = 0;
dataSet.MaxExpNoLoadFlux               = 0;
dataSet.MechStressOptCheck             = 0;
dataSet.MinExpTorque                   = -10;
dataSet.MaxRippleTorque                = 8;
dataSet.syrmDesignFlag.hc         = 1;
dataSet.syrmDesignFlag.dx         = 1;
dataSet.syrmDesignFlag.ks         = 1;
dataSet.syrmDesignFlag.i0         = 1;
dataSet.syrmDesignFlag.gf         = 1;
dataSet.syrmDesignFlag.ichf       = 1;
dataSet.syrmDesignFlag.scf        = 1;
dataSet.syrmDesignFlag.demag0     = 1;
dataSet.syrmDesignFlag.demagHWC   = 1;
dataSet.syrmDesignFlag.mech       = 0;
dataSet.syrmDesignFlag.therm      = 0;

%% Post-processing
dataSet.EvalType                       = 'singt';
dataSet.EvalSpeed                      = 4000;
dataSet.AngularSpanPP                  = 60;
dataSet.GammaPP                        = 145;
dataSet.CurrLoPP                       = 1;
dataSet.NumOfRotPosPP                  = 15;
dataSet.NumGrid                        = 5;
dataSet.MapQuadrants                   = 1;
dataSet.CustomLossMCADCheck            = 0;
dataSet.TransientPeriod                = 60;
dataSet.TransientTimeStep              = 1;
dataSet.TransTime                      = 30;
dataSet.th_eval_type                   = 'Steady State';
dataSet.custom                         = 0;
dataSet.CustomCurrentA                 = NaN;
dataSet.CustomCurrentB                 = NaN;
dataSet.CustomCurrentC                 = NaN;
dataSet.CustomCurrentTime              = NaN;
dataSet.CustomCurrentEnable            = 0;
dataSet.CustomCurrentAnsysCounter      = 1;

%% Computed mass / inertia (filled by data0; included for completeness)
dataSet.MassMagnet                     = 1.6118504314665576;
dataSet.MassRotorBar                   = 0;
dataSet.MassRotorIron                  = 11.926974046867738;
dataSet.MassStatorIron                 = 16.839079172900032;
dataSet.MassWinding                    = 4.628429567709369;
dataSet.RotorInertia                   = 0.03964909437954833;

%% Misc
dataSet.ScaleCheck                     = 0;
dataSet.RQ                             = [];
dataSet.RQnames                        = '';
dataSet.currentpathname                = checkPathSyntax(fullfile(cd,'motorExamples',filesep));
dataSet.currentfilename                = 'syreDefaultMotor.mat';
dataSet.pShape.rotor            = [];
dataSet.pShape.stator           = [];
dataSet.pShape.magnet           = [];
dataSet.pShape.slot             = [];
dataSet.pShape.flag             = 0;
