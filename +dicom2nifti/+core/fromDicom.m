function outputPath = fromDicom(inputFile, outputFile)
%FROMDICOM Convert DICOM series to NIfTI via SPM.
%   outputPath = fromDicom(inputFile, outputFile)
%
%   Collects DICOM files by SeriesInstanceUID, converts with SPM8,
%   promotes result to outputFile.

series = dicom2nifti.dicom.collectSeries(inputFile);

outputDir = fileparts(outputFile);
if isempty(outputDir), outputDir = pwd; end
if exist(outputDir, 'dir') ~= 7
    [ok, message] = mkdir(outputDir);
    if ~ok
        error('dicom2nifti:core:CreateOutputDirFailed', ...
            'Could not create output directory %s: %s', outputDir, message);
    end
end

stageDir = tempname(outputDir);
[ok, message] = mkdir(stageDir);
if ~ok
    error('dicom2nifti:core:CreateStageFailed', ...
        'Could not create conversion staging directory %s: %s', stageDir, message);
end
stageCleanup = onCleanup(@() cleanupDirectory(stageDir));
currentDir = pwd;
cd(stageDir);
cwdCleanup = onCleanup(@() cd(currentDir));

dcmFn = char(series.files);
hdr = spm_dicom_headers(dcmFn, true);
spm_dicom_convert(hdr, 'all', 'flat', 'nii');

tempOutput = fullfile(stageDir, 'Temp_spm.nii');
if exist(tempOutput, 'file') ~= 2
    error('dicom2nifti:core:ConversionFailed', ...
        'SPM did not produce output for: %s', inputFile);
end

[ok, message] = movefile(tempOutput, outputFile, 'f');
if ~ok
    error('dicom2nifti:core:PromoteFailed', ...
        'Could not promote converted NIfTI to %s: %s', outputFile, message);
end
outputPath = outputFile;
end

function cleanupDirectory(directory)
if exist(directory, 'dir') == 7
    rmdir(directory, 's');
end
end
