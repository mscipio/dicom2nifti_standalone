function outputPath = fromNifti(inputFile, outputFile)
%FROMNIFTI Copy or decompress NIfTI to destination.
%   outputPath = fromNifti(inputFile, outputFile)
%
%   Handles .nii (copy) and .nii.gz (gunzip).

outputDir = fileparts(outputFile);
if ~isempty(outputDir) && exist(outputDir, 'dir') ~= 7
    [ok, message] = mkdir(outputDir);
    if ~ok
        error('dicom2nifti:core:CreateOutputDirFailed', ...
            'Could not create output directory %s: %s', outputDir, message);
    end
end

[~, ~, ext] = fileparts(inputFile);
if strcmpi(ext, '.gz')
    % Decompress: gunzip to temp, then move
    tempDir = tempname(outputDir);
    [ok, message] = mkdir(tempDir);
    if ~ok
        error('dicom2nifti:core:CreateStageFailed', ...
            'Could not create decompression staging directory %s: %s', ...
            tempDir, message);
    end
    cleanup = onCleanup(@() localCleanup(tempDir));
    gunzip(inputFile, tempDir);
    % Find the uncompressed file
    niiFiles = dir(fullfile(tempDir, '*.nii'));
    if isempty(niiFiles)
        error('dicom2nifti:core:DecompressFailed', ...
            'gunzip did not produce .nii file');
    end
    [ok, message] = movefile(fullfile(tempDir, niiFiles(1).name), outputFile, 'f');
    if ~ok
        error('dicom2nifti:core:PromoteFailed', ...
            'Could not promote decompressed NIfTI to %s: %s', outputFile, message);
    end
else
    if ~sameFile(inputFile, outputFile)
        [ok, message] = copyfile(inputFile, outputFile, 'f');
        if ~ok
            error('dicom2nifti:core:CopyFailed', ...
                'Could not copy NIfTI to %s: %s', outputFile, message);
        end
    end
end
outputPath = outputFile;
end

function result = sameFile(first, second)
if ispc
    result = strcmpi(first, second);
else
    result = strcmp(first, second);
end
end

function localCleanup(dirPath)
if exist(dirPath, 'dir') == 7
    rmdir(dirPath, 's');
end
end
