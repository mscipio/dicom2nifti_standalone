function logPath = writeVersionLog(outputPath)
%WRITEVERSIONLOG Write a release record beside a delivered output.

outputDir = fileparts(outputPath);
if isempty(outputDir), outputDir = pwd; end
logPath = fullfile(outputDir, 'dcm2nii_version.txt');
fid = fopen(logPath, 'wt');
if fid < 0
    error('dicom2nifti:version:LogWriteFailed', ...
        'Could not write version record: %s', logPath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'dcm2nii version: %s\n', dicom2nifti.io.readVersion());
end
