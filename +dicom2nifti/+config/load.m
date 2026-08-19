function config = load()
%LOAD Resolve SPM configuration with caller-first authority.
%   config = dicom2nifti.config.load()
%
%   Resolution order:
%   1. If BOTH spm_dicom_headers AND spm_dicom_convert are on the caller's
%      MATLAB path → authoritative, unshadowed. Returns their resolved paths.
%   2. If ONLY ONE of the two functions exists → deterministic error (partial
%      SPM installation).
%   3. If NEITHER function is on the path → fallback to config/defaults.m
%      spm_root.
%
%   Snapshot caller path state before any mutation and restores it on exit.
%   No path leakage.
%
%   See also dicom2nifti.config.validate, defaults

% Snapshot caller path before any mutation
originalPath = path;
cleanup = onCleanup(@() path(originalPath));

% Check caller SPM presence
existingHeaders = which('spm_dicom_headers');
existingConvert = which('spm_dicom_convert');

if ~isempty(existingHeaders) || ~isempty(existingConvert)
    % At least one SPM function is on the path
    if isempty(existingHeaders) || isempty(existingConvert)
        error('dicom2nifti:config:SpmIncomplete', ...
            'The caller MATLAB path contains only part of an SPM installation.');
    end
    % Complete caller SPM pair — authoritative, unshadowed
    config.spm_root = fileparts(existingHeaders);
    config.spm_headers_func = existingHeaders;
    config.spm_convert_func = existingConvert;
    return;
end

% Neither SPM function on the caller path — fallback to defaults
repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'config'), '-begin');

defaultConfig = defaults();
config.spm_root = defaultConfig.spm_root;
config.spm_headers_func = fullfile(config.spm_root, 'spm_dicom_headers.m');
config.spm_convert_func = fullfile(config.spm_root, 'spm_dicom_convert.m');
end
