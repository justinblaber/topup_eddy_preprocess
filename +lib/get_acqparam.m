function acqparam = get_acqparam(nifti_file,pe_dir,readout_time)
    % Gets acqparam. This will convert the PE direction to the corresponding
    % image coordinates which is what topup needs as an input.

    % First, get phase encoding direction with respect to image coordinates
    xform_RAS = nifti_utils.get_voxel_RAS_xform(nifti_file.get_path());
    switch upper(pe_dir)
        case 'R'                
            acqparam = xform_RAS(1,:);  
        case 'L'
            acqparam = -1*xform_RAS(1,:);  
        case 'A'
            acqparam = xform_RAS(2,:); 
        case 'P'
            acqparam = -1*xform_RAS(2,:); 
        case 'S'
            acqparam = xform_RAS(3,:); 
        case 'I'
            acqparam = -1*xform_RAS(3,:); 
    end    
    
    % Set the readout time
    acqparam(4) = readout_time;
end