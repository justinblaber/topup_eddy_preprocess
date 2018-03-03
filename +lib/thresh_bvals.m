function bval_files = thresh_bvals(bval_files,zero_bval_thresh)
    % Sets bvals less than or equal to zero_bval_thresh to zero. This is 
    % done because some acquisitions use small non-zero bvalues for their 
    % B0.

    disp('---');
    disp('Setting small bvalues to zero...');

    for i = 1:length(bval_files)
        bvals = bval_files(i).dlmread();
        bvals(bvals <= zero_bval_thresh) = 0;
        bval_files(i).dlmwrite(bvals,' ');
    end
end