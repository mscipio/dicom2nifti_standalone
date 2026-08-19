function validate(config)
%VALIDATE Pre-mutation guard for SPM configuration.
%   dicom2nifti.config.validate(config)
%
%   Validates before any output-directory creation or path mutation:
%   - spm_root is a nonempty character vector
%   - spm_root directory exists on disk
%
%   Throws dicom2nifti:config:InvalidSpmRoot on any failure.
%
%   See also dicom2nifti.config.load, defaults

if ~isfield(config, 'spm_root') || ~ischar(config.spm_root) || isempty(config.spm_root)
    error('dicom2nifti:config:InvalidSpmRoot', ...
        'Config must define a nonempty spm_root character vector.');
end

if exist(config.spm_root, 'dir') ~= 7
    error('dicom2nifti:config:InvalidSpmRoot', ...
        'Configured SPM root does not exist: %s', config.spm_root);
end
end
