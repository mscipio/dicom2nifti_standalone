function varargout = dcm2nii(varargin)
%DCM2NII Convert DICOM/NIfTI to NIfTI via structured API.
%   dcm2nii()                    GUI choosers
%   dcm2nii(input)               auto output beside input
%   dcm2nii(input, output)       CLI conversion
%   Options: 'Compression','gz', 'Overwrite',true
%   Thin facade dispatching to dicom2nifti.api.run or dicom2nifti.gui.mainWindow.

origPath = path; origDir = pwd;
rootDir = fileparts(mfilename('fullpath'));
addpath(rootDir, '-begin');
addpath(fullfile(rootDir, 'config'), '-begin');

compression = 'none'; overwrite = false; positional = {};
i = 1;
while i <= nargin
    v = varargin{i};
    if ischar(v) && strcmpi(v, 'Compression')
        if i == nargin || ~ischar(varargin{i + 1})
            error('dcm2nii:InvalidCompression', 'Compression must be ''none'' or ''gz''.');
        end
        compression = lower(strtrim(varargin{i + 1})); i = i + 2;
    elseif ischar(v) && strcmpi(v, 'Overwrite')
        if i == nargin || ~(islogical(varargin{i + 1}) || isnumeric(varargin{i + 1})) || ~isscalar(varargin{i + 1})
            error('dcm2nii:InvalidOverwrite', 'Overwrite must be a logical or numeric scalar.');
        end
        overwrite = logical(varargin{i + 1}); i = i + 2;
    else
        positional{end + 1} = v; i = i + 1; %#ok<AGROW>
    end
end
if ~any(strcmp(compression, {'none', 'gz'})) || numel(positional) > 2
    error('dcm2nii:InvalidInput', ...
        'Use dcm2nii(inputFile [, outputFile] [, ''Compression'', ''gz'']).');
end

apiOptions = {};
if ~strcmp(compression, 'none'), apiOptions = [apiOptions, {'Compression', compression}]; end
if overwrite, apiOptions = [apiOptions, {'Overwrite', true}]; end

try
    if isempty(positional)
        result = dicom2nifti.gui.mainWindow(apiOptions);
    elseif isscalar(positional)
        outputFile = fullfile(fileparts(positional{1}), dicom2nifti.io.proposeName(positional{1}));
        result = dicom2nifti.api.run(positional{1}, outputFile, apiOptions{:});
    else
        result = dicom2nifti.api.run(positional{1}, positional{2}, apiOptions{:});
    end
catch ME
    try path(origPath); catch ME_c, ME = addCause(ME, ME_c); end
    try
        if exist(origDir, 'dir') == 7, cd(origDir); else cd(tempdir); end
    catch ME_c, ME = addCause(ME, ME_c); end
    mapLegacyError(ME);
end

% Normal exit cleanup (result path)
try path(origPath); catch ME_c
    warning('dcm2nii:CleanupError', 'Path restoration failed: %s', ME_c.message);
end
try
    if exist(origDir, 'dir') == 7, cd(origDir); else cd(tempdir); end
catch ME_c
    warning('dcm2nii:CleanupError', 'CWD restoration failed: %s', ME_c.message);
end

% Map result → legacy contract
switch result.status
    case {'success', 'partial'}
        outPath = result.outputs{1};
    case 'cancelled'
        outPath = '';
    case 'failed'
        error('dcm2nii:ConversionFailed', '%s', result.message);
    otherwise
        error('dcm2nii:UnknownStatus', 'Unexpected status: %s', result.status);
end
if nargout > 0, varargout{1} = outPath; end
end
function mapLegacyError(ME)
% Map api identifiers → legacy dcm2nii identifiers.
import dicom2nifti.io.logMessage;

switch ME.identifier
    case 'dicom2nifti:api:InputOutputSame'
        id = 'dcm2nii:InputOutputSame';
    case 'dicom2nifti:api:InvalidInputFile'
        id = 'dcm2nii:InvalidInputFile';
    case {'dicom2nifti:api:InvalidExtension', 'dicom2nifti:api:UnsupportedInput'}
        id = 'dcm2nii:UnsupportedInput';
    case 'dicom2nifti:api:InvalidOutputFile'
        id = 'dcm2nii:InvalidOutputFile';
    case 'dicom2nifti:api:OverwriteDenied'
        id = 'dcm2nii:OverwriteDenied';
    case 'dicom2nifti:api:InvalidInput'
        id = 'dcm2nii:InvalidInput';
    case 'dicom2nifti:api:OutputExists'
        id = 'dcm2nii:OutputExists';
    case 'dicom2nifti:api:InvalidOption'
        id = 'dcm2nii:InvalidInput';
    otherwise
        rethrow(ME);
end
try logMessage('WARN', 'DEBUG', sprintf('facade remap %s → %s', ME.identifier, id)); catch, end
newME = MException(id, '%s', ME.message);
% Forward causes (e.g. cleanup failures attached by caller)
for c = 1:numel(ME.cause)
    newME = addCause(newME, ME.cause{c});
end
throwAsCaller(newME);
end
