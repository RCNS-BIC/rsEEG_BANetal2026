% Automatic analysis
% User master script example (aa version 5.*.*)
%
% This script demonstrates a basic EEG pipeline on the LEMON dataset: http://fcon_1000.projects.nitrc.org/indi/retro/MPI_LEMON.html.
% The retrieval of the dataset requires aws-cli
%
% It requires the following software to be configured in your parameterset
%   - SPM
%   - FSL
%   - EEGLAB with extensions Fileio, bva-io, clean_rawdata, AMICA, dipfit, Fieldtrip-lite, firfilt, fitTwoDipoles, ICLabel, Viewprops
%   - FieldTrip
% See aa_parametersets/aap_parameters_defaults_UoS.xml, lines 21-56 for example configuration
%
% N.B.: Time-resolved (CONT branch) aamod_meeg_timefrequencystatistics at source level is disabled because it requires high amount of memory. You can 
% enable it by uncommenting the corresponding lines in the tasklist and this UMS marked with corresponding comment.

addpath /projects/eeg/tools/automaticanalysis

clear;
aa_ver5

%% INTIAL
DATADIR = '/projects/eeg/data/dsdance/BIDS';
SESSIONS = {'restingstate1_pre' 'restingstate2_pre' 'rltask1_pre'...
    'restingstate1_fu1' 'restingstate2_fu1'};

load(fullfile(DATADIR,'../allevents.mat'),'events')

%% RECIPE
aap = aarecipe('meeg_dance.xml');
SPM = aas_inittoolbox(aap,'spm');
SPM.load;

EL = aas_inittoolbox(aap,'eeglab');
EL.load;
CHANNELFILE = fullfile(EL.dipfitPath,'standard_BESA','standard-10-5-cap385.elp');
EL.close;

MRIFILE = fullfile(aap.directory_conventions.fsldir,'data/standard/MNI152_T1_1mm.nii.gz');

% SITE-SPECIFIC CONFIGURATION:
aap.options.wheretoprocess = 'batch'; % queuing system: localsingle, batch, parpool
aap.options.aaparallel.numberofworkers = 20;
aap.options.aaparallel.memory = 4;
aap.options.aaparallel.walltime = 36;
aap.options.aaworkerGUI = 0;
aap.options.garbagecollection = 1;
aap.options.diagnostic_videos = 0;

%% PIPELINE
% Directory & sub-directory for analysed data:
aap.acq_details.root = '/projects/eeg';
aap.directory_conventions.analysisid = 'dance'; 

% Pipeline customisation
aap = aas_addinitialstream(aap,'channellayout',{CHANNELFILE});
aap = aas_addinitialstream(aap,'MNI_1mm',{MRIFILE});
aap.tasksettings.aamod_importfilesasstream(2).unzip = 'gunzip';

aap.tasksettings.aamod_structuralfromnifti.sfxformodality = 'T1w'; % suffix for structural
aap.tasksettings.aamod_segment8.combine = [0.05 0.05 0.05 0.05 0.5 0];
aap.tasksettings.aamod_segment8.writenormimg = 0; % write normialised structural
% aap = aas_renamestream(aap,'aamod_coreg_general_00001','reference','MNI_1mm','input');
% aap = aas_renamestream(aap,'aamod_coreg_general_00001','input','structural','input');
% aap = aas_renamestream(aap,'aamod_coreg_general_00001','output','structural','output');
% aap.tasksettings.aamod_meeg_prepareheadmodel.method = 'simbio';
% aap.tasksettings.aamod_meeg_prepareheadmodel.options.simbio.downsample = 2;
% aap.tasksettings.aamod_meeg_prepareheadmodel.options.simbio.meshshift = 0.1;
% aap.tasksettings.aamod_meeg_preparesourcemodel.method = 'grid';
% aap.tasksettings.aamod_meeg_preparesourcemodel.options.grid.resolution = '10';
aap = aas_renamestream(aap,'aamod_norm_write_00001','structural','MNI_1mm','input');
aap = aas_renamestream(aap,'aamod_norm_write_00001','epi','aamod_structuralfromnifti_00001.structural','input');
aap = aas_renamestream(aap,'aamod_norm_write_00001','epi','structural','output');
aap.tasksettings.aamod_norm_write.bb = [-90 90 -126 91 -72 109];
aap.tasksettings.aamod_norm_write.vox = [1 1 1];

