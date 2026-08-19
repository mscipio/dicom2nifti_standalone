function tests = testGui()
%TESTGUI Contract tests for dicom2nifti.gui.mainWindow(). Headless smoke only.
tests = functiontests(localfunctions);
end

function fix = setupOnce(testCase)
fix = struct();
fix.root = fileparts(fileparts(mfilename('fullpath')));
addpath(fix.root, '-begin');
addpath(fullfile(fix.root, 'config'), '-begin');
testCase.TestData.fix = fix;
end

function testMainWindowExists(testCase)
% mainWindow(options) MUST be a callable function.
verifyNotEmpty(testCase, which('dicom2nifti.gui.mainWindow'));
end

function testMainWindowReturnsStruct(testCase)
% mainWindow MUST return a scalar struct even when no display.
r = dicom2nifti.gui.mainWindow({'Compression', 'none'});
verifyTrue(testCase, isstruct(r) && isscalar(r));
end

function testMainWindowFourFields(testCase)
% Result MUST have exactly: status, outputs, message, details.
r = dicom2nifti.gui.mainWindow({'Compression', 'none'});
verifyEqual(testCase, sort(fieldnames(r)), ...
    sort({'status';'outputs';'message';'details'}));
end

function testMainWindowCancelledShape(testCase)
% When GUI is unavailable (headless), status MUST be 'cancelled'.
r = dicom2nifti.gui.mainWindow({'Compression', 'none'});
verifyEqual(testCase, r.status, 'cancelled');
verifyEmpty(testCase, r.outputs);
verifyNotEmpty(testCase, r.message);
end

function testMainWindowForwardsOptions(testCase)
% Headless smoke: mainWindow(options) MUST accept arbitrary option combinations.
r = dicom2nifti.gui.mainWindow({'Compression', 'gz', 'Overwrite', true});
verifyEqual(testCase, r.status, 'cancelled');
verifyTrue(testCase, isstruct(r.details) && isscalar(r.details));
end

function testMainWindowChooserParity(testCase)
% Headless smoke: mainWindow({}) MUST return cancelled without error.
r = dicom2nifti.gui.mainWindow({});
verifyEqual(testCase, r.status, 'cancelled');
verifyEmpty(testCase, r.outputs);
verifyNotEmpty(testCase, r.message);
end
