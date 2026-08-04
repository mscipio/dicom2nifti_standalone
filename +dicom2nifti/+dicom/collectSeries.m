function series = collectSeries(representativeFile)
%COLLECTSERIES Collect files with the exact SeriesInstanceUID.

series = struct('files', {{}}, 'instanceCount', 0, ...
    'seriesInstanceUID', '', 'modality', '', 'seriesNumber', [], ...
    'sourceDirectory', '', 'representativeFile', '');

representativeFile = normalizePath(representativeFile);
entry = dir(representativeFile);
if isempty(entry) || entry.isdir
    error('dicom2nifti:dicom:FileNotFound', ...
        'Representative DICOM file not found: %s', representativeFile);
end

requested = {'SeriesInstanceUID', 'Modality', 'SOPInstanceUID', ...
    'InstanceNumber', 'SeriesNumber'};
representativeTags = dicom2nifti.dicom.readTags(representativeFile, requested, true);
if isempty(representativeTags.SeriesInstanceUID)
    error('dicom2nifti:dicom:MissingUID', ...
        'Could not read SeriesInstanceUID from: %s', representativeFile);
end

series.seriesInstanceUID = representativeTags.SeriesInstanceUID;
series.modality = normalizeModality(representativeTags.Modality);
series.seriesNumber = representativeTags.SeriesNumber;
series.sourceDirectory = fileparts(representativeFile);
series.representativeFile = representativeFile;

entries = dir(series.sourceDirectory);
maximumCount = numel(entries);
matchingFiles = cell(maximumCount, 1);
instanceNumbers = nan(maximumCount, 1);
sopInstanceUIDs = cell(maximumCount, 1);
matchingCount = 0;
for index = 1:maximumCount
    if entries(index).isdir, continue; end
    candidateFile = fullfile(series.sourceDirectory, entries(index).name);
    if strcmp(candidateFile, representativeFile)
        candidateTags = representativeTags;
    else
        try
            % Candidate files never use full dicominfo; invalid/non-DICOM files
            % are simply not members of the selected series.
            candidateTags = dicom2nifti.dicom.readTags(candidateFile, ...
                {'SeriesInstanceUID', 'Modality', 'SOPInstanceUID', 'InstanceNumber'}, false);
        catch
            continue;
        end
    end
    if isempty(candidateTags.SeriesInstanceUID) || ...
            ~strcmp(candidateTags.SeriesInstanceUID, series.seriesInstanceUID)
        continue;
    end
    candidateModality = normalizeModality(candidateTags.Modality);
    if ~isempty(series.modality) && ~isempty(candidateModality) && ...
            ~strcmp(candidateModality, series.modality)
        error('dicom2nifti:dicom:ModalityMismatch', ...
            'Series contains inconsistent modality metadata: %s', candidateFile);
    end
    matchingCount = matchingCount + 1;
    matchingFiles{matchingCount} = candidateFile;
    sopInstanceUIDs{matchingCount} = candidateTags.SOPInstanceUID;
    if ~isempty(candidateTags.InstanceNumber)
        instanceNumbers(matchingCount) = double(candidateTags.InstanceNumber);
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

if all(~isnan(instanceNumbers)) && numel(unique(instanceNumbers)) == matchingCount
    [~, order] = sort(instanceNumbers);
else
    [~, order] = sort(matchingFiles);
end
series.files = matchingFiles(order);
series.instanceCount = matchingCount;
end

function modality = normalizeModality(value)
if ischar(value)
    modality = upper(strtrim(value));
else
    modality = '';
end
if strcmp(modality, 'PET'), modality = 'PT'; end
end

function pathValue = normalizePath(pathValue)
if ~ischar(pathValue) || isempty(strtrim(pathValue))
    error('dicom2nifti:dicom:EmptyPath', 'Representative file path is empty.');
end
pathValue = strtrim(pathValue);
if isunix && pathValue(1) == '~'
    pathValue = fullfile(getenv('HOME'), pathValue(2:end));
end
if isempty(fileparts(pathValue)), pathValue = fullfile(pwd, pathValue); end
end