aap.tasksettings.aamod_meeg_converttoeeglab.removechannel = '';
aap.tasksettings.aamod_meeg_converttoeeglab.downsample = [250 250 250 250];
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(1).subject = '*';
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(1).session = 'restingstate1_pre:restingstate2_pre:restingstate1_fu1:restingstate2_fu1';
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(1).event(1) = struct('type','S 10','operation','inserteachbetween:S  1:2:S101'); % regular markers at every 2 s

% replace S 40 (remove no-choice), recode S 49
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(2).subject = '*';
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(2).session = 'rltask1_pre';
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(2).event(1) = struct('type','S 40','operation','remove');
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(3).subject = '*';
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(3).session = 'rltask1_pre';
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(3).event(1) = struct('type','S 49','operation','remove');
for behav = events
    % S 40 - choice
    aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(end+1).subject = ['sub-' behav.subj_id];
    aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(end).session = 'rltask1_pre';
    aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(end).event(1) = struct('type','S 40','operation',['insertwithtime:[' num2str(behav.tstim) ']']);
    % S149 - reward-neutral (negative)
    latencies = behav.tfdbk(behav.condition==1 & behav.feedback==0);
    aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(end+1).subject = ['sub-' behav.subj_id];
    aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(end).session = 'rltask1_pre';
    aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(end).event(1) = struct('type','S149','operation',['insertwithtime:[' num2str(latencies) ']']);
    % S249 - punishment-neutral (positive)
    latencies = behav.tfdbk(behav.condition==2 & behav.feedback==1);
    aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(end+1).subject = ['sub-' behav.subj_id];
    aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(end).session = 'rltask1_pre';
    aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(end).event(1) = struct('type','S249','operation',['insertwithtime:[' num2str(latencies) ']']);
    % keep S 33 only before S 40
    aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(end+1).subject = ['sub-' behav.subj_id];
    aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(end).session = 'rltask1_pre';
    aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(end).event(1) = struct('type','S 33','operation','keepbeforeevent:S 40');
    % recode S 33 according to blocks
    aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(end+1).subject = ['sub-' behav.subj_id];
    aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(end).session = 'rltask1_pre';
    aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(end).event(1) = struct('type','S 33','operation',['prefixpattern:33:[' num2str(behav.block) ']']);
end
aap.tasksettings.aamod_meeg_converttoeeglab.diagnostics.freqrange = [1 120];
aap.tasksettings.aamod_meeg_converttoeeglab.diagnostics.freq = [6 10 50];   

