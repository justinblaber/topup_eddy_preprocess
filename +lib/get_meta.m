function dwmri_meta = get_meta(dwmri_info,dwmri_files)
    % Get meta data which stores the scan number, blip, scan description, 
    % the readout time, and acqparam index per volume.

    dwmri_meta = {};
    for i = 1:length(dwmri_files)        
        % Just load nifti header and cycle over time dimension
        dwmri_nii_hdr = load_untouch_header_only(dwmri_files(i).get_path());          
        
        % Get basename without .nii
        dwmri_basename = strsplit(dwmri_files(i).get_base_name(),'.nii');
        if length(dwmri_basename) ~= 2
            error([dwmri_files(i).get_name() ' must only have a single .nii.gz in the filename. Please fix.']);                
        end
        dwmri_basename = dwmri_basename{1};     
        
        % Store meta data
        dwmri_meta{i} = struct(); %#ok<AGROW>
        for j = 1:dwmri_nii_hdr.dime.dim(5)         
            dwmri_meta{i}(j).name = [dwmri_basename '-x-' num2str(j)];
            dwmri_meta{i}(j).pe_dir = dwmri_info(i).pe_dir;
            dwmri_meta{i}(j).scan_descrip = dwmri_info(i).scan_descrip;
            dwmri_meta{i}(j).readout_time = dwmri_info(i).readout_time;
            dwmri_meta{i}(j).index = 1; % Initialize to 1
        end
    end
end