function [topup_output_basename,acqparams_file,b0_all_topup_file,b0_all_file,b0_topup_paths,dwmri_meta] = topup(job_dir,dwmri_info,dwmri_files,bval_files,dwmri_meta,topup_params,use_all_b0s_topup,fsl_exec)
    % Run topup
    tic

    disp('---');
    disp('Running topup...');

    % Create topup directory
    topup_dir = system_utils.directory(job_dir,'TOPUP');
    topup_dir.mkdir();    
    
    % Grab b0s, fill out acqparams, and set dwmri_meta. If use_all_b0s_topup
    % is set, then grab all b0s for topup. If it is not set, then just get 
    % the first unique acqparam per b0, as eddy for 5.0.9+ does not need 
    % topup run on every b0.
    b0_topup_paths = {};
    acqparams = zeros(0,4);    
    for i = 1:length(dwmri_files)
        % Get b0 indices
        b0_idx = find(bval_files(i).dlmread() == 0);        
        if isempty(b0_idx) || b0_idx(1) ~= 1
            error(['First volume in scan: ' dwmri_files(i).get_path() ' is not a b0!']);
        end   
        
        % Get acqparam  
        acqparam = lib.get_acqparam(dwmri_files(i), ...
                                    dwmri_info(i).pe_dir, ...
                                    dwmri_info(i).readout_time);
        
        % Go over each b0 and determine whether or not to add another index
        % into acqparam
        for j = 1:length(b0_idx)                                     
            % Get index            
            if use_all_b0s_topup || all(~ismember(acqparams,acqparam,'rows'))
                % use_all_b0s is set or this is a unique acqparam
                index = size(acqparams,1) + 1;
            else
                % Use previous acqparam
                index = find(ismember(acqparams,acqparam,'rows'));
            end 
            
            % Add new acqparam if index is new
            if index > size(acqparams,1)
                acqparams = vertcat(acqparams,acqparam); %#ok<AGROW>

                % Get basename without .nii
                dwmri_basename = strsplit(dwmri_files(i).get_base_name(),'.nii');
                if length(dwmri_basename) ~= 2
                    error([dwmri_files(i).get_name() ' must only have a single .nii.gz in the filename. Please fix.']);                
                end
                dwmri_basename = dwmri_basename{1};  

                b0_file = system_utils.file(topup_dir,[num2str(index) '_b0_' dwmri_basename '.nii.gz']);
                nifti_utils.idx_untouch_nii4D(dwmri_files(i).get_path(),b0_idx(j),b0_file.get_path());
                b0_topup_paths{end+1} = b0_file.get_path(); %#ok<AGROW>
            end   
            
            % Set index in dwmri_meta
            for k = b0_idx(j):length(dwmri_meta{i})
                dwmri_meta{i}(k).index = index;
            end
        end
    end
    
    % Create acqparams.txt file
    acqparams_file = system_utils.file(topup_dir,'acqparams.txt');
    acqparams_file.dlmwrite(acqparams,' ');
    
    % Get b0s
    b0_all_file = system_utils.file(topup_dir,'b0_all.nii.gz');    
    nifti_utils.merge_untouch_nii4D(b0_topup_paths,b0_all_file.get_path());
        
    % Run topup
    topup_output_basename = fullfile(topup_dir.get_path(),'topup_results');
    b0_all_topup_file = system_utils.file(topup_dir,'b0_all_topup.nii.gz');
    field_file = system_utils.file(topup_dir,'field.nii.gz'); % Useful for debugging phase encode blips and acquisition time if a real fieldmap has been acquired.
    
    % topup
    system_utils.system_with_errorcheck([fsl_exec.get_path('topup') ' --imain=' b0_all_file.get_path() ' --datain=' acqparams_file.get_path() ' --config=b02b0.cnf --out=' topup_output_basename ' --iout=' b0_all_topup_file.get_path() ' --fout=' field_file.get_path() ' --verbose ' topup_params],'Failed to run topup');

    % Copy dwmri_file's header (except img info) to b0_all_topup and 
    % fieldmap since fsl changes some header info
    nifti_utils.copyexceptimginfo_untouch_header_only(dwmri_files(1).get_path(),b0_all_topup_file.get_path());  
    nifti_utils.copyexceptimginfo_untouch_header_only(dwmri_files(1).get_path(),field_file.get_path());  
    
    toc
end