function outputPath = fromNifti(inputFile, outputFile)
%FROMNIFTI Copy or decompress an existing NIfTI file.

outputDir = fileparts(outputFile);
if isempty(outputDir), outputDir = pwd; end
if exist(outputDir, 'dir') ~= 7
    [ok, message] = mkdir(outputDir);
    if ~ok
        error('dicom2nifti:core:CreateOutputDirFailed', ...
            'Could not create output directory %s: %s', outputDir, message);
    end
end

[~, ~, extension] = fileparts(inputFile);
if strcmpi(extension, '.gz')
    stageDir = tempname(outputDir);
    [ok, message] = mkdir(stageDir);
    if ~ok
        error('dicom2nifti:core:CreateStageFailed', ...
            'Could not create decompression staging directory %s: %s', stageDir, message);
    end
    cleanup = onCleanup(@() cleanupDirectory(stageDir));
    gunzip(inputFile, stageDir);
    niiFiles = dir(fullfile(stageDir, '*.nii'));
    if isempty(niiFiles)
        error('dicom2nifti:core:DecompressFailed', ...
            'gunzip did not produce a .nii file for %s.', inputFile);
    end
    [ok, message] = movefile(fullfile(stageDir, niiFiles(1).name), outputFile, 'f');
    if ~ok
        error('dicom2nifti:core:PromoteFailed', ...
            'Could not promote decompressed NIfTI to %s: %s', outputFile, message);
    end
else
    [ok, message] = copyfile(inputFile, outputFile, 'f');
    if ~ok
        error('dicom2nifti:core:CopyFailed', ...
            'Could not copy NIfTI to %s: %s', outputFile, message);
    end
end
outputPath = outputFile;
end

function cleanupDirectory(directory)
if exist(directory, 'dir') == 7, rmdir(directory, 's'); end
end
