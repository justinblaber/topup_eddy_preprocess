function [dwmri_files,bvec_files,bval_files] = b0_intensity_normalization(dwmri_files,bvec_files,bval_files)
    % Applies intensity normalization based on mean b0 value. This seems 
    % like a somewhat poor fix for doing normalization before calling 
    % topup/eddy, but this was done in the HCP so it should be ok.

    disp('---');
    disp('Applying b0 intensity normalization...');

    for i = 1:length(dwmri_files)                
        dwmri_nii = load_untouch_nii(dwmri_files(i).get_path());   
        dwmri_nii.img = nifti_utils.load_untouch_nii4D_vol_scaled(dwmri_files(i).get_path(),'double');
        
        % Get average b0 value and divide each dwmri by that value until the next b0.
        b0_ranges = [find(bval_files(i).dlmread() == 0) length(bval_files(i).dlmread()) + 1];   
        for j = 1:length(b0_ranges)-1 
            b0_mean = nanmean(reshape(dwmri_nii.img(:,:,:,b0_ranges(j)),1,[]));            
            dwmri_nii.img(:,:,:,b0_ranges(j):b0_ranges(j+1)-1) = dwmri_nii.img(:,:,:,b0_ranges(j):b0_ranges(j+1)-1)./b0_mean;
        end        
        
        % Save
        nifti_utils.save_untouch_nii_using_scaled_img_info(dwmri_files(i).get_path(),dwmri_nii,'double');
    end
end