function run_tests()
%RUN_TESTS Focused release checks that do not require clinical test data.

rootDir = fileparts(fileparts(mfilename('fullpath')));
originalPath = path;
cleanupPath = onCleanup(@() path(originalPath));
addpath(rootDir, '-begin');

releaseVersion = dicom2nifti.io.readVersion();
changelog = fileread(fullfile(rootDir, 'CHANGELOG.md'));
heading = ['^## \[' regexptranslate('escape', releaseVersion) '\]'];
assert(~isempty(regexp(changelog, heading, 'lineanchors', 'once')));
assert(strcmp(dicom2nifti.io.proposeName('MR', 11), 'mr_series_0011.nii'));

workDir = tempname;
mkdir(workDir);
cleanupDir = onCleanup(@() localCleanup(workDir));
source = fullfile(workDir, 'source.nii');
fid = fopen(source, 'wb');
assert(fid >= 0);
fwrite(fid, uint8(0:255), 'uint8');
fclose(fid);

copyPath = fullfile(workDir, 'copy.nii');
actualCopy = dcm2nii(source, copyPath);
assert(strcmp(actualCopy, copyPath));
assert(isequal(readBytes(source), readBytes(copyPath)));

gzipPath = fullfile(workDir, 'compressed.nii.gz');
actualGzip = dcm2nii(source, gzipPath);
assert(strcmp(actualGzip, gzipPath));
assert(exist(gzipPath, 'file') == 2);
assert(exist(source, 'file') == 2);

roundtripPath = fullfile(workDir, 'roundtrip.nii');
actualRoundtrip = dcm2nii(gzipPath, roundtripPath);
assert(strcmp(actualRoundtrip, roundtripPath));
assert(isequal(readBytes(source), readBytes(roundtripPath)));
assert(exist(fullfile(workDir, 'dcm2nii_version.txt'), 'file') == 2);

originalDir = pwd;
cd(workDir);
cleanupPwd = onCleanup(@() cd(originalDir));
relativePath = dcm2nii('source.nii', 'relative.nii');
assert(strcmp(relativePath, fullfile(workDir, 'relative.nii')));
assert(isequal(readBytes(source), readBytes(relativePath)));
clear cleanupPwd;

fprintf(['Focused tests passed: version, NIfTI copy, gzip, gunzip, ' ...
    'source preservation, relative paths.\n']);
end

function bytes = readBytes(filePath)
fid = fopen(filePath, 'rb');
assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid));
bytes = fread(fid, inf, '*uint8');
end

function localCleanup(directory)
if exist(directory, 'dir') == 7, rmdir(directory, 's'); end
end
