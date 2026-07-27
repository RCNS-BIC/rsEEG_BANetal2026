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
addpath /projects/eeg/tools/bids-matlab

clear;
aa_ver5

%% INTIAL
SESSIONS = {'1' 'EyesOpen',   'pre';...
            '1' 'EyesOpen',   'post'; ...
            '1' 'EyesClosed', 'pre'; ...
            '1' 'EyesClosed', 'post';...
            '2' 'EyesOpen',   'pre';...
            '2' 'EyesOpen',   'post'; ...
            '2' 'EyesClosed', 'pre'; ...
            '2' 'EyesClosed', 'post'};

%% RECIPE
aap = aarecipe('meeg_dvs_neuropsych.xml');
SPM = aas_inittoolbox(aap,'spm');
SPM.load;

EL = aas_inittoolbox(aap,'eeglab');
EL.load;
CHANNELFILE = fullfile(EL.dipfitPath,'standard_BESA','standard-10-5-cap385.elp');
EL.close;

% SITE-SPECIFIC CONFIGURATION:
aap.options.wheretoprocess = 'batch'; % queuing system: localsingle, batch, parpool
aap.options.aaparallel.numberofworkers = 20;
aap.options.aaparallel.memory = 4;
aap.options.aaparallel.walltime = 36;
aap.options.symlinks = 1;
aap.options.hardlinks = 0;
aap.options.aaworkerGUI = 0;
aap.options.garbagecollection = 1;
aap.options.diagnostic_videos = 0;

%% PIPELINE
% Directory & sub-directory for analysed data:
aap.acq_details.root = '/projects/eeg';
aap.directory_conventions.analysisid = 'dvs_neuropysch'; 

% Pipeline customisation
aap = aas_addinitialstream(aap,'channellayout',{CHANNELFILE});

aap.tasksettings.aamod_meeg_converttoeeglab.removechannel = 'Status';
aap.tasksettings.aamod_meeg_converttoeeglab.downsample = [250];
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(1).subject = '*';
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(1).session = '*';
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(1).event(1) = struct('type',Inf,'operation','clear'); % remove all markers
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(2).subject = '*';
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(2).session = '*';
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(2).event(1) = struct('type','S  1','operation','insertwithlatency:1'); % marker at the beginning
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(3).subject = '*';
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(3).session = '*';
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(3).event(1) = struct('type','S101','operation','insertwithlatency:-45000'); % = 180s at rate of 250Hz (see line 63); marker at the 3 min or less
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(4).subject = '*';
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(4).session = '*';
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(4).event(1) = struct('type','S 10','operation','inserteachbetween:S  1:2:S101'); % regular markers at every 2 s
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(5).subject = '*';
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(5).session = '*';
aap.tasksettings.aamod_meeg_converttoeeglab.toEdit(5).event(1) = struct('type','S101','operation','ignoreafter'); % discard data after 3 min

aap.tasksettings.aamod_meeg_converttoeeglab.diagnostics.freqrange = [1 120];
aap.tasksettings.aamod_meeg_converttoeeglab.diagnostics.freq = [6 10 50];   

