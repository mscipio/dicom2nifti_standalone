function varargout = dcm2nii(varargin)
%DCM2NII Convert one DICOM series or NIfTI file to NIfTI.
%   dcm2nii()
%   dcm2nii(inputFile)
%   dcm2nii(inputFile, outputFile)
%   dcm2nii(..., 'Compression', 'gz')

originalPath = path;
pathCleanup = onCleanup(@() path(originalPath));
rootDir = fileparts(mfilename('fullpath'));
addpath(rootDir, '-begin');
addpath(fullfile(rootDir, 'config'), '-begin');

[positional, compression] = parseInputs(varargin);
if isempty(positional)
    [inputName, inputDir] = uigetfile( ...
        {'*.dcm;*.DCM;*.ima;*.IMA', 'DICOM files'; ...
         '*.nii;*.nii.gz', 'NIfTI files'}, ...
        'Select one DICOM instance or NIfTI file');
    if isnumeric(inputName) && isscalar(inputName) && inputName == 0, return; end
    inputFile = fullfile(inputDir, inputName);
    defaultName = proposeOutputName(inputFile);
    [outputName, outputDir] = uiputfile( ...
        {'*.nii', 'NIfTI uncompressed (*.nii)'; ...
         '*.nii.gz', 'NIfTI compressed (*.nii.gz)'}, ...
        'Save as', fullfile(inputDir, defaultName));
    if isnumeric(outputName) && isscalar(outputName) && outputName == 0, return; end
    outputFile = fullfile(outputDir, outputName);
elseif isscalar(positional)
    inputFile = positional{1};
    outputFile = '';
else
    inputFile = positional{1};
    outputFile = positional{2};
end

if ~ischar(inputFile) || isempty(strtrim(inputFile)) || exist(inputFile, 'file') ~= 2
    error('dcm2nii:InvalidInputFile', 'Input file does not exist: %s', inputFile);
end
inputFile = strtrim(inputFile);
if isempty(fileparts(inputFile)), inputFile = fullfile(pwd, inputFile); end
[isNifti, isCompressedInput] = classifyNifti(inputFile);

if isempty(outputFile)
    outputFile = automaticOutput(inputFile, isNifti, isCompressedInput);
elseif ~ischar(outputFile) || isempty(strtrim(outputFile))
    error('dcm2nii:InvalidOutputFile', 'Output file must be a nonempty character vector.');
else
    outputFile = strtrim(outputFile);
end
if isempty(fileparts(outputFile)), outputFile = fullfile(pwd, outputFile); end

[outputFile, compression] = normalizeOutput(outputFile, compression);
if strcmp(compression, 'gz')
    workingOutput = outputFile(1:end-3);
else
    workingOutput = outputFile;
end

outputDir = fileparts(outputFile);
if ~isempty(outputDir) && exist(outputDir, 'dir') ~= 7
    [ok, message] = mkdir(outputDir);
    if ~ok
        error('dcm2nii:CreateOutputDirFailed', ...
            'Could not create output directory %s: %s', outputDir, message);
    end
end

if isNifti
    workflow = 'nifti';
else
    tags = dicom2nifti.dicom.readTags(inputFile);
    modality = upper(strtrim(tags.Modality));
    if strcmp(modality, 'PET'), modality = 'PT'; end
    if strcmp(modality, 'PT')
        workflow = 'pet';
    elseif any(strcmp(modality, {'MR', 'CT'}))
        workflow = 'dicom';
    else
        error('dcm2nii:UnsupportedModality', ...
            'Unsupported DICOM modality ''%s''. Only MR, CT, and PT are accepted.', ...
            modality);
    end
    setupSpm();
end

dicom2nifti.io.logMessage('INFO', 'dcm2nii', 'Input: %s', inputFile);
dicom2nifti.io.logMessage('INFO', 'dcm2nii', 'Output: %s', outputFile);
startTime = tic;

if strcmp(workflow, 'nifti') && strcmp(compression, 'gz') && sameFile(inputFile, outputFile)
    outputPath = inputFile;
else
    switch workflow
        case 'nifti'
            outputPath = dicom2nifti.core.fromNifti(inputFile, workingOutput);
        case 'dicom'
            outputPath = dicom2nifti.core.fromDicom(inputFile, workingOutput);
        case 'pet'
            outputPath = dicom2nifti.core.fromPet(inputFile, workingOutput);
    end
    if strcmp(compression, 'gz')
        outputPath = compressTo(outputPath, outputFile, inputFile);
    end
end

try
    dicom2nifti.io.writeVersionLog(outputPath);
catch ME
    dicom2nifti.io.logMessage('WARN', 'dcm2nii', ...
        'Output written, but version record failed: %s', ME.message);
end

dicom2nifti.io.logMessage('SUCCESS', 'dcm2nii', ...
    'Conversion completed (%.1f sec)', toc(startTime));
if nargout > 0, varargout{1} = outputPath; end
end

