function outputPath = fromPet(inputFile, outputFile, overwrite)
%FROMPET Convert static PET or legacy-style dynamic/gated PET to NIfTI.
%   Dynamic frames are grouped by AcquisitionTime. If AcquisitionTime is
%   constant and TriggerTime has multiple values, TriggerTime is used for
%   gating. Each frame is converted independently through SPM.

if nargin < 3, overwrite = false; end
series = dicom2nifti.dicom.collectSeries(inputFile);
fields = {'AcquisitionTime', 'ActualFrameDuration', 'TriggerTime', ...
    'NumberOfTimeSlices', 'NumberOfTimeSlots'};
acquisitionSeconds = nan(series.instanceCount, 1);
triggerTimes = nan(series.instanceCount, 1);
frameDurations = nan(series.instanceCount, 1);
declaredVolumes = nan(series.instanceCount, 1);

for index = 1:series.instanceCount
    tags = dicom2nifti.dicom.readTags(series.files{index}, fields, false);
    acquisitionSeconds(index) = parseDicomTime(tags.AcquisitionTime);
    triggerTimes(index) = parseNumber(tags.TriggerTime);
    frameDurations(index) = parseNumber(tags.ActualFrameDuration);
    timeSlices = parseNumber(tags.NumberOfTimeSlices);
    timeSlots = parseNumber(tags.NumberOfTimeSlots);
    if isfinite(timeSlices)
        declaredVolumes(index) = timeSlices;
    elseif isfinite(timeSlots)
        declaredVolumes(index) = timeSlots;
    end
end

[groups, frameInfo] = groupFrames(acquisitionSeconds, triggerTimes, ...
    frameDurations, declaredVolumes);
if isempty(groups)
    outputPath = dicom2nifti.core.fromDicom(inputFile, outputFile);
    return;
end
requireDynamicPetSpm();

outputDir = fileparts(outputFile);
if isempty(outputDir), outputDir = pwd; end
frameInfoPath = fullfile(outputDir, 'Frame_info.txt');
if (exist(frameInfoPath, 'file') == 2 || exist(frameInfoPath, 'dir') == 7) && ~overwrite
    error('dicom2nifti:core:FrameInfoExists', ...
        'Frame_info.txt already exists and was not overwritten: %s', frameInfoPath);
end

stageDir = tempname(outputDir);
[ok, message] = mkdir(stageDir);
if ~ok
    error('dicom2nifti:core:CreateStageFailed', ...
        'Could not create PET staging directory %s: %s', stageDir, message);
end
cleanup = onCleanup(@() cleanupDirectory(stageDir));

images = [];
referenceVolume = [];
for frame = 1:numel(groups)
    frameDir = fullfile(stageDir, sprintf('frame_%03d', frame));
    [ok, message] = mkdir(frameDir);
    if ~ok
        error('dicom2nifti:core:CreateFrameStageFailed', ...
            'Could not create PET frame staging directory %s: %s', frameDir, message);
    end
    [framePath, volume] = convertFrame(series.files(groups{frame}), frameDir, inputFile);
    frameImage = spm_read_vols(volume(1));
    if isempty(referenceVolume)
        referenceVolume = volume(1);
        images = zeros([size(frameImage) numel(groups)]);
    elseif any(size(frameImage) ~= size(images(:, :, :, 1))) || ...
            any(abs(referenceVolume.mat(:) - volume(1).mat(:)) > 1e-6)
        error('dicom2nifti:core:PetFrameGeometryMismatch', ...
            'PET frames do not have matching dimensions and geometry: %s', framePath);
    end
    images(:, :, :, frame) = frameImage; %#ok<AGROW>
end

standardPath = fullfile(stageDir, 'PET_4D_standard.nii');
writeFourD(standardPath, images, referenceVolume);
pmodPath = fullfile(stageDir, 'PET_4D_pmod.nii');
writePmodNifti(standardPath, pmodPath, frameInfo);

[ok, message] = movefile(pmodPath, outputFile, 'f');
if ~ok
    error('dicom2nifti:core:PromoteFailed', ...
        'Could not promote PET 4D output to %s: %s', outputFile, message);
