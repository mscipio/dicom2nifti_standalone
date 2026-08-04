function varargout = dcm2nii(varargin)
%DCM2NII Convert one DICOM series or NIfTI file to NIfTI.
%   dcm2nii()                         GUI: Java input/save choosers
%   dcm2nii(inputFile)                automatic output beside input
%   dcm2nii(inputFile, outputFile)    CLI conversion
%   dcm2nii(..., 'Compression', 'gz') write .nii.gz output
%   dcm2nii(..., 'Overwrite', true)   explicitly allow replacement

rootDir = fileparts(mfilename('fullpath'));
originalPath = path;
originalDir = pwd;
cleanup = onCleanup(@() restoreSession(originalPath, originalDir));
addpath(rootDir, '-begin');
addpath(fullfile(rootDir, 'config'), '-begin');

[inputFile, outputFile, compression, overwrite, interactive, cancelled] = ...
    requestFiles(varargin{:});
if cancelled
    if nargout > 0, varargout{1} = ''; end
    return;
end

inputFile = absolutePath(inputFile);
if exist(inputFile, 'file') ~= 2
    error('dcm2nii:InvalidInputFile', 'Input file does not exist: %s', inputFile);
end

[~, ~, inputExt] = fileparts(inputFile);
if strcmpi(inputExt, '.i')
    error('dcm2nii:UnsupportedInput', ...
        'Legacy .i files are not supported. Provide DICOM or NIfTI (.nii, .nii.gz) input.');
end

isNifti = isNiftiFile(inputFile);
if isempty(outputFile)
    outputFile = fullfile(fileparts(inputFile), ...
        dicom2nifti.io.proposeName(inputFile));
else
    outputFile = absolutePath(outputFile);
end
[outputFile, compression] = normalizeOutput(outputFile, compression);

if sameFile(inputFile, outputFile)
    error('dcm2nii:InputOutputSame', ...
        'Input and output are the same file; the source will not be overwritten.');
end

if isempty(fileparts(outputFile))
    outputFile = fullfile(pwd, outputFile);
end
outputDir = fileparts(outputFile);

if isNifti
    workflow = 'nifti';
else
    routingTags = dicom2nifti.dicom.readTags(inputFile, ...
        {'SeriesInstanceUID', 'Modality', 'SeriesNumber'}, true);
    modality = normalizeModality(routingTags.Modality);
    if strcmp(modality, 'PT')
        workflow = 'pet';
    elseif any(strcmp(modality, {'MR', 'CT'}))
        workflow = 'dicom';
    else
        error('dcm2nii:UnsupportedModality', ...
            'Unsupported DICOM modality ''%s''. Only MR, CT, and PT are accepted.', ...
            modality);
    end
end

if strcmp(workflow, 'pet')
    % The legacy 4D workflow writes this sidecar. Protect it even when the
    % selected PET happens to be static and does not need the file.
    existingOutputs = {outputFile, fullfile(outputDir, 'dcm2nii_version.txt'), ...
        fullfile(outputDir, 'Frame_info.txt')};
else
    existingOutputs = {outputFile, fullfile(outputDir, 'dcm2nii_version.txt')};
end
[overwrite, cancelled] = resolveOverwrite(existingOutputs, overwrite, interactive);
if cancelled
    if nargout > 0, varargout{1} = ''; end
    return;
end

if ~isempty(outputDir) && exist(outputDir, 'dir') ~= 7
    [ok, message] = mkdir(outputDir);
    if ~ok
        error('dcm2nii:CreateOutputDirFailed', ...
            'Could not create output directory %s: %s', outputDir, message);
    end
end

if ~isNifti
    setupSpm();
end

if strcmp(compression, 'gz')
    workingOutput = outputFile(1:end - 3);
else
    workingOutput = outputFile;
end

dicom2nifti.io.logMessage('INFO', 'dcm2nii', 'Input: %s', inputFile);
dicom2nifti.io.logMessage('INFO', 'dcm2nii', 'Output: %s', outputFile);
startTime = tic;

if strcmp(workflow, 'nifti')
    outputPath = dicom2nifti.core.fromNifti(inputFile, workingOutput);
elseif strcmp(workflow, 'dicom')
    outputPath = dicom2nifti.core.fromDicom(inputFile, workingOutput);
else
    outputPath = dicom2nifti.core.fromPet(inputFile, workingOutput, overwrite);
end

if strcmp(compression, 'gz')
    outputPath = compressTo(outputPath, outputFile, inputFile);
end

try
    dicom2nifti.io.writeVersionLog(outputPath, overwrite);
catch ME
    dicom2nifti.io.logMessage('WARN', 'dcm2nii', ...
        'Output written, but version record failed: %s', ME.message);
end

dicom2nifti.io.logMessage('SUCCESS', 'dcm2nii', ...
    'Conversion completed (%.1f sec)', toc(startTime));
if nargout > 0
    varargout{1} = outputPath;
end
end

function [inputFile, outputFile, compression, overwrite, interactive, cancelled] = ...
    requestFiles(varargin)
