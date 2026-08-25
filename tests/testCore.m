function tests = testCore()
%TESTCORE Focused unit tests for dicom2nifti.core package seams.
%   Covers fromNifti (uncompressed copy and .nii.gz decompression) and
%   resolveOutputs (single output, sidecar ignored, zero/non-NIfTI
%   rejection, multiple-NIfTI rejection). SPM-independent; uses temporary
%   fixtures and cleans up after each test.

tests = functiontests(localfunctions);
end

% ---------------------------------------------------------------------------
% Setup / teardown
% ---------------------------------------------------------------------------

function setupOnce(testCase)
% Ensure the repo root is on the MATLAB path so +dicom2nifti is reachable.
repoDir = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(repoDir, '-begin');
end

function [tmpDir, cleanupObj] = makeTempDir()
tmpDir = tempname(tempdir);
mkdir(tmpDir);
cleanupObj = onCleanup(@() rmdir(tmpDir, 's'));
end

% ---------------------------------------------------------------------------
% Shared fixture helpers
% ---------------------------------------------------------------------------

function p = makeMinimalNifti(directory)
% Write a minimal valid NIfTI-1 file and return its path.
% The header is coherent: sizeof_hdr=348, ndim=3, 1x1x1 uint8, magic='n+1\0'.
p = fullfile(directory, 'fixture.nii');
hdr = zeros(1, 348, 'uint8');
hdr(1:4)   = typecast(int32(348), 'uint8');        % sizeof_hdr = 348
hdr(41:42) = typecast(int16(3),   'uint8');        % dim[0] = 3 (ndim)
hdr(43:44) = typecast(int16(1),   'uint8');        % dim[1] = 1
hdr(45:46) = typecast(int16(1),   'uint8');        % dim[2] = 1
hdr(47:48) = typecast(int16(1),   'uint8');        % dim[3] = 1
hdr(71:72) = typecast(int16(2),   'uint8');        % datatype = uint8 (2)
hdr(73:74) = typecast(int16(8),   'uint8');        % bitpix = 8
hdr(345:348) = [110 43 49 0];                    % magic = 'n+1\0'
fid = fopen(p, 'w'); fwrite(fid, hdr); fclose(fid);
end

function gzPath = makeMinimalNiftiGz(directory)
% Write a minimal NIfTI-1 and gzip it; return the .nii.gz path.
niiPath = makeMinimalNifti(directory);
gzip(niiPath, directory);
candidates = dir(fullfile(directory, '*.nii.gz'));
if isempty(candidates)
    % Some MATLAB gzip() implementations name the output <basename>.gz
    gzPath = fullfile(directory, [extractFilenameNoExt(niiPath) '.nii.gz']);
    movefile([niiPath '.gz'], gzPath);
else
    gzPath = fullfile(directory, candidates(1).name);
end
end

function name = extractFilenameNoExt(filePath)
[~, name, ~] = fileparts(filePath);
if length(name) > 4 && strcmpi(name(end-3:end), '.nii')
    name = name(1:end-4);
end
end

function writeDummy(filePath)
fid = fopen(filePath, 'w'); fprintf(fid, 'x'); fclose(fid);
end

% ---------------------------------------------------------------------------
% dicom2nifti.core.fromNifti tests
% ---------------------------------------------------------------------------

function testFromNiftiUncompressedCopy(testCase)
% fromNifti on a plain .nii MUST copy the file and return the output path.
[tmpDir, cleanupObj] = makeTempDir();
srcDir = fullfile(tmpDir, 'src'); mkdir(srcDir);
outDir = fullfile(tmpDir, 'out'); mkdir(outDir);
src = makeMinimalNifti(srcDir);
outFile = fullfile(outDir, 'copied.nii');

result = dicom2nifti.core.fromNifti(src, outFile);

verifyEqual(testCase, result, outFile, 'Returned path must equal outputFile');
verifyTrue(testCase, exist(outFile, 'file') == 2, ...
    'Output file must be committed to disk');
% Source must still exist (copy, not move).
verifyTrue(testCase, exist(src, 'file') == 2, ...
    'Source file must remain after copy');
% Output bytes must equal source bytes (faithful copy).
fidSrc = fopen(src, 'rb'); srcBytes = fread(fidSrc, '*uint8')'; fclose(fidSrc);
fidOut = fopen(outFile, 'rb'); outBytes = fread(fidOut, '*uint8')'; fclose(fidOut);
verifyEqual(testCase, outBytes, srcBytes, ...
    'Copied file bytes must match source bytes exactly');
