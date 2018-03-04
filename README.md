# topup_eddy_preprocess
DWMRI preprocessing pipeline with topup and eddy

# Installation instructions:
1) Install [FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki)
2) Download repos and (optional) example data:
```
git clone https://github.com/justinblaber/system_utils.git
git clone https://github.com/justinblaber/nifti_utils.git
git clone https://github.com/justinblaber/dwmri_visualizer.git
git clone https://github.com/justinblaber/topup_eddy_preprocess.git

# Optionally download example data
wget https://justinblaber.org/downloads/github/topup_eddy_preprocess/scans.zip
unzip scans.zip
```
3) In MATLAB:
```
>> addpath('system_utils');
>> addpath(genpath('nifti_utils'));
>> addpath(genpath('dwmri_visualizer'));
>> addpath('topup_eddy_preprocess');
```
If you've downloaded the example data, then run the test:

```
>> test_topup_eddy_preprocess
```
