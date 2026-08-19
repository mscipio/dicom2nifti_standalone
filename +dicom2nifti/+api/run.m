function result = run(inputFile, outputFile, varargin)
%RUN Explicit-input, UI-free conversion entrypoint.
%   result = dicom2nifti.api.run(inputFile, outputFile, varargin)
%   Options: 'Compression'={'none','gz'}, 'Overwrite'=logical/numeric.
%   Returns struct(status/outputs/message/details).

% Parse options
compression = 'none'; overwrite = false;
if mod(numel(varargin), 2) ~= 0
    error('dicom2nifti:api:InvalidOption', ...
        'Options must be Name-Value pairs.');
end
for i = 1:2:numel(varargin)
    k = varargin{i}; v = varargin{i+1};
    if ~ischar(k)
        error('dicom2nifti:api:InvalidOption', ...
            'Option name must be a character vector.');
    end
    if strcmpi(k, 'Compression')
        if ~ischar(v)
            error('dicom2nifti:api:InvalidInput', 'Compression must be a character vector.');
        end
        compression = lower(strtrim(v));
    elseif strcmpi(k, 'Overwrite')
        if ~((islogical(v)||isnumeric(v))&&isscalar(v))
            error('dicom2nifti:api:InvalidInput', 'Overwrite must be a logical or numeric scalar.');
        end
        overwrite = logical(v);
    else
        error('dicom2nifti:api:InvalidOption', ...
            'Unknown option ''%s''. Accepted: Compression, Overwrite.', k);
    end
end
if ~any(strcmp(compression, {'none', 'gz'}))
    error('dicom2nifti:api:InvalidInput', 'Compression must be ''none'' or ''gz''.');
end

% Scaffold result
result = struct('status', 'failed', 'outputs', {{}}, ...
    'message', '', 'details', struct('spm_loaded', false));

% Path/cwd snapshots for cleanup
origPath = path; origDir = pwd;
rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));

% ==== MAIN BODY
try

% Validate inputFile
if ~ischar(inputFile)
    error('dicom2nifti:api:InvalidInput', 'inputFile must be a character vector.');
end
inputFile = absPath(inputFile);
if exist(inputFile, 'file') ~= 2
    error('dicom2nifti:api:InvalidInput', 'Input file does not exist: %s', inputFile);
end
if strcmpi(ext(inputFile), '.i')
    error('dicom2nifti:api:InvalidExtension', '.i files are not supported.');
end

% Validate outputFile
if ~ischar(outputFile)
    error('dicom2nifti:api:InvalidInput', 'outputFile must be a character vector.');
end
[outputFile, compression] = normOut(absPath(outputFile), compression);

% Guards
if isSame(inputFile, outputFile)
    error('dicom2nifti:api:InputOutputSame', ...
        'Input and output are the same file.');
end

% Route: NIfTI vs DICOM
isNii = endsWith(lower(inputFile), {'.nii', '.nii.gz'});
if isNii
    workflow = 'nifti';
else
    tags = dicom2nifti.dicom.readTags(inputFile, ...
        {'SeriesInstanceUID', 'Modality', 'SeriesNumber'}, true);
    modality = normMod(tags.Modality);
    switch modality
        case 'PT',  workflow = 'pet';
        case {'MR', 'CT'}, workflow = 'dicom';
        otherwise
            error('dicom2nifti:api:UnsupportedModality', ...
                'Unsupported modality ''%s''.', modality);
    end
end

% SPM: DICOM routes only
if ~isNii
    config = dicom2nifti.config.load();
    dicom2nifti.config.validate(config);
    addpath(rootDir, '-begin');
    addpath(fullfile(rootDir, 'config'), '-begin');
    result.details.spm_loaded = true;
    if isfield(config, 'spm_root') && ~isempty(config.spm_root) ...
            && exist(config.spm_root, 'dir') == 7
        addpath(config.spm_root, '-begin');
    end
    if exist('spm_dicom_headers', 'file') ~= 2 ...
            || exist('spm_dicom_convert', 'file') ~= 2
        error('dicom2nifti:api:InvalidInput', ...
            'SPM DICOM conversion functions are not reachable.');
    end
end

% Overwrite check
outDir = fileparts(outputFile);
if isempty(outDir), outDir = pwd; end
expected = {outputFile, fullfile(outDir, 'dcm2nii_version.txt')};
if strcmp(workflow, 'pet')
    expected{end + 1} = fullfile(outDir, 'Frame_info.txt');
end
existing = {};
for i = 1:numel(expected)
    if exist(expected{i}, 'file') == 2
        existing{end + 1} = expected{i}; %#ok<AGROW>
    end
end
if ~isempty(existing) && ~overwrite
    error('dicom2nifti:api:OutputExists', ...
        'Destination already exists: %s', existing{1});
end

% Create output directory
if ~isempty(outDir) && exist(outDir, 'dir') ~= 7
    [ok, msg] = mkdir(outDir);
    if ~ok
        error('dicom2nifti:api:InvalidInput', 'Cannot create %s: %s', outDir, msg);
    end
end

% Working output (strip .gz for core)
if strcmp(compression, 'gz')
    workingOut = outputFile(1:end - 3);
else
    workingOut = outputFile;
end