aap.tasksettings.aamod_meeg_filter.hpfreq = 1;
aap.tasksettings.aamod_meeg_filter.bsfreq = cell2mat(arrayfun(@(x) [x-5 x+5]', [50 100], 'UniformOutput', false))';
aap.tasksettings.aamod_meeg_filter.diagnostics = aap.tasksettings.aamod_meeg_converttoeeglab.diagnostics;

for rep = 1:2
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

aap.tasksettings.aamod_meeg_rereference.reference = 'average';
aap.tasksettings.aamod_meeg_rereference.diagnostics = aap.tasksettings.aamod_meeg_converttoeeglab.diagnostics;

aap.tasksettings.aamod_meeg_ica.PCA = 'rank';
aap.tasksettings.aamod_meeg_ica.iterations = 2000;
aap.tasksettings.aamod_meeg_ica.method = 'runica';
aap.tasksettings.aamod_meeg_ica.options.runica.extended = 1;

% Automatic IC rejection using ICLabel label probability (brain > 0.7) and and residual variance (< 0.15) from dipole fitting (if performed).
aap.tasksettings.aamod_meeg_icclassification.method = 'ICLabel';
aap.tasksettings.aamod_meeg_icclassification.criteria.prob = 'Eye<0.7:*Muscle<0.7:*Heart<0.7:*Line Noise<0.7:*Channel Noise<0.7:*Other<0.7';
aap.tasksettings.aamod_meeg_icclassification.diagnostics.freqrange = [1 40; 1 120];


aap.tasksettings.aamod_meeg_timefrequencyanalysis.timefrequencyanalysis.method = 'mtmfft';
aap.tasksettings.aamod_meeg_timefrequencyanalysis.timefrequencyanalysis.taper = 'hanning';
aap.tasksettings.aamod_meeg_timefrequencyanalysis.timefrequencyanalysis.foi = [1:0.2:40 60 70 80 95 110 120];

aap.tasksettings.aamod_meeg_fooof.frequencyrange = [2 40];
aap.tasksettings.aamod_meeg_fooof.bandspecification.band = {'alpha'};
aap.tasksettings.aamod_meeg_fooof.bandspecification.bandbound = {[7 14]};

%% DATA
% Directory for raw data:
aap.directory_conventions.rawmeegdatadir = '/projects/eeg/data/RestState__20251017_BIDS';
aap.directory_conventions.subject_directory_format = 1;
aap.directory_conventions.meegsubjectoutputformat = '%s';

BIDS = bids.layout(aap.directory_conventions.rawmeegdatadir);
pts = struct2table(bids.util.tsvread(fullfile(aap.directory_conventions.rawmeegdatadir,'participants.tsv')));
%pts = pts((pts.age >= 61) & (pts.age <= 70),:);

for sess = 1:size(SESSIONS,1), aap = aas_add_meeg_session(aap,lower(sprintf('%s%s_%s',SESSIONS{sess,2:3}, SESSIONS{sess,1}))); end
allsess = {aap.acq_details.meeg_sessions.name};

for subj = pts.participant_id'
    filter = [];
    filter.sub = regexp(subj{1},'(?<=sub-)[0-9]+','match','once');
    filter.extension = '.edf';

    eegacq = {};
    for sess = 1:size(SESSIONS,1)
        filter.ses = SESSIONS{sess,1};
        filter.task = SESSIONS{sess,2};
        filter.acq =  SESSIONS{sess,3};        
        try eegacq(sess) = bids.query(BIDS,'data', filter); catch, eegacq(sess) = {''}; end
    end
    eegacq = strrep(eegacq,[meeg_findvol(aap,subj{1},'fullpath',true), '/'],'');

    subjtasks = cellfun(@(match) lower(sprintf('%s%s_%s',match{[2:3 1]})), regexp(eegacq(~cellfun(@isempty, eegacq)),'((?<=_ses-)[^_]+)|((?<=_task-)[^_]+)|((?<=_acq-)[a-z]+)','match'), 'UniformOutput',false);

    if any(cellfun(@isempty, eegacq))
        aas_log(aap,false,[subj{1} ' - The numbers of EEG sessions and EEG acquisitions do not match']);
        fprintf('\t Missing sessions: %s\n', strjoin(allsess(~ismember(allsess,subjtasks))));
    end

    aap = aas_addsubject(aap,{subj{1} subj{1}},'functional',eegacq);
    % hack
    if numel(aap.acq_details.subjects(end).seriesnumbers{1}) == numel(SESSIONS)
        aap.acq_details.subjects(end).meegseriesnumbers = aap.acq_details.subjects(end).seriesnumbers;
        aap.acq_details.subjects(end).seriesnumbers{1} = [];
    end % hack
end

%% Epoching (N.B.: no '_' in condition name)
for rep = 1:2
    % Rest
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',rep),'*','*','segment-1','S  1:S101',[0 0]); % whole dataset
    aap = aas_add_meeg_event(aap,sprintf('aamod_meeg_epochs_%05d',rep),'*','*','EPOCH','S 10',0,[0 2000],[]); % 2-s epochs
end

% rest
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00001','*','singlesession:eyesopenpre_1','+1xEPOCH','avg','EOPRERS1');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00001','*','singlesession:eyesopenpost_1','+1xEPOCH','avg','EOPOSTRS1');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00001','*','singlesession:eyesclosedpre_1','+1xEPOCH','avg','ECPRERS1');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00001','*','singlesession:eyesclosedpost_1','+1xEPOCH','avg','ECPOSTRS1');

aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00001','*','singlesession:eyesopenpre_2','+1xEPOCH','avg','EOPRERS2');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00001','*','singlesession:eyesopenpost_2','+1xEPOCH','avg','EOPOSTRS2');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00001','*','singlesession:eyesclosedpre_2','+1xEPOCH','avg','ECPRERS2');
aap = aas_add_meeg_trialmodel(aap,'aamod_meeg_timefrequencyanalysis_00001','*','singlesession:eyesclosedpost_2','+1xEPOCH','avg','ECPOSTRS2');
 
%% RUN
aa_doprocessing(aap);
aa_report(fullfile(aas_getstudypath(aap),aap.directory_conventions.analysisid),[],78); % #78 subject is full
