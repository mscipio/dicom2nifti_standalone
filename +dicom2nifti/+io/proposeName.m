function name = proposeName(modality, seriesNumber)
%PROPOSENAME Suggest a PHI-neutral DICOM output filename.

modality = lower(strtrim(modality));
if isempty(modality), modality = 'dicom'; end
if isnumeric(seriesNumber) && isscalar(seriesNumber) && isfinite(seriesNumber)
    name = sprintf('%s_series_%04d.nii', modality, round(seriesNumber));
else
    name = sprintf('%s_series.nii', modality);
end
end
