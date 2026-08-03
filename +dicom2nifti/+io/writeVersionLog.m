function logPath = writeVersionLog(outputPath, overwrite)
%WRITEVERSIONLOG Write a release record beside the delivered output.

if nargin < 2, overwrite = false; end
outputDir = fileparts(outputPath);
if isempty(outputDir), outputDir = pwd; end
logPath = fullfile(outputDir, 'dcm2nii_version.txt');
if (exist(logPath, 'file') == 2 || exist(logPath, 'dir') == 7) && ~overwrite
    error('dicom2nifti:version:LogExists', ...
        'Version record already exists and was not overwritten: %s', logPath);
end
fid = fopen(logPath, 'wt');
if fid < 0
    error('dicom2nifti:version:LogWriteFailed', ...
        'Could not write version record: %s', logPath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'dcm2nii version: %s\n', dicom2nifti.io.readVersion());
end
