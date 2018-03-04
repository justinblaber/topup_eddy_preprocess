function [dwmri_all_finished_path, bvec_all_finished_path, bval_all_finished_path, mask_finished_path, eddy_params_finished_path, pdf_path] = topup_eddy_preprocess_pipeline(job_dir_path, dwmri_info, fsl_path, ADC_fix, zero_bval_thresh, prenormalize, use_all_b0s_topup, topup_params, eddy_name, use_b0s_eddy, eddy_params, normalize, sort_scans, bet_params)
    % This is a dwmri preprocessing pipeline that is specifically written
    % to work with FSL 5.0.10 + eddy 5.0.11 (patch). Output nifti will have
    % the same header information as the first dwmri input.
    %
    % INPUTS: 
    %   job_dir_path - path to job directory
    %   dwmri_info - struct('base_path',{},'pe_dir',{},'readout_time',{},'scan_descrip,{});
    %       Note that "readout_time" and "scan_descrip" are optional.
    %       If "readout_time" is omitted, it will be assumed that all 
    %       readout times are the same.    
    %       For "scan_descrip", input can either be "scan" or "b0". If it 
    %       is a b0, all dwi will be trimmed. If "scan_descrip" is omitted,
    %       it is assumed all inputs are of type "scan".
    %           NOTE: First input MUST be a scan and all scans and b0s must
    %           have a b0 as their first volume.
    %   fsl_path - path to fsl installation
    %   ADC_fix - fix for philips scanners to remove ADC component from
    %       niftis/bvecs/bvals
    %   zero_bval_thresh - value set here will threshold bvalues equal to
    %       or below it to zero
    %   prenormalize - if true, performs B0 intensity normalization before
    %       calling topup/eddy
    %   use_all_b0s_topup - if true, topup will use all b0s. If false, then
    %       topup will select the first b0 for each unique acqparam.
    %   topup_params - params to use with topup
    %   eddy_name - name of eddy executable (can be "eddy", "eddy_openmp",
    %       "eddy_cuda", etc...)
    %   use_b0s_eddy - if set to true, this will use scans marked as "b0"
    %       in eddy. Typically these are just used for topup and omitted in
    %       eddy
    %   eddy_params - params to use with eddy
    %   normalize - if true, performs B0 normalization which results in a 
    %       a single B0 output
    %   sort_scans - if true, will sort scans by b-value
    %   bet_params - params to use with bet
    %    
    %   Assumes bvecs are in "radiological voxel convention". Also 
    %   assumes input niftis are in radiological storage orientation.
    %
    %   From FSL documentation:
    %       What conventions do the bvecs use?
    % 
    %       The bvecs use a radiological voxel convention, which is the voxel 
    %       convention that FSL uses internally and originated before NIFTI 
    %       (i.e., it is the old Analyze convention). If the image has a 
    %       radiological storage orientation (negative determinant of 
    %       qform/sform) then the NIFTI voxels and the radiological voxels 
    %       are the same. If the image has a neurological storage 
    %       orientation (positive determinant of qform/sform) then the 
    %       NIFTI voxels need to be flipped in the x-axis (not the y-axis 
    %       or z-axis) to obtain radiological voxels. Tools such as dcm2nii 
    %       create bvecs files and images that have consistent conventions 
    %       and are suitable for FSL. Applying fslreorient2std requires 
    %       permuting and/or changing signs of the bvecs components as 
    %       appropriate, since it changes the voxel axes. 
    % 
    %   Assumes input scans are all the same voxel dimensions, 
    %   resolution, sform, etc... They should be acquired in the same way. 
    % 
    % OUTPUTS: 
    %   Returns absolute paths to preprocessed dwmri, bvec, bval, mask,  
    %   eddy_params, and pdf.
            
    % Use exec_gen to generate full path to fsl executable
    fsl_exec = system_utils.exec_gen(fullfile(fsl_path,'bin'));
    
    % Setup job directory ------------------------------------------------%
    job_dir = system_utils.directory(job_dir_path);
    job_dir.mkdir_with_warning('Files in this directory may get modified in-place.');
    
    % Handle inputs ------------------------------------------------------%
    
    % Handle dwmri_info; check to make sure required fields are there.
    % Optional fields which are omitted will get filled.
    if isempty(dwmri_info)
        error('dwmri_info must have at least one entry');
    end
    
    if ~isfield(dwmri_info,'base_path')
        error('base_path field must be set in dwmri_info');
    end
    
    if ~isfield(dwmri_info,'pe_dir')
        error('pe_dir field must be set in dwmri_info');
    end
    
    if ~isfield(dwmri_info,'readout_time')
        % If omitted, I assume the readout_time for all scans is the same.
        % Set readout time to 0.05 for all scans here; this value works for
        % both topup and eddy.
        for i = 1:length(dwmri_info)
            dwmri_info(i).readout_time = 0.05;
        end        
    end
    
    if ~isfield(dwmri_info,'scan_descrip')
        % If omitted, I assume all inputs are full scans. Set all scan
        % descriptions to "scan"
        for i = 1:length(dwmri_info)
            dwmri_info(i).scan_descrip = 'scan';
        end        
    end
                
    % Check to make sure first input is not a b0
    if strcmp(dwmri_info(1).scan_descrip,'b0')
        error(['First scan cannot be a b0. This is because the first b0 ' ...
               'and the first DWI must correspond to each other. This ' ...
               'ensures the susceptibility field and the eddy current ' ...
               'field are in the same space.']);
    end
                
    % Copy scans into SCANS directory, this is because scans may get
    % modified in-place. If scans are already in SCANS directory then they
    % may get modified in place.
    %   dwmri must have extension: .nii.gz
    %   bvec must have extension: .bvec
    %   bval must have extension: .bval
    scans_dir = system_utils.directory(job_dir,'SCANS');
    scans_dir.mkdir();
    
    dwmri_files = system_utils.file.empty();
    bvec_files = system_utils.file.empty();
    bval_files = system_utils.file.empty();
    for i = 1:length(dwmri_info)   
        % Validate
        dwmri_files(i) = system_utils.file.validate_path([dwmri_info(i).base_path '.nii.gz']);
        bvec_files(i) = system_utils.file.validate_path([dwmri_info(i).base_path '.bvec']);
        bval_files(i) = system_utils.file.validate_path([dwmri_info(i).base_path '.bval']);
        
        % Copy files to scan dir (cp() will do nothing if files are copied
        % onto themselves)
        dwmri_files(i) = dwmri_files(i).cp(scans_dir,dwmri_files(i).get_name());  
        bvec_files(i) = bvec_files(i).cp(scans_dir,bvec_files(i).get_name());
        bval_files(i) = bval_files(i).cp(scans_dir,bval_files(i).get_name());        
    end
    
    % Check to make sure niftis are all compatible (i.e. can be
    % concatenated without changing orientation info). Issue a warning
    % instead of an error since some scanners will output sforms/qforms
    % which are slightly different.
    for i = 2:length(dwmri_files)
        if ~nifti_utils.are_compatible(dwmri_files(1).get_path(),dwmri_files(i).get_path())
            warning(['niftis: ' dwmri_files(1).get_path() ' and ' ...
                     dwmri_files(i).get_path() ' were found to be "incompatible". ' ...
                     'Please check to make sure sform/qform are very ' ...
                     'similar. Output nifti will have header ' ...
                     'information matching first input nifti: ' ...
                     dwmri_files(1).get_path()]);
        end
    end
    
    % Check to make sure niftis are in radiological storage orientation;
    % this is for FSL's sake. If nifti is in radiological storage 
    % orientation, I assume the bvecs are correctly in "radiological voxel 
    % convention". If this is not the case, issue a warning.
    for i = 1:length(dwmri_files)
        if ~nifti_utils.is_radiological_storage_orientation(dwmri_files(i).get_path(), ...
                                                            fsl_exec.get_path('fslorient'))
            warning(['Input nifti: ' dwmri_files(i).get_path() ' ' ...
                     'was found to not be in radiological storage ' ...
                     'orientation. Make sure bvecs are in correct ' ...
                     'orientation for FSL!!!']);
        end
    end
    
    % --------------------------------------------------------------------%
    % Perform scan specific preprocessing --------------------------------%
    % --------------------------------------------------------------------%
    
    % Get meta data ------------------------------------------------------%
    dwmri_meta = lib.get_meta(dwmri_info,dwmri_files);
        
    % ADC fix ------------------------------------------------------------%
    if ADC_fix    
        [dwmri_files,bvec_files,bval_files,dwmri_meta] = ...
            lib.ADC_fix(dwmri_files, ...
                        bvec_files, ...
                        bval_files, ...
                        dwmri_meta);
    end
    
    % Set small bvals to zero --------------------------------------------%
    if zero_bval_thresh > 0       
        bval_files = lib.thresh_bvals(bval_files,zero_bval_thresh);
    end  
    
    % Trim all b0 inputs -------------------------------------------------%
    if any(strcmp({dwmri_info.scan_descrip},'b0'))
        [dwmri_files,bvec_files,bval_files,dwmri_meta] = ...
            lib.trim_b0(dwmri_info, ...
                        dwmri_files, ...
                        bvec_files, ...
                        bval_files, ...
                        dwmri_meta);
    end
    
    % Apply b0 intensity normalization (taken from HCP pipeline) ---------%
    if prenormalize
        [dwmri_files,bvec_files,bval_files] = ...
            lib.b0_intensity_normalization(dwmri_files, ...
                                           bvec_files, ...
                                           bval_files);
    end
                                                            
    % --------------------------------------------------------------------%
    % topup --------------------------------------------------------------%
    % --------------------------------------------------------------------% 
    topup_output_basename = '';    
    acqparams_file = system_utils.file.empty();
    b0_all_topup_file = system_utils.file.empty();
    b0_all_file = system_utils.file.empty();
    b0_topup_paths = {};
    if length(unique({dwmri_info.pe_dir})) > 1 || length(unique([dwmri_info.readout_time])) > 1             
        % Only run topup if there are different PE directions or readout times
        [topup_output_basename,acqparams_file,b0_all_topup_file,b0_all_file,b0_topup_paths,dwmri_meta] = ...
            lib.topup(job_dir, ...
                      dwmri_info, ...
                      dwmri_files, ...
                      bval_files, ...
                      dwmri_meta, ...
                      topup_params, ...
                      use_all_b0s_topup, ...
                      fsl_exec);     
    end
    
    % --------------------------------------------------------------------%
    % eddy ---------------------------------------------------------------%
    % --------------------------------------------------------------------%
    [dwmri_eddy_file,bvec_eddy_file,bval_eddy_file,mask_file,eddy_params_file,acqparams_file,index_file,dwmri_eddy_paths,dwmri_eddy_meta] = ...
        lib.eddy(job_dir, ...
                 dwmri_info, ...
                 dwmri_files, ...
                 bvec_files, ...
                 bval_files, ...
                 dwmri_meta, ...
                 bet_params, ...
                 eddy_params, ...
                 eddy_name, ...
                 use_b0s_eddy, ...
                 topup_output_basename, ...
                 acqparams_file, ...
                 b0_all_topup_file, ...
                 fsl_exec);
                                                                              
    % --------------------------------------------------------------------%
    % Finish preprocessing -----------------------------------------------%
    % --------------------------------------------------------------------%
    % Will optionally perform normalization or sorting of scans by b-value
    [dwmri_all_finished_file,bvec_all_finished_file,bval_all_finished_file,mask_finished_file,eddy_params_finished_file] = ...
        lib.finish_preprocessed_dwi(job_dir, ...
                                    dwmri_eddy_file, ...
                                    bvec_eddy_file, ...
                                    bval_eddy_file, ...
                                    mask_file, ...
                                    eddy_params_file, ...
                                    dwmri_eddy_meta, ...
                                    normalize, ...
                                    sort_scans);
                                
    % --------------------------------------------------------------------%
    % topup/eddy pdf -----------------------------------------------------%
    % --------------------------------------------------------------------%
    pdf_path = lib.topup_eddy_plot(job_dir, ...
                                   dwmri_all_finished_file, ...
                                   bval_all_finished_file, ...  
                                   mask_finished_file, ...
                                   fsl_path, ...
                                   ADC_fix, ...
                                   zero_bval_thresh, ... 
                                   prenormalize, ...
                                   use_all_b0s_topup, ...
                                   topup_params, ...
                                   eddy_name, ...
                                   use_b0s_eddy, ...
                                   eddy_params, ...
                                   normalize, ...
                                   sort_scans, ...
                                   bet_params, ...
                                   acqparams_file, ...
                                   index_file, ...
                                   dwmri_eddy_paths, ...
                                   b0_all_file, ...
                                   b0_topup_paths, ...
                                   fsl_exec);
                                                                                                                               
    % Assign outputs -----------------------------------------------------%
    dwmri_all_finished_path = dwmri_all_finished_file.get_path();
    bvec_all_finished_path = bvec_all_finished_file.get_path();
    bval_all_finished_path = bval_all_finished_file.get_path();
    mask_finished_path = mask_finished_file.get_path();
    eddy_params_finished_path = eddy_params_finished_file.get_path();
end