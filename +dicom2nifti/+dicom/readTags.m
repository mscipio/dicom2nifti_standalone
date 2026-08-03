function tags = readTags(filePath, fields, allowFallback)
%READTAGS Read only the DICOM tags needed by the converter.
%   The binary reader stops at PixelData. dicominfo is used only for the
%   representative file when the selective reader cannot parse it.

if nargin < 2 || isempty(fields)
    fields = defaultFields();
end
if nargin < 3
    allowFallback = true;
end
tags = emptyTags(fields);
try
    tags = parseSelective(filePath, fields);
catch cause
    if ~allowFallback
        error('dicom2nifti:dicom:InvalidDicom', ...
            'Could not selectively read DICOM metadata from %s: %s', ...
            filePath, cause.message);
    end
    try
        info = dicominfo(filePath);
    catch fallbackCause
        error('dicom2nifti:dicom:InvalidDicom', ...
            'Could not read DICOM metadata from %s: %s', ...
            filePath, fallbackCause.message);
    end
    for index = 1:numel(fields)
        field = fields{index};
        if isfield(info, field)
            tags.(field) = normalizeFallbackValue(info.(field), field);
        end
    end
end
end

function tags = parseSelective(filePath, fields)
tags = emptyTags(fields);
fileInfo = dir(filePath);
if isempty(fileInfo) || fileInfo.isdir || fileInfo.bytes < 132
    error('short DICOM file');
end

