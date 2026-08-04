function test_dcm2nii_integration()
%TEST_DCM2NII_INTEGRATION  Focused integration checks for the standalone
%   dcm2nii converter. Covers input-type handling, output cardinality,
%   SPM authority, state restoration, and edge cases. Unavailable fixtures,
%   profiles, or runtimes are explicitly reported as UNVERIFIED.

rootDir = fileparts(mfilename('fullpath'));
repoDir = fullfile(rootDir, '..');
addpath(repoDir, '-begin');
addpath(fullfile(repoDir, 'config'), '-begin');

passed = 0; failed = 0; unverified = 0;

fprintf('\n===== test_dcm2nii_integration =====\n');
fprintf('MATLAB: %s | Platform: %s\n', version, computer);

% --- Environment ---
hasHeaders = ~isempty(which('spm_dicom_headers'));
hasConvert = ~isempty(which('spm_dicom_convert'));
spmReady = hasHeaders && hasConvert;
fprintf('spm_dicom_headers: %d | spm_dicom_convert: %d | ready: %d\n\n', ...
    hasHeaders, hasConvert, spmReady);

% --- Fixtures ---
tmpRoot = tempname(tempdir);
mkdir(tmpRoot);
fixtureDir = fullfile(tmpRoot, 'fixtures');
mkdir(fixtureDir);

niiFixture = fullfile(fixtureDir, 'test.nii');
createMinimalNifti(niiFixture);

niiGzFixture = fullfile(fixtureDir, 'test.nii.gz');
gzip(niiFixture, fixtureDir);
gzList = dir(fullfile(fixtureDir, '*.nii.gz'));
if isempty(gzList)
    movefile(fullfile(fixtureDir, 'test.nii.gz'), niiGzFixture);
else
    niiGzFixture = fullfile(fixtureDir, gzList(1).name);
end

iFixture = fullfile(fixtureDir, 'legacy.i');
fid = fopen(iFixture, 'w'); fprintf(fid, 'dummy legacy\n'); fclose(fid);
fprintf('Fixtures created in: %s\n\n', fixtureDir);

% --- Test 1: NIfTI .nii pass-through ---
fprintf('--- 1. NIfTI (.nii) pass-through ---\n');
outDir1 = fullfile(tmpRoot, 'test1'); mkdir(outDir1);
output1 = fullfile(outDir1, 'out1.nii');
try
    result = dcm2nii(niiFixture, output1);
    if strcmp(result, output1) && exist(output1, 'file') == 2
        fprintf('  PASS: .nii pass-through -> %s\n', result);
        passed = passed + 1;
    else
        fprintf('  FAIL: bad result or missing output\n');
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% --- Test 2: NIfTI .nii.gz pass-through ---
fprintf('--- 2. NIfTI (.nii.gz) pass-through ---\n');
outDir2 = fullfile(tmpRoot, 'test2'); mkdir(outDir2);
output2 = fullfile(outDir2, 'out2.nii');
try
    result = dcm2nii(niiGzFixture, output2);
    if strcmp(result, output2) && exist(output2, 'file') == 2
        fprintf('  PASS: .nii.gz pass-through -> %s\n', result);
        passed = passed + 1;
    else
        fprintf('  FAIL: bad result or missing output\n');
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% --- Test 3: Path/CWD restoration after successful conversion ---
fprintf('--- 3. Path/CWD restoration (success) ---\n');
outDir3 = fullfile(tmpRoot, 'test3'); mkdir(outDir3);
output3 = fullfile(outDir3, 'out3.nii');
pathBefore = path; cwdBefore = pwd;
try
    dcm2nii(niiFixture, output3);
    pathAfter = path; cwdAfter = pwd;
    pathOk = strcmp(pathBefore, pathAfter);
    cwdOk = strcmp(cwdBefore, cwdAfter);
    if pathOk && cwdOk
        fprintf('  PASS: path and cwd restored after success\n');
        passed = passed + 1;
    else
        if ~pathOk, fprintf('  FAIL: path NOT restored\n'); end
        if ~cwdOk, fprintf('  FAIL: cwd NOT restored\n'); end
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
if exist(output3, 'file') == 2, delete(output3); end