end

frameInfoStage = fullfile(stageDir, 'Frame_info.txt');
writeFrameInfo(frameInfoStage, frameInfo);
[ok, message] = movefile(frameInfoStage, frameInfoPath, 'f');
if ~ok
    error('dicom2nifti:core:FrameInfoWriteFailed', ...
        'Could not promote Frame_info.txt to %s: %s', frameInfoPath, message);
end
outputPath = outputFile;
clear cleanup;
end

function [groups, frameInfo] = groupFrames(acquisitionSeconds, triggerTimes, ...
    frameDurations, declaredVolumes)
groups = {};
frameInfo = [];
validAcquisition = acquisitionSeconds(isfinite(acquisitionSeconds));
validTrigger = triggerTimes(isfinite(triggerTimes));
declared = declaredVolumes(isfinite(declaredVolumes) & declaredVolumes > 0);
if isempty(declared)
    declaredCount = 1;
else
    declaredCount = round(declared(1));
end

uniqueAcquisition = unique(validAcquisition);
uniqueTrigger = unique(validTrigger);
if numel(uniqueAcquisition) <= 1 && numel(uniqueTrigger) <= 1 && declaredCount <= 1
    return;
end
if numel(uniqueAcquisition) > 1
    if any(~isfinite(acquisitionSeconds))
        error('dicom2nifti:core:PetMissingAcquisitionTime', ...
            'Dynamic PET contains files without AcquisitionTime.');
    end
    keys = uniqueAcquisition;
    useTrigger = false;
elseif numel(uniqueTrigger) > 1
    if any(~isfinite(triggerTimes))
        error('dicom2nifti:core:PetMissingTriggerTime', ...
            'Gated PET contains files without TriggerTime.');
    end
    keys = uniqueTrigger;
    useTrigger = true;
elseif declaredCount > 1
    error('dicom2nifti:core:PetGroupingUnavailable', ...
        'PET declares multiple frames but has no usable acquisition or trigger grouping.');
else
    return;
end

if declaredCount > 1 && numel(keys) ~= declaredCount
    error('dicom2nifti:core:PetFrameCountMismatch', ...
        'DICOM declares %d PET frames but metadata yields %d groups.', ...
        declaredCount, numel(keys));
end
groups = cell(numel(keys), 1);

if useTrigger
    frameStarts = zeros(numel(keys), 1);
else
    frameStarts = zeros(numel(keys), 1);
    for index = 1:numel(keys)
        frameStarts(index) = elapsedSeconds(uniqueAcquisition(1), keys(index));
    end
end
frameInfo = zeros(numel(keys), 2);
for index = 1:numel(keys)
    if useTrigger
        members = find(triggerTimes == keys(index));
    else
        members = find(acquisitionSeconds == keys(index));
    end
    if isempty(members), error('dicom2nifti:core:PetEmptyFrame', 'PET frame group is empty.'); end
    groups{index} = members;
    durations = frameDurations(members);
    durations = durations(isfinite(durations));
    if isempty(durations)
        error('dicom2nifti:core:PetMissingFrameDuration', ...
            'PET frame %d has no ActualFrameDuration.', index);
    end
    frameInfo(index, :) = [frameStarts(index) durations(1) / 1000];
end
end

function [framePath, volume] = convertFrame(files, frameDir, inputFile)
oldDir = pwd;
cd(frameDir);
cleanup = onCleanup(@() cd(oldDir));
headers = spm_dicom_headers(char(files), true);
spm_dicom_convert(headers, 'all', 'flat', 'nii');
framePath = fullfile(frameDir, 'Temp_spm.nii');
if exist(framePath, 'file') ~= 2
    error('dicom2nifti:core:PetFrameConversionFailed', ...
        'SPM did not produce a NIfTI frame for %s.', inputFile);
end

volume = spm_vol(framePath);
if numel(volume) ~= 1
    error('dicom2nifti:core:PetFrameConversionFailed', ...
        'SPM produced more than one volume for PET frame %s.', framePath);
