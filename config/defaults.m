function config = defaults()
%DEFAULTS Authoritative defaults for dicom2nifti.
%   config = defaults()
%
%   Deployer-owned configuration. Edit this file to match your site.
%   This is the authoritative source for spm_root and other defaults.
%
%   See also dicom2nifti.config.load, dicom2nifti_config

% SPM installation root
config.spm_root = '/usr/pubsw/packages/mrpet/standalone_apps/shared_libraries_2026/spm8-r6313';
end