% --- Test 4: Path/CWD restoration after error ---
fprintf('--- 4. Path/CWD restoration (error) ---\n');
pathBefore = path; cwdBefore = pwd;
try
    dcm2nii(fullfile(tmpRoot, 'does_not_exist.nii'), fullfile(tmpRoot, 'out4.nii'));
    fprintf('  FAIL: expected error for nonexistent input, none raised\n');
    failed = failed + 1;
catch ME
    pathAfter = path; cwdAfter = pwd;
    pathOk = strcmp(pathBefore, pathAfter);
    cwdOk = strcmp(cwdBefore, cwdAfter);
    if pathOk && cwdOk
        fprintf('  PASS: path and cwd restored after error\n');
        passed = passed + 1;
    else
        if ~pathOk, fprintf('  FAIL: path NOT restored after error\n'); end
        if ~cwdOk, fprintf('  FAIL: cwd NOT restored after error\n'); end
        failed = failed + 1;
    end
end

% --- Test 5: .i file rejection (explicit error before DICOM routing) ---
fprintf('--- 5. .i file rejection ---\n');
try
    dcm2nii(iFixture, fullfile(tmpRoot, 'out5.nii'));
    fprintf('  FAIL: .i file should have been rejected\n');
    failed = failed + 1;
catch ME
    if strcmp(ME.identifier, 'dcm2nii:UnsupportedInput')
        fprintf('  PASS: .i rejected with dcm2nii:UnsupportedInput\n');
        passed = passed + 1;
    else
        fprintf('  FAIL: .i rejected but wrong identifier: %s\n', ME.identifier);
        failed = failed + 1;
    end
end

% --- Test 6: resolveOutputs unit tests ---
fprintf('--- 6. resolveOutputs unit tests ---\n');
stage = fullfile(tmpRoot, 'rsv_test'); mkdir(stage);

% 6a: exactly one .nii
dummyFile(fullfile(stage, 'one.nii'));
try
    r = dicom2nifti.core.resolveOutputs({'one.nii'}, stage);
    assert(numel(r) == 1, 'expected 1');
    fprintf('  PASS 6a: single .nii resolved\n'); passed = passed + 1;
catch ME, fprintf('  FAIL 6a: %s\n', ME.message); failed = failed + 1; end

% 6b: zero outputs — must error
try
    dicom2nifti.core.resolveOutputs({}, stage);
    fprintf('  FAIL 6b: empty list did not error\n'); failed = failed + 1;
catch ME
    assert(contains(ME.message, 'no output'), 'wrong error for empty list');
    fprintf('  PASS 6b: empty file list rejected\n'); passed = passed + 1;
end

% 6c: zero .nii (non-.nii files only) — must error
dummyFile(fullfile(stage, 'sidecar.json'));
try
    dicom2nifti.core.resolveOutputs({'sidecar.json'}, stage);
    fprintf('  FAIL 6c: non-.nii list did not error\n'); failed = failed + 1;
catch ME
    assert(contains(ME.message, 'no .nii'), 'wrong error for non-.nii list');
    fprintf('  PASS 6c: non-.nii-only rejected\n'); passed = passed + 1;
end

% 6d: multiple .nii — must error
dummyFile(fullfile(stage, 'v1.nii')); dummyFile(fullfile(stage, 'v2.nii'));
try
    dicom2nifti.core.resolveOutputs({'v1.nii', 'v2.nii'}, stage);
    fprintf('  FAIL 6d: multiple .nii did not error\n'); failed = failed + 1;
catch ME
    assert(contains(ME.message, 'expected exactly 1'), 'wrong error for multiple .nii');
    fprintf('  PASS 6d: multiple .nii rejected\n'); passed = passed + 1;
end

% 6e: 1 .nii + 1 .json — single .nii selected
dummyFile(fullfile(stage, 's.nii')); dummyFile(fullfile(stage, 's.json'));
try
    r = dicom2nifti.core.resolveOutputs({'s.nii', 's.json'}, stage);
    assert(numel(r) == 1, 'expected 1 from mixed list');
    fprintf('  PASS 6e: 1 .nii + .json -> single .nii\n'); passed = passed + 1;
catch ME, fprintf('  FAIL 6e: %s\n', ME.message); failed = failed + 1; end

% --- Test 7: SPM authority — incomplete SPM ---
fprintf('--- 7. SPM authority: incomplete SPM ---\n');
fprintf('  UNVERIFIED: requires MATLAB path manipulation. Remove one\n');
fprintf('              of spm_dicom_headers or spm_dicom_convert from\n');
fprintf('              path and run dcm2nii on a DICOM file. Must fail\n');
fprintf('              with SpmIncomplete.\n');
unverified = unverified + 1;

