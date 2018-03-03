function topup_eddy_pdf_path = topup_eddy_plot(job_dir,dwmri_file,bval_file,mask_file,fsl_path,ADC_fix,zero_bval_thresh,prenormalize,use_all_b0s_topup,topup_params,eddy_name,use_b0s_eddy,eddy_params,normalize,sort_scans,bet_params,acqparams_file,index_file,dwmri_eddy_paths,b0_all_file,b0_topup_paths,fsl_exec)
                                               
    % This will plot outputs of topup/eddy

    % Create "PDF" directory
    pdf_dir = system_utils.directory(job_dir,'PDF');
    pdf_dir.mkdir();
           
    % Load data 
    template_nii = load_untouch_nii(mask_file.get_path());
    dwmri_vol = nifti_utils.load_untouch_nii4D_vol_scaled(dwmri_file.get_path(),'double');
    bvals = bval_file.dlmread();    
    mask_vol = nifti_utils.load_untouch_nii_vol_scaled(mask_file.get_path(),'logical');    
    xform_RAS = nifti_utils.get_voxel_RAS_xform(dwmri_file.get_path());
    acqparams = acqparams_file.dlmread();
    indices = index_file.dlmread();
    if ~isempty(b0_all_file)
        b0_all_vol = nifti_utils.load_untouch_nii4D_vol_scaled(b0_all_file.get_path(),'double');
    end
           
    % Grab data for plotting
    row_vols = {};
    row_descriptions = {};
    [acqparams_unique,~,acqparams_unique_idx] = unique(acqparams,'rows','stable');
    % Add rows for raw b0s input to topup if it was run
    if ~isempty(b0_all_file)
        % topup was run, and acqparams will correspond to b0_all_vol
        for i = 1:size(acqparams_unique,1)            
            row_vols{end+1} = nanmean(b0_all_vol(:,:,:,acqparams_unique_idx == i),4); %#ok<AGROW>
            row_descriptions{end+1} = ['Avg B0 w/ acqparams: [' num2str(acqparams_unique(i,1)) ' ' num2str(acqparams_unique(i,2)) ' ' num2str(acqparams_unique(i,3)) ' ' num2str(acqparams_unique(i,4)) '] x ' num2str(length(find(acqparams_unique_idx == i)))]; %#ok<AGROW>
        end
    end
    % Add row for each shell - including b0, which is preprocessed and will
    % show topup correction.
    bvals_unique = unique(bvals);
    dwmri_mean_files = system_utils.file.empty();
    for i = 1:length(bvals_unique)
        bval_idx = find(bvals == bvals_unique(i));
        row_vols{end+1} = nanmean(dwmri_vol(:,:,:,bval_idx),4); %#ok<AGROW>
        row_descriptions{end+1} = ['preprocessed b-val: ' num2str(bvals_unique(i)) ' x ' num2str(length(bval_idx))]; %#ok<AGROW>
        
        % Save nifti
        dwmri_mean_files(end+1) = system_utils.file(pdf_dir,['dwi_mean_' num2str(bvals_unique(i)) '.nii.gz']); %#ok<AGROW>
        template_nii.img = row_vols{end};
        nifti_utils.save_untouch_nii_using_scaled_img_info(dwmri_mean_files(end).get_path(),template_nii,'double');
    end
    % Last row is a row to overlay segmentations - this shows if shells are
    % aligned with b0.
    row_descriptions{end+1} = 'preprocessed segmentations';   
    % Get FAST segmentations of each mean dwi
    row_vols{end+1} = {nifti_utils.load_untouch_nii_vol_scaled(dwmri_mean_files(1).get_path(),'double')};
    dwmri_mean_files(1).rm();
    for i = 2:length(bvals_unique) % Skip b0
        % Mask out region - use dwi_mean as a template
        dwi_mask_nii = load_untouch_nii(dwmri_mean_files(i).get_path());
        dwi_mask_nii.img = nifti_utils.load_untouch_nii_vol_scaled(dwmri_mean_files(i).get_path(),'double');
        dwi_mask_nii.img(~mask_vol) = 0;
        nifti_utils.save_untouch_nii_using_scaled_img_info(dwmri_mean_files(i).get_path(),dwi_mask_nii,'double');
        
        % Run FSL's FAST
        fast_basename = fullfile(pdf_dir.get_path(),['fast_' num2str(bvals_unique(i))]);
        csf_file = system_utils.file(pdf_dir,['fast_' num2str(bvals_unique(i)) '_pve_0.nii.gz']); % Fast technically thinks the input is T1, so this is what corresponds to CSF
        system_utils.system_with_errorcheck([fsl_exec.get_path('fast') ' -o ' fast_basename ' -v ' dwmri_mean_files(i).get_path()],'Failed to run FAST on averaged DWI');
        
        % Get non-CSF vol
        row_vols{end}{i} = ~(nifti_utils.load_untouch_nii_vol_scaled(csf_file.get_path(),'double') > 0.33) & imerode(mask_vol,ones(3));
                
        % Remove temporary files                
        dwmri_mean_files(i).rm();
        system_utils.file(pdf_dir,['fast_' num2str(bvals_unique(i)) '_mixeltype.nii.gz']).rm();
        system_utils.file(pdf_dir,['fast_' num2str(bvals_unique(i)) '_pve_0.nii.gz']).rm();
        system_utils.file(pdf_dir,['fast_' num2str(bvals_unique(i)) '_pve_1.nii.gz']).rm();
        system_utils.file(pdf_dir,['fast_' num2str(bvals_unique(i)) '_pve_2.nii.gz']).rm();
        system_utils.file(pdf_dir,['fast_' num2str(bvals_unique(i)) '_pveseg.nii.gz']).rm();
        system_utils.file(pdf_dir,['fast_' num2str(bvals_unique(i)) '_seg.nii.gz']).rm();    
    end

    % Get dwmri base plot ------------------------------------------------%   
    [f,pos_header,pos_info,pos_footer] = dwmri_info_plot({'TOPUP/EDDY', ...
                                                         ['   FSL path: ' fsl_path '; exec: ' eddy_name '; ADC fix: ' num2str(ADC_fix) '; bval thresh: ' num2str(zero_bval_thresh) '; prenorm:' num2str(prenormalize) '; all_b0_topup:' num2str(use_all_b0s_topup) '; use_b0s_eddy: ' num2str(use_b0s_eddy) '; norm: ' num2str(normalize), '; sort: ' num2str(sort_scans) '; bet params: ' bet_params], ...
                                                         ['   topup params: ' topup_params], ...
                                                         ['   eddy params: ' eddy_params], ...
                                                         '', ...
                                                         '', ...
                                                         'Justin Blaber', ...
                                                         'justin.blaber@vanderbilt.edu', ...
                                                         'An integrated approach to correction for off-resonance effects and subject movement in diffusion MR imaging (Andersson et al)', ...
                                                         'N/A', ...
                                                         'N/A'}); %#ok<ASGLU>                                                     
                                                     
    % Set up axes --------------------------------------------------------%    
    num_rows = length(row_descriptions);    
    padding = 0.01;
    filenames_height = 0.10;
    view3D_header_height = 0.015;
    view3D_row_width = 1-2*padding;
    view3D_plot_height = (pos_info(2)-(pos_footer(2)+pos_footer(4))-view3D_header_height-filenames_height-(num_rows+3)*padding)/num_rows;
    view3D_text_width = 0.25;
    view3D_text_height = 0.009;
    view3D_text_area_width = view3D_text_width+2*padding;
    view3D_plot_width = (view3D_row_width-view3D_text_area_width-3*padding)/3;
       
    % Create view3D axes
    axes_view3D = struct('axial',{},'coronal',{},'sagittal',{});
    for i = 1:num_rows
        axes_view3D(end+1).axial = axes('Position',[view3D_text_area_width+2*padding pos_footer(2)+pos_footer(4)+filenames_height+(num_rows-i)*(view3D_plot_height+padding)+2*padding view3D_plot_width view3D_plot_height],'xtick',[],'ytick',[],'XColor','w','YColor','w','Parent',f);  %#ok<AGROW>
        axes_view3D(end).coronal = axes('Position',[view3D_text_area_width+view3D_plot_width+3*padding pos_footer(2)+pos_footer(4)+filenames_height+(num_rows-i)*(view3D_plot_height+padding)+2*padding view3D_plot_width view3D_plot_height],'xtick',[],'ytick',[],'XColor','w','YColor','w','Parent',f); 
        axes_view3D(end).sagittal = axes('Position',[view3D_text_area_width+2*view3D_plot_width+4*padding pos_footer(2)+pos_footer(4)+filenames_height+(num_rows-i)*(view3D_plot_height+padding)+2*padding view3D_plot_width view3D_plot_height],'xtick',[],'ytick',[],'XColor','w','YColor','w','Parent',f); 
    end
        
    % These axes are used for plotting stuff between other axes. You have
    % to make an axes over everything to accomplish this.
    axes_overlay = axes('Position',[0 0 1 1],'Color','none','Xlim',[0 1],'Ylim',[0 1],'xtick',[],'ytick',[],'XColor','w','YColor','w','Parent',f);    
    hold(axes_overlay,'on'); % Set hold here
    
    % End of axes --------------------------------------------------------%
    
    % axial, coronal and sagittal headers
    axial_header_pos = [view3D_text_area_width+2*padding pos_info(2)-view3D_header_height-padding view3D_plot_width view3D_header_height];
    uicontrol('style','text','units','normalized','String',{'Axial'},...
        'FontUnits','Normalized','FontSize',1,'FontWeight','bold',...
        'Position',axial_header_pos, ...
        'BackgroundColor',[0.85 0.85 0.85],'Parent',f);
    
    coronal_header_pos = [view3D_text_area_width+view3D_plot_width+3*padding pos_info(2)-view3D_header_height-padding view3D_plot_width view3D_header_height];
    uicontrol('style','text','units','normalized','String',{'Coronal'},...
        'FontUnits','Normalized','FontSize',1,'FontWeight','bold',...
        'Position',coronal_header_pos, ...
        'BackgroundColor',[0.85 0.85 0.85],'Parent',f);
    
    sagittal_header_pos = [view3D_text_area_width+2*view3D_plot_width+4*padding pos_info(2)-view3D_header_height-padding view3D_plot_width view3D_header_height];
    uicontrol('style','text','units','normalized','String',{'Sagittal'},...
        'FontUnits','Normalized','FontSize',1,'FontWeight','bold',...
        'Position',sagittal_header_pos, ...
        'BackgroundColor',[0.85 0.85 0.85],'Parent',f);
    
    % Text descriptions for each row  
    for i = 1:length(row_descriptions)
        row_description_pos = [padding+view3D_text_area_width/2-view3D_text_width/2 pos_footer(2)+pos_footer(4)+filenames_height+(num_rows-i)*(view3D_plot_height+padding)+2*padding+view3D_plot_height/2-view3D_text_height/2 view3D_text_width view3D_text_height];
        uicontrol('style','text','units','normalized','String',row_descriptions{i},...
            'FontUnits','Normalized','FontSize',0.85,'FontWeight','bold',...
            'Position',row_description_pos, ...
            'BackgroundColor',[0.95 0.95 0.95],'Parent',f);
    end
    
    % Format filenames, acqparams, and indices
    for i = 1:length(b0_topup_paths)
        [~,b0_topup_name,b0_topup_ext] = fileparts(b0_topup_paths{i});
        b0_topup_paths{i} = [b0_topup_name b0_topup_ext];
    end
    for i = 1:length(dwmri_eddy_paths)
        [~,dwmri_eddy_name,dwmri_eddy_ext] = fileparts(dwmri_eddy_paths{i});
        dwmri_eddy_paths{i} = [dwmri_eddy_name dwmri_eddy_ext];
    end
    acqparams_strings = {};
    for i = 1:size(acqparams,1)
        acqparams_strings{i} = [num2str(acqparams(i,1)) ' ' num2str(acqparams(i,2)) ' ' num2str(acqparams(i,3)) ' ' num2str(acqparams(i,4))];  %#ok<AGROW>
    end   
    % Get number of adjacent values
    val = [];
    num_val = [];
    for i = 1:length(indices)
        if isempty(val) || (indices(i) ~= val(end))
            % This is a new value
            val(end+1) = indices(i); %#ok<AGROW>
            num_val(end+1) = 1; %#ok<AGROW>
        else
            % We're still in same val
            num_val(end) = num_val(end) + 1;
        end            
    end
    % Create string
    indices_string = '';
    for i = 1:length(val)
        indices_string = [indices_string num2str(val(i)) ' x ' num2str(num_val(i)) '; ']; %#ok<AGROW>
    end
    
    filenames_pos = [padding pos_footer(2)+pos_footer(4)+padding 1-2*padding filenames_height];
    uicontrol('style','text','units','normalized', ...
              'String',{'',['   topup filenames: ' strjoin(b0_topup_paths,', ')], ...
                           ['   eddy filenames: ' strjoin(dwmri_eddy_paths,', ')], ...
                           ['   acqparams: [' strjoin(acqparams_strings,']; [') ']'], ...
                           ['   indices: ' indices_string(1:end-2)]}, ...
              'FontUnits','Normalized','FontSize',10/110,...
              'Position',filenames_pos,'HorizontalAlignment','left',...
              'BackgroundColor',[0.965 0.965 0.965],'Parent',f);
    
    % Make plots - get centroid of mask volume in RAS configuration    
    mask_vol_RAS = nifti_utils.load_untouch_nii_vol_scaled_RAS(mask_file.get_path(),'logical');  
    rp_mask_vol = regionprops(double(mask_vol_RAS),'Centroid','Area');
    centroid = round(rp_mask_vol.Centroid);
    if length(centroid) == 2 % vol might be 1D or 2D by matlabs standards if trailing dimensions are 1
        centroid(3) = 1;
    end
    centroid = centroid([2 1 3]); % (x,y,z) => (j,i,k)
    
    % Plot
    for i = 1:num_rows-1
        % Normalize row_vol for plotting purposes
        row_vol = row_vols{i};
        row_vol_min = prctile(row_vol(mask_vol),5);
        row_vol_max = prctile(row_vol(mask_vol),99);
        row_vol = (row_vol-row_vol_min)./(row_vol_max-row_vol_min);
        
        % Get visualizer
        dv = dwmri_visualizer([], ...
                              row_vol, ...
                              mask_vol, ...
                              xform_RAS, ...
                              'vol');
        % Plot axial
        dv.plot_slice(centroid(3),'axial','slice',[],axes_view3D(i).axial);

        % Plot coronal 
        dv.plot_slice(centroid(2),'coronal','slice',[],axes_view3D(i).coronal);
        
        % Plot sagittal
        dv.plot_slice(centroid(1),'sagittal','slice',[],axes_view3D(i).sagittal);
        
        % set all to axis image
        axis(axes_view3D(i).axial,'image');
        axis(axes_view3D(i).coronal,'image');
        axis(axes_view3D(i).sagittal,'image');
    end
    % Plot outlines    
    b0_vol = row_vols{end}{1};
    b0_vol_min = prctile(b0_vol(mask_vol),5);
    b0_vol_max = prctile(b0_vol(mask_vol),99);
    b0_vol = (b0_vol-b0_vol_min)./(b0_vol_max-b0_vol_min);
    
    dv = dwmri_visualizer(row_vols{end}(2:end), ...
                          b0_vol, ...
                          mask_vol, ...
                          xform_RAS, ...
                          'outlines', ...
                          vertcat(mat2cell(distinguishable_colors(length(row_vols{end}(2:end)),{'w','k'}),ones(1,length(row_vols{end}(2:end))),3)', ...
                                  num2cell(0.25*ones(1,length(row_vols{end}(2:end))))));
                       
    % Plot axial
    dv.plot_slice(centroid(3),'axial','slice',[],axes_view3D(end).axial);

    % Plot coronal 
    dv.plot_slice(centroid(2),'coronal','slice',[],axes_view3D(end).coronal);

    % Plot sagittal
    dv.plot_slice(centroid(1),'sagittal','slice',[],axes_view3D(end).sagittal);

    % set all to axis image
    axis(axes_view3D(end).axial,'image');
    axis(axes_view3D(end).coronal,'image');
    axis(axes_view3D(end).sagittal,'image');
    
    % Plot lines over plots to help check for alignment
    for i = 1:3
        line([view3D_text_area_width+(i-0.5)*view3D_plot_width+(1+i)*padding view3D_text_area_width+(i-0.5)*view3D_plot_width+(1+i)*padding],[pos_footer(2)+pos_footer(4)+filenames_height+2*padding pos_info(2)-view3D_header_height-2*padding],'color',[0 1 0 0.5],'Parent',axes_overlay);
        line([view3D_text_area_width+(i-0.575)*view3D_plot_width+(1+i)*padding view3D_text_area_width+(i-0.575)*view3D_plot_width+(1+i)*padding],[pos_footer(2)+pos_footer(4)+filenames_height+2*padding pos_info(2)-view3D_header_height-2*padding],'color',[0 1 0 0.5],'Parent',axes_overlay);
        line([view3D_text_area_width+(i-0.425)*view3D_plot_width+(1+i)*padding view3D_text_area_width+(i-0.425)*view3D_plot_width+(1+i)*padding],[pos_footer(2)+pos_footer(4)+filenames_height+2*padding pos_info(2)-view3D_header_height-2*padding],'color',[0 1 0 0.5],'Parent',axes_overlay);
    end
        
    % Save pdf
    topup_eddy_pdf_file = system_utils.file(pdf_dir,'topup_eddy.pdf');
    
    % Sometimes figures are saved before everything is "set". This might
    % fix it?
    drawnow
    
    print(f,'-painters','-dpdf','-r600',topup_eddy_pdf_file.get_path());
    
    % Return path
    topup_eddy_pdf_path = topup_eddy_pdf_file.get_path();
end
