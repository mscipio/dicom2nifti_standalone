function tests = testApi()
%TESTAPI Contract tests for dicom2nifti.api.run(). Baseline: 11 PASS / 0 FAIL.
tests = functiontests(localfunctions);
end

function testResultShape(testCase)
% Result MUST be scalar struct with exactly status/outputs/message/details
% and status MUST be in {success,partial,failed,cancelled}.
result = dicom2nifti.api.run(getNifti(), outFile());
verifyTrue(testCase, isstruct(result) && isscalar(result));
verifyEqual(testCase, sort(fieldnames(result)), ...
    sort({'status';'outputs';'message';'details'}));
valid = {'success','partial','failed','cancelled'};
verifyTrue(testCase, any(strcmp(result.status, valid)));
end

function testInvalidInputRaisesError(testCase)
% Nonexistent input MUST raise deterministic error (not return a result).
verifyError(testCase, ...
    @() dicom2nifti.api.run('/nonexistent/in.nii', '/tmp/out.nii'), ...
    'dicom2nifti:api:InvalidInput');
end

function testSuccessHasCommittedOutput(testCase)
% On success, outputs{1} lists committed absolute path that exists on disk.
result = dicom2nifti.api.run(getNifti(), outFile());
verifyEqual(testCase, result.status, 'success');
verifyNotEmpty(testCase, result.outputs);
verifyTrue(testCase, exist(result.outputs{1}, 'file') == 2);
end

function testCancelledReturnsEmpty(testCase)
% Facade 0-arg path (GUI→mainWindow→cancelled) maps to ''.
verifyEqual(testCase, dcm2nii(), '');
end

function testNiftiSkipsSpm(testCase)
% NIfTI pass-through MUST NOT load SPM — no spm_dicom_headers on path needed.
result = dicom2nifti.api.run(getNifti(), outFile());
verifyEqual(testCase, result.status, 'success');
verifyTrue(testCase, isfield(result.details,'spm_loaded') && ...
    ~result.details.spm_loaded, 'SPM must not load on NIfTI path');
end

function testCompressionGzProducesNiiGz(testCase)
% 'Compression','gz' MUST produce a .nii.gz committed output.
result = dicom2nifti.api.run(getNifti(), outFile(), 'Compression', 'gz');
verifyEqual(testCase, result.status, 'success');
outPath = result.outputs{1};
verifyTrue(testCase, length(outPath) >= 7 && ...
    strcmpi(outPath(end-6:end), '.nii.gz'), ...
    'Compressed output must end in .nii.gz');
end

function testRejectsDotI(testCase)
% .i input MUST raise dicom2nifti:api:InvalidExtension.
d = tempname(tempdir); mkdir(d);
fakeFile = fullfile(d, 'legacy.i');
outDir = tempname(tempdir); mkdir(outDir);
fid = fopen(fakeFile, 'w'); fwrite(fid, [0 0]); fclose(fid);
verifyError(testCase, ...
    @() dicom2nifti.api.run(fakeFile, fullfile(outDir, 'out.nii')), ...
    'dicom2nifti:api:InvalidExtension');
end

function testRejectsSameFile(testCase)
% Input == output MUST raise dicom2nifti:api:InputOutputSame.
niiFile = getNifti();
verifyError(testCase, ...
    @() dicom2nifti.api.run(niiFile, niiFile), ...
    'dicom2nifti:api:InputOutputSame');
end

function testRejectsCollisionWithoutOverwrite(testCase)
% Existing output without 'Overwrite',true MUST raise OutputExists.
niiFile = getNifti();
of = outFile();
% First conversion succeeds
result = dicom2nifti.api.run(niiFile, of);
verifyEqual(testCase, result.status, 'success');
% Second conversion collides on output + version log — must fail
verifyError(testCase, ...
    @() dicom2nifti.api.run(niiFile, of), ...
    'dicom2nifti:api:OutputExists');
end

function testConversionFaultReturnsFailed(testCase)
% R4: conversion fault → failed with outputs={}.
niiFile = getNifti();
gzDir = tempname(tempdir); mkdir(gzDir);
gzip(niiFile, gzDir);
gzFiles = dir(fullfile(gzDir, '*.nii.gz'));
niiGz = fullfile(gzDir, gzFiles(1).name);
od = tempname(tempdir); mkdir(od);
of = fullfile(od, 'out.nii');
system(['chmod a-w ' od]);
c = onCleanup(@() system(['chmod a+w ' od]));
result = dicom2nifti.api.run(niiGz, of);
verifyEqual(testCase, result.status, 'failed');
verifyEmpty(testCase, result.outputs);
verifyNotEmpty(testCase, result.message);
end

function testVersionLogFailureReturnsPartial(testCase)
% R4: version-log write failure → partial with committed NIfTI.
niiFile = getNifti();
d = tempname(tempdir); mkdir(d);
of = fullfile(d, 'out.nii');
% Create a directory where version log should go → write fails
mkdir(fullfile(d, 'dcm2nii_version.txt'));
result = dicom2nifti.api.run(niiFile, of);
verifyEqual(testCase, result.status, 'partial');
verifyTrue(testCase, exist(result.outputs{1}, 'file') == 2, ...
    'Committed NIfTI must be retained');
verifyTrue(testCase, isfield(result.details, 'version_log_error'));
end

function testCleanupNonMasking(testCase)
% R7: Cleanup silent on success, exception-path restores. Induction UNVERIFIED.
niiFile = getNifti();
of = outFile();
pBefore = path; cBefore = pwd;
lastwarn('');
result = dicom2nifti.api.run(niiFile, of);
[wmsg, wid] = lastwarn();
verifyEqual(testCase, result.status, 'success');
verifyFalse(testCase, isfield(result.details, 'cleanup_error'));
verifyEqual(testCase, path, pBefore);
verifyEqual(testCase, pwd, cBefore);
verifyTrue(testCase, isempty(wid)||~contains(wid,'CleanupError'));

% Exception path: cleanup preserves state, primary error unmasked
try
    dicom2nifti.api.run(niiFile, niiFile);
    verifyTrue(testCase, false, 'Expected InputOutputSame');
catch ME
    verifyEqual(testCase, ME.identifier, 'dicom2nifti:api:InputOutputSame');
    verifyEqual(testCase, path, pBefore);
    verifyEqual(testCase, pwd, cBefore);
end
end

function p = getNifti()
d = tempname(tempdir); mkdir(d); p = fullfile(d, 'fixture.nii');
h = zeros(1,348,'uint8'); h(1)=92; h(4)=1; h(40)=9;
h(43:44)=typecast(int16(1),'uint8'); h(45:46)=typecast(int16(1),'uint8');
h(47:48)=typecast(int16(1),'uint8'); h(71:72)=typecast(int16(2),'uint8');
h(73:74)=typecast(int16(16),'uint8'); h(345:348)=[110 43 49 0];
fid=fopen(p,'w'); fwrite(fid,h); fclose(fid);
end

function p = outFile()
d = tempname(tempdir); mkdir(d); p = fullfile(d, 'out.nii');
end
