function [dwmri_file,bvec_file,bval_file,mask_file,eddy_params_file] = finish_preprocessed_dwi(job_dir,dwmri_file,bvec_file,bval_file,mask_file,eddy_params_file,dwmri_meta,normalize,sort_scans)
    disp('---');
    disp('Finishing preprocessing...');

    % Create "preprocessed" directory
    preprocessed_dir = system_utils.directory(job_dir,'PREPROCESSED');
    preprocessed_dir.mkdir();
    
    % Copy data into preprocessed directory since it may get modified
    % in-place
    dwmri_file = dwmri_file.cp(preprocessed_dir,'dwmri.nii.gz');
    bvec_file = bvec_file.cp(preprocessed_dir,'dwmri.bvec');
    bval_file = bval_file.cp(preprocessed_dir,'dwmri.bval');
    mask_file = mask_file.cp(preprocessed_dir,'mask.nii.gz');
    eddy_params_file = eddy_params_file.cp(preprocessed_dir,'eddy_params.txt');
        
    % Load data    
    dwmri_vol = nifti_utils.load_untouch_nii4D_vol_scaled(dwmri_file.get_path(),'double');
    bvecs = bvec_file.dlmread();
    bvals = bval_file.dlmread();
    mask_vol = nifti_utils.load_untouch_nii_vol_scaled(mask_file.get_path(),'logical');
    eddy_params = eddy_params_file.dlmread();
    
    if normalize        
        % Obtain weighted average of b0s ---------------------------------%
        % Get idxs of b0s
        b0_idxs = find(bvals == 0);
        
        % First get mean
        b0_mean_vol  = nanmean(dwmri_vol(:,:,:,b0_idxs),4);
        
        % Get median gains
        b0_gains_median = zeros(1,length(b0_idxs));
        for i = 1:length(b0_idxs)
            % Divide b0 by mean b0 to get gain field, then get the median value
            b0_vol = dwmri_vol(:,:,:,b0_idxs(i));
            b0_gains_median(i) = nanmedian(b0_vol(mask_vol)./b0_mean_vol(mask_vol));
        end

        % Get weighted average (using inverse of median gain) of b0s
        weights = 1./b0_gains_median;
        % Initialize with first b0
        b0_mean_weighted_vol = weights(1) * dwmri_vol(:,:,:,b0_idxs(1));
        for i = 2:length(b0_idxs)
            b0_mean_weighted_vol = b0_mean_weighted_vol + weights(i) * dwmri_vol(:,:,:,b0_idxs(i));
        end
        % Divide by sum of weights
        b0_mean_weighted_vol = b0_mean_weighted_vol/sum(weights);
        
        % Perform normalization with weighted average b0 -----------------%
        b0_ranges = [b0_idxs length(bvals)+1];
        for i = 1:length(b0_ranges)-1
            % Divide by b0
            norm_vols = bsxfun(@rdivide,dwmri_vol(:,:,:,b0_ranges(i):b0_ranges(i+1)-1),dwmri_vol(:,:,:,b0_ranges(i)));

            % Values must be between 0 and 1. 
            norm_vols(norm_vols < 0) = 0; 
            norm_vols(norm_vols > 1) = 1;

            % Store
            dwmri_vol(:,:,:,b0_ranges(i):b0_ranges(i+1)-1) = norm_vols;        
        end   
        % Multiply everything by b0_mean_weighted_vol
        dwmri_vol = bsxfun(@times,dwmri_vol,b0_mean_weighted_vol);
        % Set nonfinte values to 0; I think NaNs were causing fnirt to fail.
        dwmri_vol(~isfinite(dwmri_vol)) = 0; 

        % Remove all other b0s
        dwmri_vol(:,:,:,b0_ranges(2:end-1)) = [];
        bvecs(:,b0_ranges(2:end-1)) = [];
        bvals(b0_ranges(2:end-1)) = [];        
        eddy_params(b0_ranges(2:end-1),:) = [];
        dwmri_meta(b0_ranges(2:end-1)) = [];   
        
        % For dwmri_meta, since b0s are a weighted average, rename it
        dwmri_meta(1).name = 'weighted_average_b0';
    end
    
    if sort_scans
        % Sort bvals first
        [bvals,idx_sorted] = sort(bvals);
        
        % Sort dwi, bvecs, eddy_params, and metadata
        dwmri_vol = dwmri_vol(:,:,:,idx_sorted);
        bvecs = bvecs(:,idx_sorted);
        eddy_params = eddy_params(idx_sorted,:);
        dwmri_meta = dwmri_meta(idx_sorted);     
    end
    
    % Save data
    dwmri_nii = load_untouch_nii(dwmri_file.get_path());
    dwmri_nii.img = dwmri_vol;
    nifti_utils.save_untouch_nii_using_scaled_img_info(dwmri_file.get_path(),dwmri_nii,'double');    
    bvec_file.dlmwrite(bvecs,' ');
    bval_file.dlmwrite(bvals,' ');
    eddy_params_file.dlmwrite(eddy_params,' ');
    dwmri_meta_file = system_utils.file(preprocessed_dir,'dwmri_meta.txt');
    dwmri_meta_file.open('w');
    dwmri_meta_file.printf('%s\n',strjoin({'name', ...
                                           'pe_dir', ...
                                           'scan_descrip', ...
                                           'readout_time', ...
                                           'acqparam_index'},'-x-'));
    for i = 1:length(dwmri_meta)
        dwmri_meta_file.printf('%s\n',strjoin({dwmri_meta(i).name, ...
                                               dwmri_meta(i).pe_dir, ...
                                               dwmri_meta(i).scan_descrip, ...
                                               num2str(dwmri_meta(i).readout_time), ...
                                               num2str(dwmri_meta(i).index)},'-x-'));
    end
    dwmri_meta_file.close();
end