compression = 'none';
overwrite = false;
positional = {};
index = 1;
while index <= nargin
    value = varargin{index};
    if ischar(value) && strcmpi(value, 'Compression')
        if index == nargin || ~ischar(varargin{index + 1})
            error('dcm2nii:InvalidCompression', ...
                'Compression must be ''none'' or ''gz''.');
        end
        compression = lower(strtrim(varargin{index + 1}));
        index = index + 2;
    elseif ischar(value) && strcmpi(value, 'Overwrite')
        if index == nargin || ...
                ~(islogical(varargin{index + 1}) || isnumeric(varargin{index + 1})) || ...
                ~isscalar(varargin{index + 1})
            error('dcm2nii:InvalidOverwrite', ...
                'Overwrite must be a logical or numeric scalar.');
        end
        overwrite = logical(varargin{index + 1});
        index = index + 2;
    else
        positional{end + 1} = value; %#ok<AGROW>
        index = index + 1;
    end
end

if ~any(strcmp(compression, {'none', 'gz'})) || numel(positional) > 2
    error('dcm2nii:InvalidInput', ...
        'Use dcm2nii(inputFile [, outputFile] [, ''Compression'', ''gz'']).');
end

cancelled = false;
interactive = isempty(positional);
if isempty(positional)
    [inputFile, cancelled] = chooseInputFile();
    if cancelled
        outputFile = '';
        return;
    end
    inputFile = deblank(inputFile);
    [outputFile, cancelled] = chooseOutputFile(inputFile, ...
        dicom2nifti.io.proposeName(inputFile));
    if cancelled
        inputFile = '';
        outputFile = '';
        return;
    end
elseif isscalar(positional)
    inputFile = positional{1};
    outputFile = '';
else
    inputFile = positional{1};
    outputFile = positional{2};
end
end

function [inputFile, cancelled] = chooseInputFile()
%CHOOSEINPUTFILE Select one input, starting in the caller's current folder.
inputDirectory = pwd;
if exist('javaObjectEDT', 'file') == 2
    chooser = javaObjectEDT('javax.swing.JFileChooser', inputDirectory);
else
    chooser = javaObject('javax.swing.JFileChooser', inputDirectory);
end
chooser.setDialogTitle('Select DICOM or NIfTI input');
chooser.setDialogType(javax.swing.JFileChooser.OPEN_DIALOG);
chooser.setCurrentDirectory(javaObject('java.io.File', inputDirectory));
dicomFilter = javaObject('javax.swing.filechooser.FileNameExtensionFilter', ...
    'DICOM (*.dcm, *.DCM, *.ima, *.IMA)', {'dcm', 'DCM', 'ima', 'IMA'});
niftiFilter = javaObject('javax.swing.filechooser.FileNameExtensionFilter', ...
    'NIfTI (*.nii, *.nii.gz)', {'nii', 'gz'});
chooser.setAcceptAllFileFilterUsed(true);
chooser.addChoosableFileFilter(dicomFilter);
chooser.addChoosableFileFilter(niftiFilter);
chooser.setFileFilter(dicomFilter);
result = chooser.showOpenDialog([]);
if result ~= 0
    inputFile = '';
    cancelled = true;
    return;
end
selected = chooser.getSelectedFile();
if isempty(selected)
    inputFile = '';
    cancelled = true;
else
    inputFile = char(selected.getAbsolutePath());
    cancelled = false;
end
end

function [outputFile, cancelled] = chooseOutputFile(inputFile, defaultName)
inputDirectory = fileparts(inputFile);
if exist('javaObjectEDT', 'file') == 2
    chooser = javaObjectEDT('javax.swing.JFileChooser', inputDirectory);
else
    chooser = javaObject('javax.swing.JFileChooser', inputDirectory);
end
chooser.setDialogTitle('Save NIfTI output');
chooser.setDialogType(javax.swing.JFileChooser.SAVE_DIALOG);
chooser.setCurrentDirectory(javaObject('java.io.File', inputDirectory));
chooser.setSelectedFile(javaObject('java.io.File', ...
    fullfile(inputDirectory, defaultName)));
niiFilter = javaObject('javax.swing.filechooser.FileNameExtensionFilter', ...
    'NIfTI (*.nii)', {'nii'});
gzFilter = javaObject('javax.swing.filechooser.FileNameExtensionFilter', ...
    'NIfTI compressed (*.nii.gz)', {'gz'});
chooser.setAcceptAllFileFilterUsed(false);
chooser.addChoosableFileFilter(niiFilter);
chooser.addChoosableFileFilter(gzFilter);
chooser.setFileFilter(niiFilter);
result = chooser.showSaveDialog([]);
if result ~= 0
    outputFile = '';
    cancelled = true;
    return;
end
selected = chooser.getSelectedFile();
if isempty(selected)
    outputFile = '';
    cancelled = true;
    return;
end
outputFile = char(selected.getAbsolutePath());
selectedDescription = char(chooser.getFileFilter().getDescription());
if strcmp(selectedDescription, 'NIfTI compressed (*.nii.gz)')
    outputFile = normalizeChooserName(outputFile, true);
else
    outputFile = normalizeChooserName(outputFile, false);
end
cancelled = false;
end

