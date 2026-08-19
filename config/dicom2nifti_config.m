function config = dicom2nifti_config()
%DICOM2NIFTI_CONFIG Deprecated compatibility wrapper.
%   config = dicom2nifti_config()
%
%   This function is DEPRECATED. New deployments should use:
%     1. Edit config/defaults.m to set site-specific spm_root
%     2. Call dicom2nifti.config.load() for resolved configuration
%     3. Call dicom2nifti.config.validate(config) before conversion
%
%   Existing callers that use this symbol continue to work without
%   changes. This wrapper delegates to dicom2nifti.config.load().
%
%   This function will be removed in a future breaking version.
%
%   See also defaults, dicom2nifti.config.load, dicom2nifti.config.validate

config = dicom2nifti.config.load();
end