% --- Test 8: SPM authority — complete caller passthrough ---
fprintf('--- 8. SPM authority: caller passthrough ---\n');
fprintf('  UNVERIFIED: requires SPM functions in separate directories\n');
fprintf('              (e.g. standard SPM8 + vers/ override). Confirm\n');
fprintf('              dcm2nii no longer rejects same-directory SPM\n');
fprintf('              (SpmMixedInstallations guard was removed).\n');
unverified = unverified + 1;

% --- Test 9: DICOM conversion with real fixture ---
fprintf('--- 9. DICOM conversion (real fixture) ---\n');
if spmReady
    fprintf('  UNVERIFIED: SPM DICOM available but no fixture provided.\n');
    fprintf('              Manual: dcm2nii(''/path/to/mr.dcm'', ''out.nii'')\n');
    fprintf('              Verify exactly one .nii is produced.\n');
else
    fprintf('  UNVERIFIED: SPM DICOM functions not on MATLAB path.\n');
end
unverified = unverified + 1;

% --- Test 10: vers/spm_dicom_convert.m untouched ---
fprintf('--- 10. vers/spm_dicom_convert.m safeguard ---\n');
fprintf('  UNVERIFIED: manual check — confirm pseudoCT/vers/\n');
fprintf('              spm_dicom_convert.m byte-content matches\n');
fprintf('              the pre-change baseline.\n');
unverified = unverified + 1;

% --- Test 11: Shared-temp overwrite sequencing (mprage.nii, ref_file.nii) ---
fprintf('--- 11. Shared-temp overwrite sequencing ---\n');
sharedDir = fullfile(tmpRoot, 'test_shared'); mkdir(sharedDir);
mprageOut = fullfile(sharedDir, 'mprage.nii');
refOut = fullfile(sharedDir, 'ref_file.nii');
try
    result1 = dcm2nii(niiFixture, mprageOut, 'Overwrite', true);
    result2 = dcm2nii(niiFixture, refOut, 'Overwrite', true);
    if strcmp(result1, mprageOut) && exist(mprageOut, 'file') == 2 ...
            && strcmp(result2, refOut) && exist(refOut, 'file') == 2
        fprintf('  PASS: mprage.nii + ref_file.nii in shared temp dir\n');
        passed = passed + 1;
    else
        fprintf('  FAIL: shared-temp sequence did not produce both outputs\n');
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: shared-temp sequence error: %s\n', ME.message);
    failed = failed + 1;
end

% --- Cleanup & Report ---
rmdir(tmpRoot, 's');

total = passed + failed + unverified;
fprintf('\n===== Summary =====\n');
fprintf('  Passed:     %d/%d\n', passed, total);
fprintf('  Failed:     %d/%d\n', failed, total);
fprintf('  Unverified: %d/%d\n', unverified, total);
fprintf('==================\n');

if failed > 0
    error('test_dcm2nii_integration:AssertionFailed', ...
        '%d of %d tests FAILED.', failed, total);
end
end

% -------------------------------------------------------------------------
% Helper functions
% -------------------------------------------------------------------------

function createMinimalNifti(filePath)
% Create a minimal valid NIfTI-1 header (348 bytes, n+1 magic).
hdr = zeros(1, 348, 'uint8');
hdr(1) = 92; hdr(4) = 1;               % sizeof_hdr = 348
hdr(40) = 9;                            % dim[0] = 3
hdr(43:44) = typecast(int16(1), 'uint8');   % dim[1] = 1
hdr(45:46) = typecast(int16(1), 'uint8');   % dim[2] = 1
hdr(47:48) = typecast(int16(1), 'uint8');   % dim[3] = 1
hdr(71:72) = typecast(int16(2), 'uint8');   % datatype = 2 (uint8)
hdr(73:74) = typecast(int16(16), 'uint8');  % bitpix = 16
hdr(345:348) = [110 43 49 0];               % magic = 'n+1\0'
fid = fopen(filePath, 'w'); fwrite(fid, hdr); fclose(fid);
end

function dummyFile(filePath)
% Write a tiny placeholder file for resolveOutputs fixture use.
fid = fopen(filePath, 'w'); fprintf(fid, 'x'); fclose(fid);
end
