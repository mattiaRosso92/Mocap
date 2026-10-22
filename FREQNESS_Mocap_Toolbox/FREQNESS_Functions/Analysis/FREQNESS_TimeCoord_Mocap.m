function [FREQcoord,figures] = FREQNESS_TimeCoord_Mocap( ...
    FREQ,target_frex,varargin)

% ========================================================================
%  FREQ-NESS MOCAP: TEMPORAL COORDINATION
% ========================================================================
%  One public interface for phase-space RQA (default) and joint RQA (JRQA).
%  Phase-space RQA uses one participant time series per group-state dimension;
%  JRQA intersects the separate participant recurrence plots after delay
%  embedding. The methods retain their own preprocessing and threshold rules.
%  Raw time series are the default for phase-space and validated JRQA.
%
% ------------------------------------------------------------------------
%  INPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - FREQ        : NetworkEstimation output with FREQ.ts in
%                  [nComponents x nTime x nFrex x nParticipants] order and
%                  shared or participant-specific FREQ.frex.
%  - target_frex : Anchor frequencies, multiplied by each metric level.
%                  Phase-space: scalar or one value per participant.
%                  JRQA: one value per participant (currently two).
%
%  Shared name-value pairs:
%  - 'method'         : 'phase_space' (default) or 'jrqa'.
%  - 'standardize'    : Logical flag; default false. True subtracts each
%                       retained series' mean and divides by its sample SD.
%                       For phase-space RQA, only valid samples contribute.
%                       Legacy JRQA retains its historical CRP normalization
%                       rules; this flag does not override that old route.
%  - 'component'      : Default 1. Phase-space accepts a scalar or one index
%                       per participant; JRQA currently accepts one scalar.
%  - 'metric_levels'  : Positive anchor-frequency multipliers. Default 1.
%  - 'duration'       : Proportional interval within [0 1]. Default full.
%  - 'theiler_window' : Excluded half-width in analysed samples. Default 0.
%  - 'lmin'/'vmin'    : Minimum diagonal/vertical lengths. Default 2 samples.
%  - 'store_matrices': Retain recurrence/distance matrices. Default false.
%  - 'srate'          : Sampling rate in Hz; default empty. Required for
%                       JRQA filtering/decimation; labels phase-space time.
%
%  Phase-space options (two or more participants):
%  No 'parameters' structure is needed; use the options below directly.
%  - 'threshold_method': 'max_fraction' (default) or 'fixed_rr'.
%  - 'threshold'       : Fraction of maximum group-state distance, or target
%                        group-state RR. Default 0.1.
%  - 'downsample'      : Integer sample stride. Default 1. This does not
%                        anti-alias: filter upstream before decimation.
%  - 'bad_segments'    : Additional shared exclusions, combined with
%                        FREQ.bad_segments without concatenating valid runs.
%  - 'figure'/'animate': Logical flags, default false. Animation supports
%                        two or three participants.
%  - 'animation_pause': Seconds per animation frame. Default 0.01.
%
%  JRQA options (exactly two participants, no marked gaps):
%  - 'parameters'      : Required scalar structure with final scalar m and
%                        tau. Estimate parameters separately with
%                        FREQNESS_JRQAParameters_Mocap; pooling across trials
%                        or conditions is a study decision, not automatic.
%  - 'implementation'  : 'validated' (default) or explicit 'legacy'.
%  - 'threshold_method': 'radius' (default), 'adaptive_max_radius', 'fixed_rr'.
%  - 'threshold'       : Radius/radii, maximum-partner radius fraction, or
%                        target MARGINAL RR. Empty (default) uses JRQA.ps
%                        for radius or JRQA.RadiusFraction for adaptive_max.
%  - 'target_srate'    : Sampling rate after integer decimation; default srate.
%  - 'lowpass_cutoff'  : Anti-alias cutoff in Hz, before decimation. Default [].
%  - 'filter_order'    : Butterworth order. Default 4.
%
%  fixed_rr targets the group RP in phase-space RQA but EACH participant RP
%  in JRQA, not the joint RR. Parameters must be tuned with the same sampling,
%  normalization and preprocessing used for JRQA. Phase-space and JRQA retain
%  their existing selection/decimation order; no preprocessing is added here.
%
% ------------------------------------------------------------------------
%  OUTPUT ARGUMENTS:
% ------------------------------------------------------------------------
%  - FREQcoord : One structure per metric level, retaining the selected
%                method's existing RR, DET, L, ENTR, LAM, TT, Vmax and
%                metadata fields. Phase-space also returns DIV; JRQA also
%                returns Lmax, T1 and T2. Method records the selected method.
%                Phase-space Standardized / JRQA Preprocessing.Standardized
%                records the normalization choice.
%  - figures   : Phase-space figure handles; empty handle arrays for JRQA.
%
%  Examples:
%    FREQcoord = FREQNESS_TimeCoord_Mocap(FREQ,target_frex);
%    FREQcoord = FREQNESS_TimeCoord_Mocap(FREQ,target_frex,'standardize',true);
%    FREQcoord = FREQNESS_TimeCoord_Mocap(FREQ,[f1 f2], ...
%        'method','jrqa','parameters',JRQA);
%
%  TEMPORARY STUDY COMPATIBILITY:
%  The former (FREQ,JRQA,target_frex,...) signature still selects JRQA and
%  defaults to its legacy implementation. Explicit implementation overrides
%  remain supported. Standardization defaults to false in all call forms;
%  use standardize=true explicitly to reproduce previously normalized runs.
%  New code should use the interface above. The old signature will be removed
%  only after the study callers are migrated.
%
% ------------------------------------------------------------------------
%  AUTHORS:
% ------------------------------------------------------------------------
%  Mattia Rosso, Felix Bigand, Leonardo Bonetti
%  mattia.rosso@clin.au.dk
%  felix.bigand@iit.it
%  leonardo.bonetti@clin.au.dk; leonardo.bonetti@psych.ox.ac.uk
%  Center for Music in the Brain, Aarhus University
%  Neuroscience of Perception & Action Lab, Italian Institute of Technology (IIT)
%  Centre for Eudaimonia and Human Flourishing, Linacre College, University of Oxford
%
% ========================================================================