% Log start + dispatch to +core
dicom2nifti.io.logMessage('INFO', 'api.run', 'Input: %s', inputFile);
dicom2nifti.io.logMessage('INFO', 'api.run', 'Output: %s', outputFile);
t0 = tic;

conversionOk = true;
try
    switch workflow
        case 'nifti', outPath = dicom2nifti.core.fromNifti(inputFile, workingOut);
        case 'dicom', outPath = dicom2nifti.core.fromDicom(inputFile, workingOut);
        case 'pet',   outPath = dicom2nifti.core.fromPet(inputFile, workingOut, overwrite);
    end
catch ME
    result.status = 'failed';
    result.message = ME.message;
    dicom2nifti.io.logMessage('ERROR', 'api.run', 'Conversion failed: %s', ME.message);
    conversionOk = false;
end

% Post-compress
if conversionOk && strcmp(compression, 'gz')
    try
        outPath = gzipOut(outPath, outputFile, inputFile);
    catch ME
        result.status = 'failed';
        result.message = ME.message;
        result.outputs = {outPath};
        dicom2nifti.io.logMessage('ERROR', 'api.run', ...
            'Compression failed: %s', ME.message);
        conversionOk = false;
    end
end

% Version log
verFailed = false;
if conversionOk
    try
        dicom2nifti.io.writeVersionLog(outPath, overwrite);
    catch ME
        verFailed = true;
        result.message = ME.message;
        result.details.version_log_error = ME.message;
        dicom2nifti.io.logMessage('WARN', 'api.run', ...
            'Version log failed: %s', ME.message);
    end
end

% Build result struct
if conversionOk
    committed = {outPath, fullfile(outDir, 'dcm2nii_version.txt')};
    if strcmp(workflow, 'pet')
        committed{end + 1} = fullfile(outDir, 'Frame_info.txt');
    end

    if verFailed
        result.status = 'partial';
        result.outputs = committed(cellfun(@(c) exist(c, 'file') == 2, committed));
    else
        result.status = 'success';
        result.outputs = committed;
    end

    result.message = sprintf('Conversion completed (%.1f sec)', toc(t0));
    dicom2nifti.io.logMessage('SUCCESS', 'api.run', result.message);
end

% ==== END MAIN BODY
catch ME_primary
    % Exception: restore, attach cleanup failures as causes
    try path(origPath); catch ME_c, ME_primary = addCause(ME_primary, ME_c); end
    try
        if exist(origDir, 'dir') == 7, cd(origDir); else cd(tempdir); end
    catch ME_c, ME_primary = addCause(ME_primary, ME_c); end
    rethrow(ME_primary);
end

% Result-path cleanup: restore, record, never mask
try path(origPath); catch ME_c
    result.details.cleanup_error = ME_c.message;
end
try
    if exist(origDir, 'dir') == 7, cd(origDir); else cd(tempdir); end
catch ME_c
    if isfield(result.details, 'cleanup_error')
        result.details.cleanup_error = [result.details.cleanup_error '; ' ME_c.message];
    else
        result.details.cleanup_error = ME_c.message;
    end
end
end

% Local helpers

function p = absPath(p)
p = strtrim(p); if isempty(p), return; end
if isunix && p(1) == '~', p = fullfile(getenv('HOME'), p(2:end)); end
if isunix && ~isempty(p) && p(1) ~= '/'
    p = fullfile(pwd, p);
end
end

function [of, comp] = normOut(of, comp)
if endsWith(lower(of), '.nii.gz')
    comp = 'gz';
elseif ~strcmpi(ext(of), '.nii') && ~isempty(ext(of))
    error('dicom2nifti:api:InvalidExtension', ...
        'Output must end in .nii or .nii.gz: %s', of);
elseif isempty(ext(of))
    of = [of '.nii'];
end
if strcmp(comp, 'gz') && ~endsWith(lower(of), '.nii.gz')
    if ~strcmpi(ext(of), '.nii')
        error('dicom2nifti:api:InvalidExtension', ...
            'Compressed output must be based on a .nii name: %s', of);
    end
    of = [of '.gz'];
end
end

function outPath = gzipOut(srcPath, outPath, origInput)
d = fileparts(outPath); if isempty(d), d = pwd; end
stage = tempname(d);
[ok, msg] = mkdir(stage);
if ~ok, error('dicom2nifti:api:InvalidInput', 'Cannot create stage: %s', msg); end
c = onCleanup(@() cleanupDir(stage)); %#ok<NASGU>
created = gzip(srcPath, stage);
if isempty(created) || exist(created{1}, 'file') ~= 2
    error('dicom2nifti:api:InvalidInput', 'gzip produced no output.');
end
[ok, msg] = movefile(created{1}, outPath, 'f');
if ~ok, error('dicom2nifti:api:InvalidInput', 'Cannot promote: %s', msg); end
if exist(srcPath, 'file') == 2 && ~strcmp(srcPath, origInput)
    delete(srcPath);
end
end

function e = ext(p)
[~, ~, e] = fileparts(p);
end

function r = isSame(a, b)
if ispc, r = strcmpi(a, b); else r = strcmp(a, b); end
end

function m = normMod(m)
if ~ischar(m), m = ''; end
m = upper(strtrim(m));
if strcmp(m, 'PET'), m = 'PT'; end
end

function cleanupDir(d)
if exist(d, 'dir') == 7, rmdir(d, 's'); end
end
