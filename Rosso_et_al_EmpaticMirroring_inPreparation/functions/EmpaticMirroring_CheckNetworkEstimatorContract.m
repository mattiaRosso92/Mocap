function contract = EmpaticMirroring_CheckNetworkEstimatorContract(config)
%EMPATICMIRRORING_CHECKNETWORKESTIMATORCONTRACT Audit bad-segment support.
%   Artificial dyads save a shared bad_segments vector, but analysis is safe
%   only when the MoCap estimator accepts it and applies it to both covariance
%   matrices. This guard prevents silent analysis with known bad samples.

functionFile = fullfile(config.paths.toolboxRoot,'FREQNESS_Functions', ...
    'FREQNESS_NetworkEstimation_Mocap.m');
assert(isfile(functionFile),'Network estimator not found: %s',functionFile);
source = fileread(functionFile);

optionName = config.network.badSegmentsOptionName;
supportsOption = contains(source,"'" + optionName + "'");
indexesBroadbandCovariance = contains(source, ...
    "cov(broadData(:,idx2cov)')");
indexesNarrowbandCovariance = contains(source, ...
    "cov(narrowData(:,idx2cov)')");
ready = supportsOption && indexesBroadbandCovariance && ...
    indexesNarrowbandCovariance;

if ready
    status = "compatible";
else
    status = "BLOCKED: MoCap estimator lacks complete bad_segments support";
    warning('EmpaticMirroring:MissingMocapBadSegmentsSupport', ...
        ['FREQNESS_NetworkEstimation_Mocap cannot yet consume the saved ' ...
         '''bad_segments'' vector and exclude it from both covariances. ' ...
         'Do not run network estimation until the toolbox is updated.']);
end

contract = table(string(functionFile),optionName,supportsOption, ...
    indexesBroadbandCovariance,indexesNarrowbandCovariance,ready,status, ...
    'VariableNames',{'FunctionFile','RequiredOption', ...
    'SupportsBadSegmentsOption','IndexesBroadbandCovariance', ...
    'IndexesNarrowbandCovariance','ReadyForNetworkEstimation','Status'});

if ~isfolder(config.paths.qcOutputRoot)
    mkdir(config.paths.qcOutputRoot);
end
writetable(contract,fullfile(config.paths.qcOutputRoot, ...
    'network_estimator_contract.csv'));

end