aap.tasksettings.aamod_meeg_filter(1).hpfreq = 1;
aap.tasksettings.aamod_meeg_filter(1).bsfreq = cell2mat(arrayfun(@(x) [x-5 x+5]', [50 100], 'UniformOutput', false))';
aap.tasksettings.aamod_meeg_filter(1).diagnostics = aap.tasksettings.aamod_meeg_converttoeeglab.diagnostics;

for rep = 1:3
    aap.tasksettings.aamod_meeg_cleanartifacts(rep).criteria.Highpass = 'off';
    aap.tasksettings.aamod_meeg_cleanartifacts(rep).criteria.LineNoiseCriterion = 'off';
    aap.tasksettings.aamod_meeg_cleanartifacts(rep).criteria.FlatlineCriterion = 5; % maximum tolerated flatline duration in seconds
    aap.tasksettings.aamod_meeg_cleanartifacts(rep).criteria.ChannelCriterion = 0.8; % minimum channel correlation    
    aap.tasksettings.aamod_meeg_cleanartifacts(rep).criteria.Distance = 'riemannian'; % Riemann adapted processing is a newer method to estimate covariance matrices
    aap.tasksettings.aamod_meeg_cleanartifacts(rep).criteria.BurstRejection = 'off'; % correcting data using ASR instead of removing
    aap.tasksettings.aamod_meeg_cleanartifacts(rep).criteria.WindowCriterion = 0.25; % if more than this % of channels still show above-threshold amplitudes, reject this window (0.05 - 0.3)
    aap.tasksettings.aamod_meeg_cleanartifacts(rep).interpolate = 'spherical';
end
aap.tasksettings.aamod_meeg_cleanartifacts(1).criteria.BurstCriterion = 100; % 5 (recommended by Makoto's pres) is too agressive; 100 according to EEGLAB tutorial
aap.tasksettings.aamod_meeg_cleanartifacts(2).criteria.BurstCriterion = 20; % 5 (recommended by Makoto's pres) is too agressive; 100 according to EEGLAB tutorial
aap.tasksettings.aamod_meeg_cleanartifacts(3).criteria.BurstCriterion = 20; % 5 (recommended by Makoto's pres) is too agressive; 100 according to EEGLAB tutorial

aap.tasksettings.aamod_meeg_rereference.reference = 'average';
aap.tasksettings.aamod_meeg_rereference.diagnostics = aap.tasksettings.aamod_meeg_converttoeeglab.diagnostics;

aap.tasksettings.aamod_meeg_ica.PCA = 'rank';
aap.tasksettings.aamod_meeg_ica.iterations = 2000;
aap.tasksettings.aamod_meeg_ica.method = 'runica';
aap.tasksettings.aamod_meeg_ica.options.runica.extended = 1;

aap.tasksettings.aamod_meeg_dipfit.transformation = CHANNELFILE;
aap.tasksettings.aamod_meeg_dipfit.volumeCondutionModel = fullfile('standard_BESA','standard_BESA.mat');
aap.tasksettings.aamod_meeg_dipfit.rejectionThreshold = 100; % keep all
aap.tasksettings.aamod_meeg_dipfit.constrainSymmetrical = 1;

for task = 1:2 % rest, rltask
    % Automatic IC rejection using ICLabel label probability (brain > 0.7) and and residual variance (< 0.15) from dipole fitting (if performed).
    aap.tasksettings.aamod_meeg_icclassification(task).method = 'ICLabel';
    aap.tasksettings.aamod_meeg_icclassification(task).criteria.prob = 'Eye<0.7:*Muscle<0.7:*Heart<0.7:*Line Noise<0.7:*Channel Noise<0.7:*Other<0.7';
    % aap.tasksettings.aamod_meeg_icclassification.criteria.rv = 0.20;
    aap.tasksettings.aamod_meeg_icclassification(task).diagnostics.freqrange = [1 40; 1 120];
end

% eventmatch for task (_fb)
for rep = 1:2
    aap.tasksettings.aamod_meeg_epochs(2+rep).eventmatch{1} = {'ITI1S1' 'ITI1S2'};
    aap.tasksettings.aamod_meeg_epochs(2+rep).eventmatch{2} = {'ITI2S1' 'ITI2S2'};
    aap.tasksettings.aamod_meeg_epochs(2+rep).eventmatch{3} = {'ITI3S1' 'ITI3S2'};
    aap.tasksettings.aamod_meeg_epochs(2+rep).eventmatch{4} = {'ITI4S1' 'ITI4S2'};

    aap.tasksettings.aamod_meeg_epochs(2+rep).eventmatch{5} = {'FBNEGPRE' 'FBNEGPOST'};
    aap.tasksettings.aamod_meeg_epochs(2+rep).eventmatch{6} = {'FBPOSPRE' 'FBPOSPOST'};
    aap.tasksettings.aamod_meeg_epochs(2+rep).eventmatch{7} = {'FBPUNNEUPRE' 'FBPUNNEUPOST'};
    aap.tasksettings.aamod_meeg_epochs(2+rep).eventmatch{8} = {'FBREWNEUPRE' 'FBREWNEUPOST'};
end

for rep = 1:3
    aap.tasksettings.aamod_meeg_timefrequencyanalysis(rep).timefrequencyanalysis.method = 'mtmfft';
    aap.tasksettings.aamod_meeg_timefrequencyanalysis(rep).timefrequencyanalysis.taper = 'hanning';
    aap.tasksettings.aamod_meeg_timefrequencyanalysis(rep).timefrequencyanalysis.foi = [1:0.2:40 60 70 80 95 110 120];

    aap.tasksettings.aamod_meeg_fooof(rep).frequencyrange = [2 40];
    aap.tasksettings.aamod_meeg_fooof(rep).bandspecification.band = {'alpha'};
    aap.tasksettings.aamod_meeg_fooof(rep).bandspecification.bandbound = {[7 14]};
end

aap.tasksettings.aamod_meeg_timefrequencyanalysis(2).subtracterp = 1;
% aap.tasksettings.aamod_meeg_timefrequencyanalysis(2).bootstrap = 100;

aap.tasksettings.aamod_meeg_timefrequencyanalysis(3).subtracterp = 1;

aap = aas_renamestream(aap,'aamod_meeg_filter_00002','meeg','aamod_meeg_cleanartifacts_00002.meeg','input');
aap.tasksettings.aamod_meeg_filter(2).bpfreq = [7 14]; % same as for FOOOF
aap.tasksettings.aamod_meeg_filter(2).diagnostics = aap.tasksettings.aamod_meeg_converttoeeglab.diagnostics;

aap.tasksettings.aamod_meeg_fei.dfa.windowsize = 5:5:100; % in s
aap.tasksettings.aamod_meeg_fei.dfa.windowoverlap = 0.8;
aap.tasksettings.aamod_meeg_fei.fei.windowsize = 5; % in s
aap.tasksettings.aamod_meeg_fei.fei.windowoverlap = 0.8;

%% DATA
% Directory for raw data:
aap.directory_conventions.rawdatadir = DATADIR;
aap.directory_conventions.rawmeegdatadir = DATADIR;
aap.directory_conventions.subject_directory_format = 1;
aap.directory_conventions.meegsubjectoutputformat = '%s';

for sess = SESSIONS, aap = aas_add_meeg_session(aap,sess{1}); end
for subj = cellstr(spm_select('List',aap.directory_conventions.rawmeegdatadir,'dir','sub-[0-9]{6}'))'
    eegacq = cellstr(spm_select('FPListRec',meeg_findvol(aap,subj{1},'fullpath',true),'.*vhdr'));
    eegacq = strrep(eegacq,[meeg_findvol(aap,subj{1},'fullpath',true), '/'],'');

    subjtasks = cellfun(@(match) sprintf('%s%s_%s',match{[2:3 1]}), regexp(eegacq,'((?<=_ses-)[^_]*)|((?<=_task-)[^_]*)|((?<=_run-)[0-9])','match'), 'UniformOutput',false);
    tmpeegacq = eegacq;
    eegacq = cell(1,numel(SESSIONS));
    [~,indSess,indData] = intersect(SESSIONS, subjtasks);
    eegacq(indSess) = tmpeegacq(indData);

    if any(cellfun(@isempty, eegacq))
        aas_log(aap,false,[subj{1} ' - The numbers of EEG sessions and EEG acquisitions do not match']); 
        fprintf('\t Missing sessions: %s\n', strjoin(SESSIONS(~ismember(SESSIONS,subjtasks))));
    end

    mriacq = cellstr(spm_select('FPListRec',mri_findvol(aap,subj{1},'fullpath',true),'.*_T1w.nii.gz')); % fullfile for MRI
    if numel(mriacq) ~= 1, aas_log(aap,false,'There MUST be one structural MRI acquisition'); end
    aap = aas_addsubject(aap,{subj{1} subj{1}},'structural',mriacq,'functional',eegacq);
    % hack
    if numel(aap.acq_details.subjects(end).seriesnumbers{1}) == numel(SESSIONS)
        aap.acq_details.subjects(end).meegseriesnumbers = aap.acq_details.subjects(end).seriesnumbers; 
        aap.acq_details.subjects(end).seriesnumbers{1} = []; 
    end % hack
end

%% Exclude data
% missing T1 (sub-621333)
aap.acq_details.subjects(arrayfun(@(subj) isempty(subj.structural{1}{1}), aap.acq_details.subjects)) = [];

% % based on QA (nEpoch < 30)
% nMinEpoch = struct(...
%     'restingstate1_pre',30, ...
%     'restingstate2_pre',30, ...
%     'rltask1_pre_FBNEGCHOICE',30, ...
%     'rltask1_pre_FBNEGPRE',5, ...
%     'rltask1_pre_FBNEGPOST',5, ...
%     'rltask1_pre_FBPOSCHOICE',30, ...
%     'rltask1_pre_FBPOSPRE',5, ...
%     'rltask1_pre_FBPOSPOST',5, ...
%     'rltask1_pre_FBPUNNEUCHOICE',30, ...
%     'rltask1_pre_FBPUNNEUPRE',5, ...
%     'rltask1_pre_FBPUNNEUPOST',5, ...
%     'rltask1_pre_FBREWNEUCHOICE',30, ...
%     'rltask1_pre_FBREWNEUPRE',5, ...
%     'rltask1_pre_FBREWNEUPOST',5, ...
%     'restingstate1_fu1',30, ...
%     'restingstate2_fu1',30 ...
%     );
% load ../qa/check_epochs.mat nEpochs
% EXCLUDEDATA = {};
% for ep = nEpochs.Properties.VariableNames
%     session = regexp(ep{1},'[^_]*((_pre)|(_fu1))','match','once');
%     EXCLUDEDATA = [EXCLUDEDATA;...
%         fullfile(nEpochs(nEpochs.(ep{1})<nMinEpoch.(ep{1}),:).Properties.RowNames, session)];
% end

% % EXCLUDEDATA = [EXCLUDEDATA; ...
EXCLUDEDATA = [...
    {'sub-393563/restingstate2_fu1'};... % empty after 1st clean
    {'sub-571772/restingstate2_pre'};... % empty after 1st clean
    {'sub-411707/restingstate2_pre'};... % empty after 1st clean
    {'sub-393563/restingstate2_pre'};... % empty after 2st clean
    {'sub-030786/rltask1_pre'};... % bad performance
    {'sub-109911/rltask1_pre'};... % bad performance
    {'sub-253743/rltask1_pre'};... % bad performance
    {'sub-645028/rltask1_pre'};... % bad performance
    {'sub-959061/rltask1_pre'};... % measurement terminated
    {'sub-979903/rltask1_pre'};... % bad performance
    {'sub-209909/rltask1_pre'};... % empty after 1st clean
    {'sub-393563/rltask1_pre'};... % empty after 1st clean
    {'sub-573722/rltask1_pre'};... % empty after 1st clean
    {'sub-720560/rltask1_pre'};... % empty after 1st clean
    {'sub-811704/rltask1_pre'};... % empty after 1st clean
    {'sub-866062/rltask1_pre'};... % empty after 1st clean
    {'sub-887169/rltask1_pre'};... % empty after 1st clean 
    % {'sub-328594/rltask1_pre'};... % emptymatch (ITI4) after 1st clean
    % {'sub-490625/rltask1_pre'};... % emptymatch (FBNEG) after 1st clean
    % {'sub-527569/rltask1_pre'};... % emptymatch (FBNEG) after 1st clean
    ];

EXCLUDEDATA = unique(EXCLUDEDATA);
EXCLUDEDATA = cellfun(@(c) strsplit(c,'/'), EXCLUDEDATA, 'UniformOutput',false);

exclSubj = [];
for excl = EXCLUDEDATA'
    subjInd = find(strcmp({aap.acq_details.subjects.subjname},excl{1}{1}));
    if isempty(subjInd), continue; end
    sessInd = find(strcmp({aap.acq_details.meeg_sessions.name},excl{1}{2}));
    aap.acq_details.subjects(subjInd).meegseriesnumbers{1}{sessInd} = [];
    if isempty(aap.acq_details.subjects(subjInd).meegseriesnumbers{1}), exclSubj(end+1) = subjInd; end
end
aap.acq_details.subjects(exclSubj) = [];

% check subjects with tasks == behav
tasks = arrayfun(@(subj) subj.meegseriesnumbers{1}(strcmp({aap.acq_details.meeg_sessions.name},'rltask1_pre')), aap.acq_details.subjects);
tasks = tasks(cellfun(@(sess) ~isempty(sess), tasks));
subjs = cellfun(@(sess) regexp(sess,'(?<=sub-)[0-9]{6}','match','once'), tasks, 'UniformOutput',false);
assert(all(ismember(subjs, {events.subj_id})))

%% Epoching (N.B.: no '_' in condition name)
for rep = 1:2
    % Rest
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',rep),'*','restingstate1_pre','segment-1','S  1:S101',[0 0]); % whole dataset
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',rep),'*','restingstate1_pre','EPOCH','S 10',0,[0 2000],[]); % 2-s epochs
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',rep),'*','restingstate2_pre','segment-1','S  1:S101',[0 0]); % whole dataset
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',rep),'*','restingstate2_pre','EPOCH','S 10',0,[0 2000],[]); % 2-s epochs
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',rep),'*','restingstate1_fu1','segment-1','S  1:S101',[0 0]); % whole dataset
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',rep),'*','restingstate1_fu1','EPOCH','S 10',0,[0 2000],[]); % 2-s epochs
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',rep),'*','restingstate2_fu1','segment-1','S  1:S101',[0 0]); % whole dataset
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',rep),'*','restingstate2_fu1','EPOCH','S 10',0,[0 2000],[]); % 2-s epochs
    
    % Task
    % aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',2+rep),'*','rltask1_pre','CHOICE','S 40',34,[-1000 2000],[]); % 3-s epochs
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',2+rep),'*','rltask1_pre','ITI1S1','S 133',34,[0 1000],[]); % 1-s epochs
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',2+rep),'*','rltask1_pre','ITI1S2','S 133',34,[1000 2000],[]); % 1-s epochs
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',2+rep),'*','rltask1_pre','ITI2S1','S 233',34,[0 1000],[]); % 1-s epochs
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',2+rep),'*','rltask1_pre','ITI2S2','S 233',34,[1000 2000],[]); % 1-s epochs
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',2+rep),'*','rltask1_pre','ITI3S1','S 333',34,[0 1000],[]); % 1-s epochs
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',2+rep),'*','rltask1_pre','ITI3S2','S 333',34,[1000 2000],[]); % 1-s epochs
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',2+rep),'*','rltask1_pre','ITI4S1','S 433',34,[0 1000],[]); % 1-s epochs
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',2+rep),'*','rltask1_pre','ITI4S2','S 433',34,[1000 2000],[]); % 1-s epochs
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',2+rep),'*','rltask1_pre','FBPOSPRE','S 48',34,[-1000 0],[]); % 1-s epochs
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',2+rep),'*','rltask1_pre','FBPOSPOST','S 48',34,[0 1000],[]); % 1-s epochs
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',2+rep),'*','rltask1_pre','FBREWNEUPRE','S149',34,[-1000 0],[]); % 1-s epochs
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',2+rep),'*','rltask1_pre','FBREWNEUPOST','S149',34,[0 1000],[]); % 1-s epochs
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',2+rep),'*','rltask1_pre','FBPUNNEUPRE','S249',34,[-1000 0],[]); % 1-s epochs
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',2+rep),'*','rltask1_pre','FBPUNNEUPOST','S249',34,[0 1000],[]); % 1-s epochs
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',2+rep),'*','rltask1_pre','FBNEGPRE','S 50',34,[-1000 0],[]); % 1-s epochs
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',2+rep),'*','rltask1_pre','FBNEGPOST','S 50',34,[0 1000],[]); % 1-s epochs
end

% rest
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00001','*','singlesession:restingstate1_pre','+1xEPOCH','avg','PRERS1');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00001','*','singlesession:restingstate2_pre','+1xEPOCH','avg','PRERS2');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00001','*','singlesession:restingstate1_fu1','+1xEPOCH','avg','FU1RS1');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00001','*','singlesession:restingstate2_fu1','+1xEPOCH','avg','FU1RS2');
 
% task
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00002','*','singlesession:rltask1_pre','+1xITI1S1','avg','ITI1S1');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00002','*','singlesession:rltask1_pre','+1xITI1S2','avg','ITI1S2');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00002','*','singlesession:rltask1_pre','+1xITI2S1','avg','ITI2S1');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00002','*','singlesession:rltask1_pre','+1xITI2S2','avg','ITI2S2');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00002','*','singlesession:rltask1_pre','+1xITI3S1','avg','ITI3S1');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00002','*','singlesession:rltask1_pre','+1xITI3S2','avg','ITI3S2');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00002','*','singlesession:rltask1_pre','+1xITI4S1','avg','ITI4S1');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00002','*','singlesession:rltask1_pre','+1xITI4S2','avg','ITI4S2');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00002','*','singlesession:rltask1_pre','+1xFBPOSPRE','bootstrap','PREFBPOSPRE');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00002','*','singlesession:rltask1_pre','+1xFBPOSPOST','bootstrap','PREFBPOSPOST');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00002','*','singlesession:rltask1_pre','+1xFBREWNEUPRE','bootstrap','PREFBREWNEUPRE');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00002','*','singlesession:rltask1_pre','+1xFBREWNEUPOST','bootstrap','PREFBREWNEUPOST');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00002','*','singlesession:rltask1_pre','+1xFBPUNNEUPRE','bootstrap','PREFBPUNNEUPRE');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00002','*','singlesession:rltask1_pre','+1xFBPUNNEUPOST','bootstrap','PREFBPUNNEUPOST');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00002','*','singlesession:rltask1_pre','+1xFBNEGPRE','bootstrap','PREFBNEGPRE');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00002','*','singlesession:rltask1_pre','+1xFBNEGPOST','bootstrap','PREFBNEGPOST');

%% RUN
aa_doprocessing(aap);
aa_report(fullfile(aas_getstudypath(aap),aap.directory_conventions.analysisid),[],78); % #78 subject is full