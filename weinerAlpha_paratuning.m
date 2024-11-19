% demo to run RL deconvolution with conventional and OMW methods
% 
% Note: please make sure your GPU has at least 32 GB available vRAM for
% deconvolution on GPU to avoid out-of-memory issue; otherwise, you may run CPU deconvolution.
%
% The parameters demonstrated here are usually a subset of those available 
% for the functions, with the rest using default values. For a comprehensive 
% list of parameters and their defaults, please see the function's parameter 
% list (or input parser) or refer to the parameter documentation (major_functions_documentation.txt).


clear, clc;

fprintf('Deconvolution demo...\n\n');

% move to the PetaKit5D root directory
curPath = pwd;
if ~endsWith(curPath, 'PetaKit5D')
    mfilePath = mfilename('fullpath');
    if contains(mfilePath,'LiveEditorEvaluationHelper')
        mfilePath = matlab.desktop.editor.getActiveFilename;
    end
    
    mPath = fileparts(mfilePath);
    if endsWith(mPath, 'demos')
        cd(mPath);
        cd('..')
    end
end

setup();


%% Step 1: get our demo data from zenodo/Dropbox (skip this step if the data is already downloaded)
% download the example dataset from zenodo (https://doi.org/10.5281/zenodo.1492027) manually, 
% or use the code below to download the data from Dropbox
% if ispc
%     destPath = fullfile(getenv('USERPROFILE'), 'Downloads');
%     destPath = strrep(destPath, '\', '/');
% else
%     destPath = '~/Downloads/';
% end
% demo_data_downloader(destPath);
% 
% dataPath = [destPath, '/PetaKit5D_demo_cell_image_dataset/'];


%% Step 2: test the parameter for OMW backward projector
dataPath = 'C:\Users\umaim\Downloads\PetaKit5D-main\'
% Cam A
psfFn = [dataPath, 'CamB_ch0_Gaussian_PSF_3d_px_108nm_0lambda.tif'];
% OTF thresholding parameter
OTFCumThresh = 0.88;
% true if the PSF is in skew space
skewed = true;
XR_visualize_OTF_mask_segmentation(psfFn, OTFCumThresh, skewed);


%% 

% Cam B
psfFn = [dataPath, 'CamB_ch0_Gaussian_PSF_3d_px_108nm_0lambda.tif'];
% OTF thresholding parameter
%%OTFCumThresh = 0.88;
OTFCumThresh = 0.88;
% true if the PSF is in skew space
skewed = true;
XR_visualize_OTF_mask_segmentation(psfFn, OTFCumThresh, skewed);


%% Step 3: OMW deconvolution 
%% Step 3.1: set parameters 
% add the software to the path
setup([]);

% root path
rt = dataPath;
% data path for data to be deconvolved, also support for multiple data folders
dataPaths = {[rt, 'rawdata_Gaussian']};

% xy pixel size in um
xyPixelSize = 0.108;
% z step size
dz = 0.3;
% scan direction
Reverse = true;
% psf z step size (we assume xyPixelSize also apply to psf)
dzPSF = 0.3;

% if true, check whether image is flipped in z using the setting files
parseSettingFile = false;

% channel patterns for the channels, the channel patterns should map the
% order of PSF filenames.
ChannelPatterns = {'CamB_ch0', ...
                   };  

% psf path
psf_rt = rt;            
PSFFullpaths = {
                [psf_rt, 'CamB_ch0_Gaussian_PSF_3d_px_108nm_0lambda.tif'], ...
                };            

% RL method
RLmethod = 'omw';
% wiener filter parameter
% alpha parameter should be adjusted based on SNR and data quality.
% typically 0.002 - 0.01 for SNR ~20; 0.02 - 0.1 or higher for SNR ~7
%wienerAlpha = 0.005;
wienerAlpha = linspace(0.002, 0.2, 20);
% OTF thresholding parameter
OTFCumThresh = 0.87;
%OTFCumThresh = [0.5, 0.75, 0.88, 0.98, 0.99];
% true if the PSF is in skew space
skewed = true;
% deconvolution result path string (within dataPath)
resultDirName = 'matlab_decon_omw';

% background to subtract
Background = 100;
% number of iterations
DeconIter = 2;
% erode the edge after decon for number of pixels.
EdgeErosion = 0;
% save as 16bit; if false, save to single
Save16bit = true;
% use zarr file as input; if false, use tiff as input
zarrFile = false;
% save output as zarr file; if false,s ave as tiff
saveZarr = false;
% number of cpu cores
cpusPerTask = 24;
% use cluster computing for different images
parseCluster = false;
% set it to true for large files that cannot be fitted to RAM/GPU, it will
% split the data to chunks for deconvolution
largeFile = false;
% use GPU for deconvolution
GPUJob = true;
% if true, save intermediate results every 5 iterations.
debug = false;
% config file for the master jobs that runs on CPU node
ConfigFile = '';
% config file for the GPU job scheduling on GPU node
GPUConfigFile = '';
% if true, use Matlab runtime (for the situation without matlab license)
mccMode = false;


%% Step 3.2: run the deconvolution with given parameters. 
% the results will be saved in matlab_decon under the dataPaths. 
% the next step is deskew/rotate (if in skewed space for x-stage scan) or 
% rotate (if objective scan) or other processings. 

% result folder:
% {destPath}/PetaKit5D_demo_cell_image_dataset/matlab_decon_omw/

for ii= 1:length(wienerAlpha)
resultDirName = strcat('matlab_decon_omw_wienerAlpha', num2str(wienerAlpha(ii)))

XR_decon_data_wrapper(dataPaths, 'resultDirName', resultDirName, 'xyPixelSize', xyPixelSize, ...
    'dz', dz, 'Reverse', Reverse, 'ChannelPatterns', ChannelPatterns, 'PSFFullpaths', PSFFullpaths, ...
    'dzPSF', dzPSF, 'parseSettingFile', parseSettingFile, 'RLmethod', RLmethod, ...
    'wienerAlpha', wienerAlpha(ii), 'OTFCumThresh', OTFCumThresh, 'skewed', skewed, ...
    'Background', Background, 'DeconIter', DeconIter, 'EdgeErosion', EdgeErosion, ...
    'Save16bit', Save16bit, 'zarrFile', zarrFile, 'saveZarr', saveZarr, 'parseCluster', parseCluster, ...
    'largeFile', largeFile, 'GPUJob', GPUJob, 'debug', debug, 'cpusPerTask', cpusPerTask, ...
    'ConfigFile', ConfigFile, 'GPUConfigFile', GPUConfigFile, 'mccMode', mccMode);

% release GPU if using GPU computing
if GPUJob && gpuDeviceCount('available') > 0
    reset(gpuDevice);
end
end


