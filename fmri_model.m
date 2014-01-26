function SPM = fmri_model(EXPT,submat)
    
    % First-level GLM analysis.
    %
    % USAGE: SPM = fmri_model(EXPT,[submat])
    %
    % INPUTS:
    %   EXPT object
    %   submat (optional) - vector of subjects to estimate (default: all subjects)
    %
    % OUTPUTS:
    %   SPM - model structure
    %
    % Sam Gershman, Jan 2014
    
    if nargin < 2 || isempty(submat)
        submat = 1:length(EXPT.subject);
    end
    
    cdir = pwd;
    defaults = spm_get_defaults;
    warning off all
    
    % SPM settings
    SPM.xY.RT = EXPT.TR;
    SPM.xBF.T = defaults.stats.fmri.fmri_t;
    SPM.xBF.T0 = defaults.stats.fmri.fmri_t0;
    SPM.xBF.dt = SPM.xY.RT/SPM.xBF.T;
    SPM.xBF.UNITS   = 'secs';     % time units ('scans', 'secs')
    SPM.xBF.name    = 'hrf';      % basis function type
    SPM.xBF.factor = [];
    SPM.xBF.Volterra = 1;
    SPM.xBF = spm_get_bf(SPM.xBF);
    SPM.xGX.iGXcalc = 'none';     % global intensity normalization (note: 'none' actually means 'session-specific')
    SPM.xVi.form    = 'AR(1)';    % correct for serial correlations ('none', 'AR(1)')
    
    for sub = submat;
        
        disp(EXPT.subject(subj).name);
        cd(fullfile(EXPT.analysis_dir,EXPT.subject(subj).name));
        
        % specify functional image files
        for r = 1:length(EXPT.subject(subj).functional)
            SPM.xY.P{r} = fmri_get(EXPT,subj,['sw*-',num2str(EXPT.subject(subj).functional(r)),'-*']);
            SPM.nscan(r) = size(SPM.xY.P{r},1);
        end
        SPM.xY.P = vertcat(SPM.xY.P{:});
        
        %loop through sessions
        for i = 1:length(EXPT.runs(subj).functional)
            
            % load movement regressors
            mrp = fullfile(EXPT.analysis_dir,EXPT.subject(subj),'movement',['rp_',num2str(i)]);
            SPM.Sess(i).C.C = load(mrp);
            for j = 1:size(SPM.Sess(i).C.C,2)
                SPM.Sess(i).C.name{j} = ['movement',num2str(j)];
            end
            
            % load regressor info (names, onsets and durations)
            reg = parse_para(EXPT.subject(subj).para{i},EXPT.TR);
            
            % configure the input structure array
            for j=1:numel(reg.onsets)
                U.name = reg.names{j};
                U.ons  = reg.onsets{j}(:);
                U.dur  = reg.durations(j) .* ones(size(U.ons));
                U.P    = struct('name', 'none', 'h', 0);                
                SPM.Sess(i).U(j) = U;
            end
            
            % high-pass filter
            SPM.xX.K(i).HParam = defaults.stats.fmri.hpf;
        end
        
        delete('mask.img'); % make spm re-use directory without prompting
        SPM = spm_fmri_spm_ui(SPM);
        SPM = spm_spm(SPM);                     %estimate model
    end
    
    cd(cdir);       % return to original directory