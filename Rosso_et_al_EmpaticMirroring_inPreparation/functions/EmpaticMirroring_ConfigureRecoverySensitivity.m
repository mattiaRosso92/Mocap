function [recoveredConfig,combinedConfig] = ...
    EmpaticMirroring_ConfigureRecoverySensitivity(primaryConfig)
%EMPATICMIRRORING_CONFIGURERECOVERYSENSITIVITY Isolate sensitivity outputs.
%   RECOVEREDCONFIG is used only for newly admitted recordings. COMBINEDCONFIG
%   receives lightweight primary-plus-recovered summaries and never points
%   any generated output at the primary analysis tree.

if ~isstruct(primaryConfig) || ~isfield(primaryConfig,'sensitivity') || ...
        ~isfield(primaryConfig.sensitivity,'output_root')
    error('EmpaticMirroring:SensitivityConfiguration', ...
        'The recovery-sensitivity configuration is incomplete.');
end

sensitivityRoot = string(primaryConfig.sensitivity.output_root);
recoveredRoot = fullfile(sensitivityRoot,'RecoveredOnly');
combinedRoot = fullfile(sensitivityRoot,'CombinedPrimaryPlusRecovered');

recoveredConfig = redirectOutputs(primaryConfig,recoveredRoot);
recoveredConfig.paths.qcOutputRoot = fullfile(sensitivityRoot,'qc');
combinedConfig = redirectOutputs(primaryConfig,combinedRoot);
combinedConfig.paths.qcOutputRoot = fullfile(sensitivityRoot,'qc');

overwrite = primaryConfig.sensitivity.overwrite;
recoveredConfig.dyads.overwrite = overwrite;
recoveredConfig.block1.overwrite_flag = overwrite;
recoveredConfig.block2.overwrite_flag = overwrite;
recoveredConfig.block3.overwrite_flag = overwrite;
recoveredConfig.block4.overwrite_flag = overwrite;
recoveredConfig.block5.overwrite_flag = overwrite;
recoveredConfig.block6.overwrite_flag = overwrite;
combinedConfig.block5.overwrite_flag = overwrite;
combinedConfig.block6.overwrite_flag = overwrite;

end


function config = redirectOutputs(config,outputRoot)

config.paths.outputRoot = char(outputRoot);
config.paths.modelOutputRoot = fullfile(outputRoot,'preprocessed_models');
config.paths.participantsOutputRoot = fullfile(outputRoot,'participants');
config.block2.output_path = fullfile(outputRoot,'02_Landscape');
config.block3.output_path = fullfile(outputRoot,'03_Coordination');
config.block4.output_path = fullfile(outputRoot,'04_PhaseSpaceRQA');
config.block5.output_path = fullfile(outputRoot,'05_Group');
config.block5.figure_path = fullfile(config.block5.output_path,'Figures');
config.block6.output_path = fullfile(outputRoot,'06_Statistics_R');

end
