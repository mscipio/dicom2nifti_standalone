function series = collectSeries(representativeFile)
%COLLECTSERIES Collect DICOM files in same directory by SeriesInstanceUID.
%   series = collectSeries(representativeFile)
%
%   Returns struct with:
%     files             - cell array of file paths in instance number order
%     instanceCount     - number of files
%     seriesInstanceUID - matched UID
%     modality          - MR, CT, or PT
%     seriesNumber      - DICOM series number
%     sourceDirectory   - directory containing the files
%     representativeFile - the input file

series = struct('files', {{}}, 'instanceCount', 0, ...
    'seriesInstanceUID', '', 'modality', '', 'seriesNumber', [], ...
    'sourceDirectory', '', 'representativeFile', '');

representativeFile = normalizePath(representativeFile);
fileEntry = dir(representativeFile);
if isempty(fileEntry) || fileEntry.isdir
    error('dicom2nifti:dicom:FileNotFound', ...
        'Representative file not found: %s', representativeFile);
end

% Read tags from representative file
tags = dicom2nifti.dicom.readTags(representativeFile);
if isempty(tags.SeriesInstanceUID)
    error('dicom2nifti:dicom:MissingUID', ...
        'Could not read SeriesInstanceUID from: %s', representativeFile);
end

series.seriesInstanceUID = tags.SeriesInstanceUID;
series.modality = normalizeModality(tags.Modality);
series.seriesNumber = tags.SeriesNumber;
series.sourceDirectory = fileparts(representativeFile);
series.representativeFile = representativeFile;

% Scan directory for matching files
dirEntries = dir(series.sourceDirectory);
maximumCount = numel(dirEntries);
matchingFiles = cell(maximumCount, 1);
instanceNumbers = nan(maximumCount, 1);
sopInstanceUIDs = cell(maximumCount, 1);
matchingCount = 0;

for index = 1:maximumCount
    entry = dirEntries(index);
    if entry.isdir, continue; end

    candidateFile = fullfile(series.sourceDirectory, entry.name);
    if strcmp(candidateFile, representativeFile)
        % Use representative file's tags directly
        candidateTags = tags;
    else
        try
            candidateTags = dicom2nifti.dicom.readTags(candidateFile);
        catch
            continue;
        end
    end

    if isempty(candidateTags.SeriesInstanceUID), continue; end
    if ~strcmp(candidateTags.SeriesInstanceUID, series.seriesInstanceUID), continue; end
    if ~strcmp(normalizeModality(candidateTags.Modality), series.modality)
        error('dicom2nifti:dicom:ModalityMismatch', ...
            'Series contains inconsistent modality metadata: %s', candidateFile);
    end

    matchingCount = matchingCount + 1;
    matchingFiles{matchingCount} = candidateFile;
    sopInstanceUIDs{matchingCount} = candidateTags.SOPInstanceUID;
    if ~isempty(candidateTags.InstanceNumber)
        instanceNumbers(matchingCount) = candidateTags.InstanceNumber;
    end
end

matchingFiles = matchingFiles(1:matchingCount);
instanceNumbers = instanceNumbers(1:matchingCount);
sopInstanceUIDs = sopInstanceUIDs(1:matchingCount);

if matchingCount == 0
    error('dicom2nifti:dicom:EmptySeries', ...
        'No files matched SeriesInstanceUID %s.', series.seriesInstanceUID);
end

nonemptySop = sopInstanceUIDs(~cellfun('isempty', sopInstanceUIDs));
if numel(unique(nonemptySop)) ~= numel(nonemptySop)
    error('dicom2nifti:dicom:DuplicateSOPInstanceUID', ...
        'Series contains duplicate SOPInstanceUID values.');
end

% Sort by instance number if available
validInstances = ~isnan(instanceNumbers);
if all(validInstances) && numel(unique(instanceNumbers)) == matchingCount
    [~, sortIdx] = sort(instanceNumbers);
    matchingFiles = matchingFiles(sortIdx);
else
    [~, sortIdx] = sort(matchingFiles);
    matchingFiles = matchingFiles(sortIdx);
end

series.files = matchingFiles;
series.instanceCount = matchingCount;
end

function modality = normalizeModality(value)
modality = upper(strtrim(value));
if strcmp(modality, 'PET'), modality = 'PT'; end
end

function path = normalizePath(path)
path = strtrim(path);
if isempty(path)
    error('dicom2nifti:dicom:EmptyPath', 'Representative file path is empty.');
end
if isunix && path(1) == '~'
    path = fullfile(getenv('HOME'), path(2:end));
end
end
