function tests = testEntrypoint()
% Legacy dcm2nii facade contract tests.
tests = functiontests(localfunctions);
end

function fix = setupOnce(testCase)
fix = struct();
fix.root = fileparts(fileparts(mfilename('fullpath')));
addpath(fix.root, '-begin');
addpath(fullfile(fix.root, 'config'), '-begin');
tmp = tempname(tempdir); mkdir(tmp);
fix.tmp = tmp;

% NIfTI-1 fixture
fix.nii = fullfile(tmp, 'entry_fixture.nii');
h = zeros(1,348,'uint8'); h(1)=92; h(4)=1; h(40)=9;
h(43:44)=typecast(int16(1),'uint8'); h(45:46)=typecast(int16(1),'uint8');
h(47:48)=typecast(int16(1),'uint8'); h(71:72)=typecast(int16(2),'uint8');
h(73:74)=typecast(int16(16),'uint8'); h(345:348)=[110 43 49 0];
fid = fopen(fix.nii,'w'); fwrite(fid,h); fclose(fid);

gzip(fix.nii, tmp);
gzFiles = dir(fullfile(tmp, '*.nii.gz'));
fix.niiGz = fullfile(tmp, gzFiles(1).name);
testCase.TestData.fix = fix;
end

function teardownOnce(testCase)
f = testCase.TestData.fix;
if exist(f.tmp, 'dir') == 7, rmdir(f.tmp, 's'); end
end

function testSuccess_ReturnsPath(testCase)
f = testCase.TestData.fix;
d = fullfile(f.tmp, 'okdir'); mkdir(d);
out = fullfile(d, 'ok.nii');
r = dcm2nii(f.nii, out);
verifyEqual(testCase, r, out);
verifyTrue(testCase, exist(out, 'file') == 2);
end

function testNargoutZero_Silent(testCase)
f = testCase.TestData.fix;
d = fullfile(f.tmp, 'sild'); mkdir(d);
out = fullfile(d, 'silent.nii');
dcm2nii(f.nii, out);
verifyTrue(testCase, exist(out, 'file') == 2);
end

function testGzToNii_PassThrough(testCase)
f = testCase.TestData.fix;
d = fullfile(f.tmp, 'gzd'); mkdir(d);
out = fullfile(d, 'fromgz.nii');
r = dcm2nii(f.niiGz, out);
verifyEqual(testCase, r, out);
verifyTrue(testCase, exist(out, 'file') == 2);
end

function testFailure_NonexistentInput(testCase)
f = testCase.TestData.fix;
verifyError(testCase, @() dcm2nii('/no/such/file.nii', fullfile(f.tmp, 'x.nii')), 'dcm2nii:InvalidInput');
end

function testFailure_SameFile(testCase)
f = testCase.TestData.fix;
d = fullfile(f.tmp, 'same_d'); mkdir(d);
same = fullfile(d, 'same.nii'); copyfile(f.nii, same);
    verifyError(testCase, @() dcm2nii(same, same), 'dcm2nii:InputOutputSame');
end

function testFailure_LegacyI_Rejected(testCase)
f = testCase.TestData.fix;
legacy = fullfile(f.tmp, 'legacy.i');
fid = fopen(legacy, 'w'); fprintf(fid, 'dummy\n'); fclose(fid);
verifyError(testCase, @() dcm2nii(legacy, fullfile(f.tmp, 'out.nii')), ...
    'dcm2nii:UnsupportedInput');
end

function testCancelled_ReturnsEmpty(testCase)
% dcm2nii() and dcm2nii(options) both return '' in headless.
verifyEqual(testCase, dcm2nii(), '');
verifyEqual(testCase, dcm2nii('Compression', 'gz'), '');
end

function testPathCwd_Restored(testCase)
f = testCase.TestData.fix;
d = fullfile(f.tmp, 'restdir'); mkdir(d);
pBefore = path; cBefore = pwd;
dcm2nii(f.nii, fullfile(d, 'restore.nii'));
verifyEqual(testCase, path, pBefore);
verifyEqual(testCase, pwd, cBefore);
end

function testOneArgAutoName(testCase)
% dcm2nii(input) auto-proposes output.
f = testCase.TestData.fix;
d = fullfile(f.tmp, 'oneArg'); mkdir(d);
srcGz = fullfile(d, 'source_copy.nii.gz');
copyfile(f.niiGz, srcGz);
r = dcm2nii(srcGz);
verifyTrue(testCase, ischar(r) && ~isempty(r) && endsWith(r, '.nii'));
verifyTrue(testCase, exist(r, 'file') == 2);
end

function testOneArgWithCompression(testCase)
% dcm2nii(input, 'Compression', 'gz') returns compressed path.
f = testCase.TestData.fix;
d = fullfile(f.tmp, 'oneArgGz'); mkdir(d);
[~, fBase] = fileparts(f.nii);
out = fullfile(d, [fBase '.nii.gz']);
r = dcm2nii(f.nii, out);
verifyTrue(testCase, endsWith(r, '.nii.gz'));
verifyTrue(testCase, exist(r, 'file') == 2);
end

function testTwoArgWithOptions(testCase)
% dcm2nii(input, output, 'Overwrite', true) forwards options.
f = testCase.TestData.fix;
d = fullfile(f.tmp, 'twoArgOpts'); mkdir(d);
out = fullfile(d, 'withopt.nii');
r = dcm2nii(f.nii, out, 'Overwrite', true);
verifyEqual(testCase, r, out);
verifyTrue(testCase, exist(out, 'file') == 2);
end
