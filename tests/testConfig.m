function tests = testConfig()
% Config boundary tests.
tests = functiontests(localfunctions);
end

function testLoadReturnsConfig(testCase)
% config.load returns struct with spm_root honoring caller-SPM-first.
config = dicom2nifti.config.load();
verifyTrue(testCase, isstruct(config) && isfield(config, 'spm_root'));
verifyTrue(testCase, ischar(config.spm_root) && ~isempty(config.spm_root));
verifyTrue(testCase, isfield(config, 'spm_headers_func') && isfield(config, 'spm_convert_func'));
end

function testValidateRejectsBadSpmRoot(testCase)
% config.validate MUST error on nonexistent spm_root.
bad = struct('spm_root', '/no/such/spm/path');
verifyError(testCase, @() dicom2nifti.config.validate(bad), ...
    'dicom2nifti:config:InvalidSpmRoot');
end

function testValidateAcceptsRealSpmRoot(testCase)
% Valid spm_root from defaults MUST pass validation.
defaultConfig = defaults();
verifyTrue(testCase, ischar(defaultConfig.spm_root) && ~isempty(defaultConfig.spm_root));
verifyWarningFree(testCase, @() dicom2nifti.config.validate(defaultConfig));
end

function testValidateRejectsMissingField(testCase)
% Missing or empty spm_root MUST error.
bad = struct('other', 1);
verifyError(testCase, @() dicom2nifti.config.validate(bad), ...
    'dicom2nifti:config:InvalidSpmRoot');
bad2 = struct('spm_root', '');
verifyError(testCase, @() dicom2nifti.config.validate(bad2), ...
    'dicom2nifti:config:InvalidSpmRoot');
end

function testLoadReturnsFunctionPaths(testCase)
% When falling back to defaults, spm_headers_func and spm_convert_func
% MUST be nonempty character vectors pointing to .m files.
config = dicom2nifti.config.load();
verifyTrue(testCase, ischar(config.spm_headers_func) && ~isempty(config.spm_headers_func));
verifyTrue(testCase, ischar(config.spm_convert_func) && ~isempty(config.spm_convert_func));
% Paths should point to .m files within spm_root
verifySubstring(testCase, config.spm_headers_func, config.spm_root);
verifySubstring(testCase, config.spm_convert_func, config.spm_root);
end

function testDefaultsStandalone(testCase)
% defaults() MUST be callable directly and return a struct with spm_root.
config = defaults();
verifyTrue(testCase, isstruct(config));
verifyTrue(testCase, isfield(config, 'spm_root'));
verifyTrue(testCase, ischar(config.spm_root) && ~isempty(config.spm_root));
end
