function [dwmri_eddy_file,bvec_eddy_file,bval_all_file,b0_mask_mask_file,eddy_params_file,acqparams_file,index_file,dwmri_all_paths,dwmri_all_meta] = eddy(job_dir,dwmri_info,dwmri_files,bvec_files,bval_files,dwmri_meta,bet_params,eddy_params,eddy_name,use_b0s_eddy,topup_output_basename,acqparams_file,b0_all_topup_file,fsl_exec)
    tic

    disp('---');
    disp('Running eddy...');

    % Create eddy directory
    eddy_dir = system_utils.directory(job_dir,'EDDY');
    eddy_dir.mkdir();

    % Check if topup ran
    topup_ran = true;
    if isempty(topup_output_basename)
        topup_ran = false;
    end
    
    % Merge scans --------------------------------------------------------%       
    dwmri_all_paths = {};
    bvecs_all = [];
    bvals_all = [];
    dwmri_all_meta = [];
    for i = 1:length(dwmri_info)     
        if strcmp(dwmri_info(i).scan_descrip,'scan') || use_b0s_eddy
            % This is a scan, or it's a 'b0' and use_b0s_eddy is set to
            % true
            dwmri_all_paths = [dwmri_all_paths dwmri_files(i).get_path()]; %#ok<AGROW>
            bvecs_all = [bvecs_all bvec_files(i).dlmread()]; %#ok<AGROW>
            bvals_all = [bvals_all bval_files(i).dlmread()]; %#ok<AGROW>
            dwmri_all_meta = [dwmri_all_meta dwmri_meta{i}]; %#ok<AGROW>
        end
    end
    
    % Save outputs
    dwmri_all_file = system_utils.file(eddy_dir,'dwmri_all.nii.gz');
    bvec_all_file = system_utils.file(eddy_dir,'dwmri_all.bvec');
    bval_all_file = system_utils.file(eddy_dir,'dwmri_all.bval');
    
    nifti_utils.merge_untouch_nii4D(dwmri_all_paths,dwmri_all_file.get_path());
    bvec_all_file.dlmwrite(bvecs_all,' ');
    bval_all_file.dlmwrite(bvals_all,' ');
    
    % Calculate mask -----------------------------------------------------%
    % If topup ran, then form mask from average of b0_all_topup_file; if 
    % not, then use first b0 in dwmri_file.
    
    b0_file = system_utils.file(eddy_dir,'b0.nii.gz');
    if topup_ran   
        % Take mean of topup corrected b0s
        nifti_utils.mean_untouch_nii4D(b0_all_topup_file.get_path(),b0_file.get_path());
    else
        % Get first b0 in diffusion images
        nifti_utils.idx_untouch_nii4D(dwmri_files(1).get_path(),find(bval_files(1).dlmread() == 0,1),b0_file.get_path());
    end
    
    % Apply bet
    b0_mask_file = system_utils.file(eddy_dir,'b0_mask.nii.gz');
    b0_mask_mask_file = system_utils.file(eddy_dir,'b0_mask_mask.nii.gz');
    system_utils.system_with_errorcheck([fsl_exec.get_path('bet') ' ' b0_file.get_path() ' ' b0_mask_file.get_path() ' -m ' bet_params],'Failed to generate mask with BET');
    
    % Copy info to mask files
    nifti_utils.copyexceptimginfo_untouch_header_only(dwmri_files(1).get_path(),b0_mask_file.get_path());
    nifti_utils.copyexceptimginfo_untouch_header_only(dwmri_files(1).get_path(),b0_mask_mask_file.get_path());        
        
    % Set acqparams.txt --------------------------------------------------%
    if ~topup_ran
        % If topup hasn't run, that means all scans must have the same 
        % phase encoding direction and readout time, so just create a 
        % single entry in the acqparams file.
        acqparam = lib.get_acqparam(dwmri_files(1), ...
                                    dwmri_info(1).pe_dir, ...
                                    dwmri_info(1).readout_time);
               
        acqparams_file = system_utils.file(eddy_dir,'acqparams.txt');
        acqparams_file.dlmwrite(acqparam,' ');
    end
    
    % Set index.txt ------------------------------------------------------%
    % Index is initialized to 1, so if topup hasn't run, it's still
    % correct.    
    index_file = system_utils.file(eddy_dir,'index.txt');
    index_file.dlmwrite([dwmri_all_meta.index],' ');
    
    % eddy ---------------------------------------------------------------%
    eddy_output_basename = fullfile(eddy_dir.get_path(),'eddy_results');
    dwmri_eddy_file = system_utils.file(eddy_dir,'eddy_results.nii.gz');
    bvec_eddy_file = system_utils.file(eddy_dir,'eddy_results.eddy_rotated_bvecs');
    eddy_params_file = system_utils.file(eddy_dir,'eddy_results.eddy_parameters');
    
    % Initialize
    eddy_cmd = [fsl_exec.get_path(eddy_name) ' --imain=' dwmri_all_file.get_path() ' --mask=' b0_mask_mask_file.get_path() ' --acqp=' acqparams_file.get_path() ' --index=' index_file.get_path() ' --bvecs=' bvec_all_file.get_path() ' --bvals=' bval_all_file.get_path() ' --out=' eddy_output_basename ' --verbose ' eddy_params];
    
    % Append topup output if topup was run
    if topup_ran
        eddy_cmd = [eddy_cmd ' --topup=' topup_output_basename];
    end
                
    % Run eddy
    system_utils.system_with_errorcheck(eddy_cmd,'Failed to run eddy');

    % Copy header info to eddy corrected nifti
    nifti_utils.copyexceptimginfo_untouch_header_only(dwmri_files(1).get_path(),dwmri_eddy_file.get_path());
            
    toc
end