%% Separate method selection from method-specific options

narginchk(2,Inf)
opts = struct('method','phase_space','parameters',[]);
legacy_call = isstruct(target_frex);
if legacy_call
    if isempty(varargin)
        error('The former JRQA signature requires target_frex after JRQA.');
    end
    opts.method = 'jrqa';
    opts.parameters = target_frex;
    target_frex = varargin{1};
    varargin = [{'implementation','legacy'} varargin(2:end)];
end

if mod(numel(varargin),2) ~= 0
    error('Arguments must be given as name-value pairs.');
end
method_arguments = {};
for argi = 1:2:numel(varargin)
    if ~(ischar(varargin{argi}) && isrow(varargin{argi})) && ...
            ~(isstring(varargin{argi}) && isscalar(varargin{argi}))
        error('Optional argument names must be text.');
    end
    name = lower(char(varargin{argi}));
    if isfield(opts,name)
        if legacy_call && strcmp(name,'parameters')
            error('Supply JRQA either positionally or by name, not both.');
        end
        opts.(name) = varargin{argi+1};
    else
        method_arguments(end+1:end+2) = varargin(argi:argi+1);
    end
end
if ~(ischar(opts.method) && isrow(opts.method)) && ...
        ~(isstring(opts.method) && isscalar(opts.method))
    error('method must be ''phase_space'' or ''jrqa''.');
end
method = validatestring(lower(char(opts.method)),{'phase_space','jrqa'});
if legacy_call && ~strcmp(method,'jrqa')
    error('The former JRQA signature cannot select phase-space RQA.');
end


%% Run the selected implementation without retuning parameters

switch method
    case 'phase_space'
        if ~isempty(opts.parameters)
            error('The parameters option is only valid for method ''jrqa''.');
        end
        [FREQcoord,figures] = compute_phase_space_rqa( ...
            FREQ,target_frex,method_arguments{:});
    case 'jrqa'
        if ~isstruct(opts.parameters) || ~isscalar(opts.parameters) || ...
                ~isfield(opts.parameters,'m') || ~isfield(opts.parameters,'tau')
            error('FREQNESS:TimeCoord:MissingJRQA', ...
                ['JRQA requires a scalar ''parameters'' structure with final m and ' ...
                'tau. Estimate and select parameters before calling TimeCoord.']);
        end
        FREQcoord = compute_joint_rqa( ...
            FREQ,opts.parameters,target_frex,method_arguments{:});
        figures = struct('phase_space',gobjects(0), ...
            'distance_matrix',gobjects(0),'recurrence_plot',gobjects(0), ...
            'animation',gobjects(0));
end

end
