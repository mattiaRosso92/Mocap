function [FREQrqa,figures] = FREQNESS_PhaseSpaceRQA_Mocap( ...
    FREQ,target_frex,varargin)

% FREQNESS_PHASESPACERQA_MOCAP Temporary entry point for unmigrated studies.
% Use FREQNESS_TimeCoord_Mocap(FREQ,target_frex,...) in new code; its default
% method is phase_space. This entry point delegates to the same private
% implementation and retains the former phase-space arguments and outputs.
% Standardization now defaults to false; set 'standardize',true explicitly
% when reproducing a previously standardized analysis. See the TimeCoord
% header for complete phase-space options and output documentation.
%
% Authors: Mattia Rosso, Felix Bigand, Leonardo Bonetti
% mattia.rosso@clin.au.dk; felix.bigand@iit.it
% leonardo.bonetti@clin.au.dk; leonardo.bonetti@psych.ox.ac.uk

[FREQrqa,figures] = compute_phase_space_rqa( ...
    FREQ,target_frex,varargin{:});

end