function outputFile = normalizeChooserName(outputFile, compressed)
if compressed
    if isNiftiGz(outputFile), return; end
    if length(outputFile) >= 4 && strcmpi(outputFile(end - 3:end), '.nii')
        outputFile = [outputFile '.gz'];
    elseif isempty(fileExtension(outputFile))
        outputFile = [outputFile '.nii.gz'];
    else
        outputFile = [outputFile '.nii.gz'];
    end
else
    if isNiftiGz(outputFile)
        outputFile = outputFile(1:end - 3);
    elseif ~strcmpi(fileExtension(outputFile), '.nii')
        outputFile = [outputFile '.nii'];
    end
end
end

function setupSpm()
%SETUPSPM Reuse caller SPM or add the configured fallback temporarily.
%   A complete caller-owned installation is authoritative and reused
%   unchanged. An incomplete caller path (only one of the two required
%   functions) fails clearly. If neither function is on the caller path,
%   the configured spm_root is added as fallback.
existingHeaders = which('spm_dicom_headers');
existingConvert = which('spm_dicom_convert');
if ~isempty(existingHeaders) || ~isempty(existingConvert)
    if isempty(existingHeaders) || isempty(existingConvert)
        error('dcm2nii:SpmIncomplete', ...
            'The caller MATLAB path contains only part of an SPM installation.');
    end
    return;
end

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

function [outputFile, compression] = normalizeOutput(outputFile, compression)
outputFile = absolutePath(outputFile);
if isNiftiGz(outputFile)
    compression = 'gz';
elseif strcmpi(fileExtension(outputFile), '.nii')
    % Keep the caller's explicit compression choice.
elseif isempty(fileExtension(outputFile))
    outputFile = [outputFile '.nii'];
else
    error('dcm2nii:InvalidOutputExtension', ...
        'Output must end in .nii or .nii.gz: %s', outputFile);
end
if strcmp(compression, 'gz') && ~isNiftiGz(outputFile)
    if ~strcmpi(fileExtension(outputFile), '.nii')
        error('dcm2nii:InvalidOutputExtension', ...
            'Compressed output must be based on a .nii name: %s', outputFile);
    end
    outputFile = [outputFile '.gz'];
end
end

function [overwrite, cancelled] = resolveOverwrite(paths, overwrite, interactive)
existing = {};
for index = 1:numel(paths)
    if exist(paths{index}, 'file') == 2 || exist(paths{index}, 'dir') == 7
        existing{end + 1} = paths{index}; %#ok<AGROW>
    end
end
cancelled = false;
if isempty(existing), return; end

if interactive
    details = sprintf('  %s\n', existing{:});
    question = sprintf(['The following output file(s) already exist:\n\n%s\n' ...
        '\nOverwrite them? Existing source files will not be changed.'], details);
    answer = questdlg(question, 'Confirm overwrite', 'Overwrite', 'Cancel', 'Cancel');
    if ~strcmp(answer, 'Overwrite')
        cancelled = true;
        return;
    end
    overwrite = true;
elseif ~overwrite
    error('dcm2nii:OutputExists', ...
        ['Destination already exists and was not changed: %s\n' ...
         'Use ''Overwrite'', true to explicitly replace it.'], existing{1});
end
end

function outputPath = compressTo(sourcePath, outputPath, originalInput)
outputDir = fileparts(outputPath);
if isempty(outputDir), outputDir = pwd; end
stageDir = tempname(outputDir);
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
[ok, message] = movefile(created{1}, outputPath, 'f');
if ~ok
    error('dcm2nii:CompressionPromoteFailed', ...
        'Could not promote compressed output to %s: %s', outputPath, message);
end
if ~sameFile(sourcePath, originalInput) && exist(sourcePath, 'file') == 2
    delete(sourcePath);
end
end

function result = isNiftiFile(filePath)
result = strcmpi(fileExtension(filePath), '.nii') || isNiftiGz(filePath);
end

function result = isNiftiGz(filePath)
result = length(filePath) >= 7 && strcmpi(filePath(end - 6:end), '.nii.gz');
end

function extension = fileExtension(filePath)
[~, ~, extension] = fileparts(filePath);
end

function pathValue = absolutePath(pathValue)
if ~ischar(pathValue)
    error('dcm2nii:InvalidPath', 'Paths must be character vectors.');
end
pathValue = strtrim(pathValue);
if isempty(pathValue), return; end
if isunix && pathValue(1) == '~'
    pathValue = fullfile(getenv('HOME'), pathValue(2:end));
end
if isempty(fileparts(pathValue))
    pathValue = fullfile(pwd, pathValue);
end
end

function modality = normalizeModality(modality)
if ~ischar(modality), modality = ''; end
modality = upper(strtrim(modality));
if strcmp(modality, 'PET'), modality = 'PT'; end
end

function result = sameFile(first, second)
if ispc, result = strcmpi(first, second); else, result = strcmp(first, second); end
end

function restoreSession(originalPath, originalDir)
path(originalPath);
if exist(originalDir, 'dir') == 7, cd(originalDir); end
end

function cleanupDirectory(directory)
if exist(directory, 'dir') == 7, rmdir(directory, 's'); end
end
