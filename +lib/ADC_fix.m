function [dwmri_files,bvec_files,bval_files,dwmri_meta] = ADC_fix(dwmri_files,bvec_files,bval_files,dwmri_meta)
    % Perform removal of ADC volume on nifti, bvec, bvals, and dwmri_meta. 
    % Find all zero bvecs with corresponding non-zero b-value and remove 
    % them.

    disp('---');
    disp('Correcting niftis, bvecs, and bvals for ADC removal...');

    for i = 1:length(dwmri_files)
        bvecs = bvec_files(i).dlmread();
        bvals = bval_files(i).dlmread();
        ADC_idxs = ismember(bvecs',[0 0 0],'rows')' & bvals ~= 0;
        if any(ADC_idxs)
            disp(['Trimming ' dwmri_files(i).get_path() ' to remove ADC volume(s): ' num2str(find(ADC_idxs)) '.'])
            
            % Trim and save bval
            bvals = bval_files(i).dlmread();
            bval_files(i).dlmwrite(bvals(1,~ADC_idxs),' ');

            % Trim and save bvec
            bvec_files(i).dlmwrite(bvecs(:,~ADC_idxs),' ');

            % Trim nifti
            nifti_utils.idx_untouch_nii4D(dwmri_files(i).get_path(),find(~ADC_idxs),dwmri_files(i).get_path()); %#ok<FNDSB>
            
            % Trim meta data
            dwmri_meta{i} = dwmri_meta{i}(~ADC_idxs);
        end
    end
end