function [positional, compression] = parseInputs(arguments)
positional = {};
compression = 'none';
index = 1;
while index <= numel(arguments)
    value = arguments{index};
    if ischar(value) && strcmpi(value, 'Compression')
        if index == numel(arguments) || ~ischar(arguments{index + 1})
            error('dcm2nii:InvalidCompression', ...
                'Compression requires ''none'' or ''gz''.');
        end
        compression = lower(strtrim(arguments{index + 1}));
        index = index + 2;
    else
        positional{end + 1} = value; %#ok<AGROW>
        index = index + 1;
    end
end
if numel(positional) > 2
    error('dcm2nii:InvalidInput', ...
        'Usage: dcm2nii(inputFile [, outputFile] [, ''Compression'', ''gz''])');
end
if ~any(strcmp(compression, {'none', 'gz'}))
    error('dcm2nii:InvalidCompression', 'Compression must be ''none'' or ''gz''.');
end
end

function [isNifti, isCompressed] = classifyNifti(filePath)
lowerPath = lower(filePath);
isCompressed = length(lowerPath) >= 7 && strcmp(lowerPath(end-6:end), '.nii.gz');
[~, ~, extension] = fileparts(lowerPath);
isNifti = isCompressed || strcmp(extension, '.nii');
end

function name = proposeOutputName(inputFile)
[isNifti, isCompressed] = classifyNifti(inputFile);
if isNifti
    [~, name, ~] = fileparts(inputFile);
    if isCompressed, [~, name, ~] = fileparts(name); end
    name = [name '.nii'];
else
    tags = dicom2nifti.dicom.readTags(inputFile);
    name = dicom2nifti.io.proposeName(tags.Modality, tags.SeriesNumber);
end
end

function outputFile = automaticOutput(inputFile, isNifti, isCompressed)
inputDir = fileparts(inputFile);
if isNifti
    [~, name, ~] = fileparts(inputFile);
    if isCompressed, [~, name, ~] = fileparts(name); end
    outputFile = fullfile(inputDir, [name '.nii']);
else
    tags = dicom2nifti.dicom.readTags(inputFile);
    outputFile = fullfile(inputDir, ...
        dicom2nifti.io.proposeName(tags.Modality, tags.SeriesNumber));
end
end

function [outputFile, compression] = normalizeOutput(outputFile, compression)
lowerOutput = lower(outputFile);
isGz = length(lowerOutput) >= 7 && strcmp(lowerOutput(end-6:end), '.nii.gz');
[~, ~, extension] = fileparts(lowerOutput);
if isGz
    compression = 'gz';
elseif isempty(extension)
    outputFile = [outputFile '.nii'];
elseif ~strcmp(extension, '.nii')
    error('dcm2nii:InvalidOutputExtension', ...
        'Output must end in .nii or .nii.gz: %s', outputFile);
end
if strcmp(compression, 'gz') && ~isGz
    outputFile = [outputFile '.gz'];
end
end

function setupSpm()
config = dicom2nifti_config();
if ~isfield(config, 'spm_root') || ~ischar(config.spm_root) || isempty(config.spm_root)
    error('dcm2nii:SpmRootMissing', ...
        'config/dicom2nifti_config.m must define a nonempty spm_root.');
end
if exist(config.spm_root, 'dir') ~= 7
    error('dcm2nii:SpmRootMissing', ...
        'Configured SPM root does not exist: %s', config.spm_root);
end
addpath(config.spm_root, '-begin');
if exist('spm_dicom_headers', 'file') ~= 2 || exist('spm_dicom_convert', 'file') ~= 2
    error('dcm2nii:SpmIncomplete', ...
        'Configured SPM root does not provide DICOM conversion functions: %s', ...
        config.spm_root);
end
end

function finalPath = compressTo(sourcePath, finalPath, originalInput)
finalDir = fileparts(finalPath);
if isempty(finalDir), finalDir = pwd; end
stageDir = tempname(finalDir);
[ok, message] = mkdir(stageDir);
if ~ok
    error('dcm2nii:CompressionStageFailed', ...
        'Could not create compression staging directory: %s', message);
end
cleanup = onCleanup(@() cleanupDirectory(stageDir));
created = gzip(sourcePath, stageDir);
if isempty(created) || exist(created{1}, 'file') ~= 2
    error('dcm2nii:CompressionFailed', 'gzip did not produce an output file.');
end
[ok, message] = movefile(created{1}, finalPath, 'f');
if ~ok
    error('dcm2nii:CompressionPromoteFailed', ...
        'Could not promote compressed output to %s: %s', finalPath, message);
end
if ~sameFile(sourcePath, originalInput) && exist(sourcePath, 'file') == 2
    delete(sourcePath);
end
end

function result = sameFile(first, second)
if ispc, result = strcmpi(first, second); else, result = strcmp(first, second); end
end

function cleanupDirectory(directory)
if exist(directory, 'dir') == 7, rmdir(directory, 's'); end
end
