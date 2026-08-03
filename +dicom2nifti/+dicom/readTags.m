function tags = readTags(filePath)
%READTAGS Read the DICOM fields used by the converter.
%   Uses MATLAB's DICOM reader so transfer syntax and tag locations are
%   handled correctly. Missing optional fields are returned empty.

try
    info = dicominfo(filePath);
catch ME
    error('dicom2nifti:dicom:InvalidDicom', ...
        'Could not read DICOM metadata from %s: %s', filePath, ME.message);
end

fields = {'SeriesInstanceUID', 'Modality', 'SOPInstanceUID', ...
    'InstanceNumber', 'SeriesNumber', 'AcquisitionTime', ...
    'ActualFrameDuration', 'TriggerTime', 'NumberOfSlices', ...
    'NumberOfTimeSlices', 'NumberOfFrames', 'Rows', 'Columns'};
tags = struct();
for index = 1:numel(fields)
    field = fields{index};
    if isfield(info, field)
        tags.(field) = info.(field);
    else
        tags.(field) = [];
    end
end

tags.SeriesInstanceUID = asText(tags.SeriesInstanceUID);
tags.Modality = asText(tags.Modality);
tags.SOPInstanceUID = asText(tags.SOPInstanceUID);
tags.AcquisitionTime = asText(tags.AcquisitionTime);
end

function value = asText(value)
if isempty(value)
    value = '';
elseif ischar(value)
    value = strtrim(value);
else
    value = strtrim(num2str(value));
end
end
