# topup_eddy_preprocess
DWMRI preprocessing with topup and eddy

# Installation instructions:
1) Install [FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki)
2) Download [system_utils](https://github.com/justinblaber/system_utils)
3) Download [nifti_utils](https://github.com/justinblaber/nifti_utils)
4) Download [dwmri_visualizer](https://github.com/justinblaber/dwmri_visualizer)
5) (optional) Download example [data](http://justinblaber.org/downloads/dwmri_visualizer/data.zip)
6) Set environment:
```
addpath('~/system_utils');
addpath(genpath('~/nifti_utils'));
addpath(genpath('~/dwmri_visualizer'));
addpath('~/topup_eddy_preprocess');
```
7) Run test on test data:

```
%% Run topup/eddy preprocessing pipeline

% Set job directory path
job_dir_path = 'test_topup_eddy_preprocess';

% Set FSL path
fsl_path = '~/fsl_5_0_10_eddy_5_0_11';

% BET params
bet_params = '-f 0.3 -R';

% Set dwmri_info - this will set base path to nifti/bvec/bval, phase 
% encoding direction, and readout times
dwmri_info(1).base_path = 'scans/1000_32_1';
dwmri_info(1).scan_descrip = 'scan';
dwmri_info(1).pe_dir = 'A';

% ADC fix - apply it for Philips scanner
ADC_fix = true;

% zero_bval_thresh - will set small bvals to zero
zero_bval_thresh = 50;

% prenormalize - will prenormalize data prior to eddy
prenormalize = true;

% use all b0s for topup
use_all_b0s_topup = false;

% topup params
topup_params = ['--subsamp=1,1,1,1,1,1,1,1,1 ' ...
                '--miter=10,10,10,10,10,20,20,30,30 ' ...
                '--lambda=0.00033,0.000067,0.0000067,0.000001,0.00000033,0.000000033,0.0000000033,0.000000000033,0.00000000000067'];

% Sometimes name of eddy is 'eddy', 'eddy_openmp', or 'eddy_cuda'
eddy_name = 'eddy_openmp';

% use b0s in eddy
use_b0s_eddy = false;

% eddy params
eddy_params = '--repol';

% normalize - will normalize data and output a single B0
normalize = true;

% sort scans - will sort scans by b-value
sort_scans = true;

% Set number of threads (only works if eddy is openmp version)
setenv('OMP_NUM_THREADS','20');

% Perform preprocessing
[dwmri_path, bvec_path, bval_path, mask_path, movement_params_path, topup_eddy_pdf_path] = ...
    topup_eddy_preprocess_pipeline(job_dir_path, ...
                                   dwmri_info, ...
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
                                   bet_params);
```