end
clear cleanup;
end

function requireDynamicPetSpm()
required = {'spm_vol', 'spm_vol_nifti', 'spm_read_vols', ...
    'spm_create_vol', 'spm_write_vol', 'spm_type'};
missing = {};
for index = 1:numel(required)
    if exist(required{index}, 'file') ~= 2
        missing{end + 1} = required{index}; %#ok<AGROW>
    end
end
if ~isempty(missing)
    error('dicom2nifti:core:DynamicPetSpmIncomplete', ...
        ['Dynamic/gated PET requires complete SPM NIfTI support. Missing: %s. ' ...
         'The legacy 4D writer cannot run with this SPM installation.'], ...
        strjoin(missing, ', '));
end
end

function writeFourD(outputFile, images, template)
volume = template(1);
volume.fname = outputFile;
volume.n = [size(images, 4) 1];
volume.dt = [spm_type('float32') volume.dt(2)];
volume.pinfo = [1; 0; 0];
volume.descrip = 'dcm2nii PET 4D';
volume = spm_create_vol(volume);
for index = 1:size(images, 4)
    frame = volume;
    frame.n = [index 1];
    frame.pinfo = [1; 0; 0];
    spm_write_vol(frame, images(:, :, :, index));
end
end

function writePmodNifti(sourceFile, destinationFile, frameInfo)
% Reproduce the legacy PMOD timing extension without depending on the
% unavailable save_nii_hdr_david helper in the Aether folder.
[source, machineFormat] = openNifti(sourceFile);
cleanupSource = onCleanup(@() fclose(source));
fseek(source, 0, 'bof');
header = fread(source, 348, '*uint8');
fseek(source, 108, 'bof');
sourceOffset = double(fread(source, 1, '*single'));
if numel(header) ~= 348 || ~isfinite(sourceOffset) || sourceOffset < 352
    error('dicom2nifti:core:InvalidNiftiStage', ...
        'SPM produced an invalid NIfTI header for PMOD annotation.');
end

extension = makePmodExtension(frameInfo, machineFormat);
destination = fopen(destinationFile, 'wb', machineFormat);
if destination < 0
    error('dicom2nifti:core:PmodWriteFailed', ...
        'Could not create PMOD PET output: %s', destinationFile);
end
writeSucceeded = false;
cleanupDestination = onCleanup(@() closeAndDelete(destination, destinationFile, writeSucceeded));
fwrite(destination, header, 'uint8');
fseek(destination, 108, 'bof');
fwrite(destination, single(352 + numel(extension)), 'float32');
fseek(destination, 348, 'bof');
fwrite(destination, uint8([1 0 0 0]), 'uint8');
fseek(destination, 352, 'bof');
fwrite(destination, extension, 'uint8');

fseek(source, sourceOffset, 'bof');
copyBytes(source, destination);
fclose(destination);
writeSucceeded = true; %#ok<NASGU> % Shared with the onCleanup callback.
clear cleanupDestination;
if exist(destinationFile, 'file') ~= 2
    error('dicom2nifti:core:PmodWriteFailed', ...
        'PMOD PET output was not created: %s', destinationFile);
end
clear cleanupSource;
end

function [fid, machineFormat] = openNifti(filePath)
machineFormat = 'ieee-le';
fid = fopen(filePath, 'rb', machineFormat);
if fid < 0
    error('dicom2nifti:core:PmodReadFailed', 'Could not read NIfTI stage: %s', filePath);
end
sizeHeader = fread(fid, 1, '*int32');
if isempty(sizeHeader) || sizeHeader ~= 348
    fclose(fid);
    machineFormat = 'ieee-be';
    fid = fopen(filePath, 'rb', machineFormat);
    sizeHeader = fread(fid, 1, '*int32');
end
if isempty(sizeHeader) || sizeHeader ~= 348
    closeFile(fid);
    error('dicom2nifti:core:PmodReadFailed', ...
        'NIfTI stage does not contain a valid header: %s', filePath);
end
end