end

function testFromNiftiGzDecompression(testCase)
% fromNifti on a .nii.gz MUST decompress and return the output path.
[tmpDir, cleanupObj] = makeTempDir();
srcDir = fullfile(tmpDir, 'src'); mkdir(srcDir);
outDir = fullfile(tmpDir, 'out'); mkdir(outDir);
% Reference uncompressed fixture for byte comparison.
refDir = fullfile(tmpDir, 'ref'); mkdir(refDir);
refNii = makeMinimalNifti(refDir);
fidRef = fopen(refNii, 'rb'); originalBytes = fread(fidRef, '*uint8')'; fclose(fidRef);
src = makeMinimalNiftiGz(srcDir);
outFile = fullfile(outDir, 'decompressed.nii');

result = dicom2nifti.core.fromNifti(src, outFile);

verifyEqual(testCase, result, outFile, 'Returned path must equal outputFile');
verifyTrue(testCase, exist(outFile, 'file') == 2, ...
    'Decompressed output must be committed to disk');
% Decompressed bytes must equal original uncompressed fixture bytes.
fidOut = fopen(outFile, 'rb'); outBytes = fread(fidOut, '*uint8')'; fclose(fidOut);
verifyEqual(testCase, outBytes, originalBytes, ...
    'Decompressed bytes must match original uncompressed fixture exactly');
end

% ---------------------------------------------------------------------------
% dicom2nifti.core.resolveOutputs tests
% (Centralized from scripts/test_dcm2nii_integration.m cases 6a-6e.)
% ---------------------------------------------------------------------------

function testResolveOutputsSingleNii(testCase)
% Exactly one .nii in fileList MUST resolve to one absolute path.
[tmpDir, cleanupObj] = makeTempDir();
stage = fullfile(tmpDir, 'stage'); mkdir(stage);
writeDummy(fullfile(stage, 'one.nii'));

result = dicom2nifti.core.resolveOutputs({'one.nii'}, stage);

verifyEqual(testCase, numel(result), 1, 'Must resolve exactly one file');
verifyTrue(testCase, iscell(result), 'Result must be a cell array');
verifyEqual(testCase, result{1}, fullfile(stage, 'one.nii'), ...
    'Resolved path must equal stageDir/one.nii');
end

function testResolveOutputsIgnoresSidecar(testCase)
% 1 .nii + 1 .json MUST resolve to the single .nii (sidecar ignored).
[tmpDir, cleanupObj] = makeTempDir();
stage = fullfile(tmpDir, 'stage'); mkdir(stage);
writeDummy(fullfile(stage, 's.nii'));
writeDummy(fullfile(stage, 's.json'));

result = dicom2nifti.core.resolveOutputs({'s.nii', 's.json'}, stage);

verifyEqual(testCase, numel(result), 1, ...
    'Sidecar must be ignored; only .nii returned');
verifyEqual(testCase, result{1}, fullfile(stage, 's.nii'), ...
    'Resolved path must equal stageDir/s.nii');
end

function testResolveOutputsRejectsEmptyList(testCase)
% Empty fileList MUST error (zero outputs).
[tmpDir, cleanupObj] = makeTempDir();
stage = fullfile(tmpDir, 'stage'); mkdir(stage);

verifyError(testCase, ...
    @() dicom2nifti.core.resolveOutputs({}, stage), ...
    'dicom2nifti:core:ZeroOutputs');
end

function testResolveOutputsRejectsNonNifti(testCase)
% fileList with only non-.nii entries MUST error (zero .nii outputs).
[tmpDir, cleanupObj] = makeTempDir();
stage = fullfile(tmpDir, 'stage'); mkdir(stage);
writeDummy(fullfile(stage, 'sidecar.json'));

verifyError(testCase, ...
    @() dicom2nifti.core.resolveOutputs({'sidecar.json'}, stage), ...
    'dicom2nifti:core:ZeroNiftiOutputs');
end

function testResolveOutputsRejectsMultipleNii(testCase)
% fileList with >1 .nii MUST error (ambiguous output).
[tmpDir, cleanupObj] = makeTempDir();
stage = fullfile(tmpDir, 'stage'); mkdir(stage);
writeDummy(fullfile(stage, 'v1.nii'));
writeDummy(fullfile(stage, 'v2.nii'));

verifyError(testCase, ...
    @() dicom2nifti.core.resolveOutputs({'v1.nii', 'v2.nii'}, stage), ...
    'dicom2nifti:core:MultipleNiftiOutputs');
end