fid = fopen(filePath, 'rb', 'ieee-le');
if fid < 0, error('could not open file'); end
cleanup = onCleanup(@() closeFile(fid));
fseek(fid, 128, 'bof');
if ~isequal(fread(fid, 4, '*uint8')', uint8('DICM'))
    error('missing DICM preamble');
end

% File meta information is always explicit little-endian and identifies the
% transfer syntax used by the following dataset.
transferSyntax = '';
datasetOffset = ftell(fid);
while ftell(fid) + 8 <= fileInfo.bytes
    elementOffset = ftell(fid);
    [group, element, ~, lengthValue] = readHeader(fid, true, fileInfo.bytes);
    if group ~= hex2dec('0002')
        fseek(fid, elementOffset, 'bof');
        break;
    end
    if group == hex2dec('0002') && element == hex2dec('0010')
        transferSyntax = readText(fid, lengthValue);
    else
        skipValue(fid, lengthValue);
    end
    datasetOffset = ftell(fid);
end

if isempty(transferSyntax)
    transferSyntax = '1.2.840.10008.1.2.1';
end
if strcmp(transferSyntax, '1.2.840.10008.1.2.2')
    fclose(fid);
    fid = fopen(filePath, 'rb', 'ieee-be');
    if fid < 0, error('could not reopen file'); end
    fseek(fid, datasetOffset, 'bof');
    explicitVR = true;
elseif strcmp(transferSyntax, '1.2.840.10008.1.2')
    fseek(fid, datasetOffset, 'bof');
    explicitVR = false;
elseif strcmp(transferSyntax, '1.2.840.10008.1.2.1')
    fseek(fid, datasetOffset, 'bof');
    explicitVR = true;
else
    error('unsupported DICOM transfer syntax %s', transferSyntax);
end

while ftell(fid) + 8 <= fileInfo.bytes
    [group, element, vr, lengthValue] = readHeader(fid, explicitVR, fileInfo.bytes);
    if group == hex2dec('7FE0') && element == hex2dec('0010')
        break;
    end
    field = tagField(group, element);
    if isempty(field) || ~any(strcmp(fields, field))
        skipValue(fid, lengthValue);
    else
        tags.(field) = readValue(fid, lengthValue, field, vr);
    end
end
clear cleanup;
end

function [group, element, vr, lengthValue] = readHeader(fid, explicitVR, fileSize)
if ftell(fid) + 8 > fileSize, error('truncated DICOM header'); end
group = double(fread(fid, 1, '*uint16'));
element = double(fread(fid, 1, '*uint16'));
if isempty(group) || isempty(element), error('truncated DICOM tag'); end
if explicitVR
    vr = char(fread(fid, 2, '*uint8')');
    if numel(vr) ~= 2, error('truncated DICOM VR'); end
    if any(strcmp(vr, {'OB', 'OD', 'OF', 'OL', 'OW', 'SQ', 'UC', 'UN', 'UR', 'UT'}))
        fread(fid, 2, '*uint8');
        lengthValue = double(fread(fid, 1, '*uint32'));
    else
        lengthValue = double(fread(fid, 1, '*uint16'));
    end
else
    vr = '';
    lengthValue = double(fread(fid, 1, '*uint32'));
end
if isempty(lengthValue), error('truncated DICOM length'); end
if lengthValue ~= 4294967295 && ftell(fid) + lengthValue > fileSize
    error('invalid DICOM value length');
end
end

function skipValue(fid, lengthValue)
if lengthValue == 4294967295
    error('undefined-length DICOM sequence is not selectively readable');
end
fseek(fid, lengthValue, 'cof');
end

function value = readValue(fid, lengthValue, field, vr)
if lengthValue == 4294967295
    error('undefined-length DICOM value');
end
bytes = fread(fid, lengthValue, '*uint8')';
if numel(bytes) ~= lengthValue, error('truncated DICOM value'); end
if isTextField(field)
    value = strtrim(char(bytes(bytes ~= 0)));
else
    value = decodeNumber(bytes, field, vr);
end
end

function value = readText(fid, lengthValue)
if lengthValue == 4294967295, error('undefined-length text value'); end
bytes = fread(fid, lengthValue, '*uint8')';
value = strtrim(char(bytes(bytes ~= 0)));
end

function value = decodeNumber(bytes, field, vr)
textValue = strtrim(char(bytes(bytes ~= 0)));
number = str2double(textValue);
if ~isempty(textValue) && isfinite(number)
    value = number;
    return;
end
if any(strcmp(vr, {'US', 'SS'})) && numel(bytes) >= 2
    if strcmp(vr, 'US')
        value = double(typecast(uint8(bytes(1:2)), 'uint16'));
    else
        value = double(typecast(uint8(bytes(1:2)), 'int16'));
    end
elseif any(strcmp(vr, {'UL', 'SL'})) && numel(bytes) >= 4
    if strcmp(vr, 'UL')
        value = double(typecast(uint8(bytes(1:4)), 'uint32'));
    else
        value = double(typecast(uint8(bytes(1:4)), 'int32'));
    end
elseif strcmp(vr, 'FL') && numel(bytes) >= 4
    value = double(typecast(uint8(bytes(1:4)), 'single'));
elseif strcmp(vr, 'FD') && numel(bytes) >= 8
    value = double(typecast(uint8(bytes(1:8)), 'double'));
else
    value = [];
end
if isempty(value) && any(strcmp(field, {'InstanceNumber', 'SeriesNumber', ...
        'ActualFrameDuration', 'TriggerTime', 'NumberOfSlices', ...
        'NumberOfTimeSlices', 'NumberOfTimeSlots', 'NumberOfFrames', ...
        'Rows', 'Columns'}))
    value = str2double(textValue);
end
end

function field = tagField(group, element)
field = '';
pairs = [hex2dec('0020') hex2dec('000E'); hex2dec('0008') hex2dec('0060'); ...
    hex2dec('0008') hex2dec('0018'); hex2dec('0020') hex2dec('0013'); ...
    hex2dec('0020') hex2dec('0011'); hex2dec('0008') hex2dec('0032'); ...
    hex2dec('0018') hex2dec('1242'); hex2dec('0018') hex2dec('1060'); ...
    hex2dec('0020') hex2dec('1002'); hex2dec('0020') hex2dec('0105'); ...
    hex2dec('0054') hex2dec('0100'); hex2dec('0028') hex2dec('0008'); ...
    hex2dec('0028') hex2dec('0010'); hex2dec('0028') hex2dec('0011'); ...
    hex2dec('0008') hex2dec('0031')];
names = {'SeriesInstanceUID', 'Modality', 'SOPInstanceUID', ...
    'InstanceNumber', 'SeriesNumber', 'AcquisitionTime', ...
    'ActualFrameDuration', 'TriggerTime', 'NumberOfSlices', ...
    'NumberOfTimeSlices', 'NumberOfTimeSlots', 'NumberOfFrames', ...
    'Rows', 'Columns', 'SeriesTime'};
index = find(pairs(:, 1) == group & pairs(:, 2) == element, 1);
if ~isempty(index), field = names{index}; end
end

function fields = defaultFields()
fields = {'SeriesInstanceUID', 'Modality', 'SOPInstanceUID', ...
    'InstanceNumber', 'SeriesNumber', 'AcquisitionTime', ...
    'ActualFrameDuration', 'TriggerTime', 'NumberOfSlices', ...
    'NumberOfTimeSlices', 'NumberOfTimeSlots', 'NumberOfFrames', ...
    'Rows', 'Columns', 'SeriesTime'};
end

function tags = emptyTags(fields)
tags = struct();
for index = 1:numel(fields), tags.(fields{index}) = []; end
end

function value = normalizeFallbackValue(value, field)
if ischar(value)
    if isTextField(field)
        value = strtrim(value);
    else
        number = str2double(strtrim(value));
        if ~isempty(number) && isfinite(number), value = number; end
    end
elseif isempty(value)
    value = [];
end
end

function result = isTextField(field)
result = any(strcmp(field, {'SeriesInstanceUID', 'Modality', ...
    'SOPInstanceUID', 'AcquisitionTime', 'SeriesTime'}));
end

function closeFile(fid)
if ~isempty(fid) && fid > 0, fclose(fid); end
end
