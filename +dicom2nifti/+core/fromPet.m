function outputPath = fromPet(inputFile, outputFile)
%FROMPET Convert a demonstrably static PET series through the SPM path.
%   Dynamic or gated PET is rejected because its 4D writer has not been
%   validated against representative data.

series = dicom2nifti.dicom.collectSeries(inputFile);
acquisitionTimes = cell(series.instanceCount, 1);
triggerTimes = nan(series.instanceCount, 1);
declaredTimeSlices = nan(series.instanceCount, 1);

for index = 1:series.instanceCount
    tags = dicom2nifti.dicom.readTags(series.files{index});
    acquisitionTimes{index} = tags.AcquisitionTime;
    if ~isempty(tags.TriggerTime)
        triggerTimes(index) = double(tags.TriggerTime);
    end
    if ~isempty(tags.NumberOfTimeSlices)
        declaredTimeSlices(index) = double(tags.NumberOfTimeSlices);
    end
end

acquisitionTimes = acquisitionTimes(~cellfun('isempty', acquisitionTimes));
isDynamic = numel(unique(acquisitionTimes)) > 1 || ...
    numel(unique(triggerTimes(~isnan(triggerTimes)))) > 1 || ...
    any(declaredTimeSlices(~isnan(declaredTimeSlices)) > 1);
if isDynamic
    error('dicom2nifti:core:DynamicPetUnsupported', ...
        ['Dynamic or gated PET conversion is disabled in this release. ' ...
         'The legacy 4D writer has not been validated with representative data.']);
end

outputPath = dicom2nifti.core.fromDicom(inputFile, outputFile);
end
