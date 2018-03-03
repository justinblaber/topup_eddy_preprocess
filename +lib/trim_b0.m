function [dwmri_files,bvec_files,bval_files,dwmri_meta] = trim_b0(dwmri_info,dwmri_files,bvec_files,bval_files,dwmri_meta)
    % All inputs marked as "b0" will get dwi trimmed. Sometimes b0s are 
    % acquired with a couple extra gradient directions which eddy might
    % mistake as DSI (and doesn't support).

    disp('---');
    disp('Trimming b0 inputs...');

    for i = 1:length(dwmri_info)
        if strcmp(dwmri_info(i).scan_descrip,'b0')
            bvals = bval_files(i).dlmread();
            if any(bvals ~= 0)
                % Trim to keep b0
                b0_idx = find(bvals == 0);

                disp(['Trimming b0 scan: ' dwmri_files(i).get_path() ' to keep B0 volume(s): ' num2str(b0_idx)])

                % Trim and save bval
                bval_files(i).dlmwrite(bvals(b0_idx),' ');

                % Trim and save bvec
                bvecs = bvec_files(i).dlmread();
                bvec_files(i).dlmwrite(bvecs(:,b0_idx),' ');

                % Trim and save nifti           
                nifti_utils.idx_untouch_nii4D(dwmri_files(i).get_path(),b0_idx,dwmri_files(i).get_path());

                % Trim meta data
                dwmri_meta{i} = dwmri_meta{i}(b0_idx);
            end
        end
    end
end