function extension = makePmodExtension(frameInfo, machineFormat)
units = 'Bq/ml';
nvol = size(frameInfo, 1);
rawSize = 8 + (4 + 2 + 2 + length(units) + 1) + ...
    (4 + 2 + 8) + 2 * (4 + 2 + 2 + 8 * nvol);
extensionSize = ceil(rawSize / 16) * 16;
extensionFile = [tempname(tempdir) '.pmod'];
fid = fopen(extensionFile, 'wb', machineFormat);
if fid < 0
    error('dicom2nifti:core:PmodWriteFailed', ...
        'Could not create temporary PMOD extension.');
end
cleanup = onCleanup(@() deleteIfPresent(extensionFile));
fwrite(fid, int32(extensionSize), 'int32');
fwrite(fid, int32(2), 'int32');
fwrite(fid, int16([84 4097]), 'int16');
fwrite(fid, uint8('CS'), 'uint8');
fwrite(fid, int16(length(units) + 1), 'int16');
fwrite(fid, uint8([units ' ']), 'uint8');
fwrite(fid, int16([85 16]), 'int16');
fwrite(fid, uint8('LO'), 'uint8');
fwrite(fid, uint8([6 0 80 77 79 68 95 49]), 'uint8');
fwrite(fid, int16([85 4097]), 'int16');
fwrite(fid, uint8('FD'), 'uint8');
fwrite(fid, int16(nvol * 8), 'int16');
fwrite(fid, frameInfo(:, 1), 'double');
fwrite(fid, int16([85 4100]), 'int16');
fwrite(fid, uint8('FD'), 'uint8');
fwrite(fid, int16(nvol * 8), 'int16');
fwrite(fid, frameInfo(:, 2), 'double');
padding = extensionSize - ftell(fid);
if padding > 0, fwrite(fid, zeros(1, padding), 'uint8'); end
fclose(fid);
fid = fopen(extensionFile, 'rb');
extension = fread(fid, Inf, '*uint8');
fclose(fid);
clear cleanup;
deleteIfPresent(extensionFile);
end

function copyBytes(source, destination)
while true
    bytes = fread(source, 1024 * 1024, '*uint8');
    if isempty(bytes), break; end
    written = fwrite(destination, bytes, 'uint8');
    if written ~= numel(bytes)
        error('dicom2nifti:core:PmodWriteFailed', 'Could not copy staged NIfTI data.');
    end
end
end

function writeFrameInfo(filePath, frameInfo)
fid = fopen(filePath, 'wt');
if fid < 0
    error('dicom2nifti:core:FrameInfoWriteFailed', ...
        'Could not create Frame_info.txt: %s', filePath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Acquisition times (start end) in seconds\n');
fprintf(fid, '%d # Number of acquisitions\n', size(frameInfo, 1));
for index = 1:size(frameInfo, 1)
    fprintf(fid, '%.1f\t%.1f\n', frameInfo(index, 1), ...
        frameInfo(index, 1) + frameInfo(index, 2));
end
end

function seconds = parseDicomTime(value)
value = parseNumber(value);
if ~isfinite(value)
    seconds = NaN;
    return;
end
hours = floor(value / 10000);
minutes = floor((value - hours * 10000) / 100);
seconds = hours * 3600 + minutes * 60 + (value - hours * 10000 - minutes * 100);
end

function value = parseNumber(value)
if ischar(value), value = str2double(strtrim(value)); end
if isempty(value) || ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
    value = NaN;
else
    value = double(value);
end
end

function seconds = elapsedSeconds(first, current)
seconds = current - first;
if seconds < 0, seconds = seconds + 24 * 3600; end
end

function closeAndDelete(fid, filePath, writeSucceeded)
if ~writeSucceeded
    if fid > 0, fclose(fid); end
    deleteIfPresent(filePath);
end
end

function closeFile(fid)
if ~isempty(fid) && fid > 0, fclose(fid); end
end

function cleanupDirectory(directory)
if exist(directory, 'dir') == 7, rmdir(directory, 's'); end
end

function deleteIfPresent(filePath)
if exist(filePath, 'file') == 2, delete(filePath); end
end
