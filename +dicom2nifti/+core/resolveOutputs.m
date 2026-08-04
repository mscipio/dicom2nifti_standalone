function niiFiles = resolveOutputs(fileList, stageDir)
%RESOLVEOUTPUTS Resolve and validate spm_dicom_convert output files.
%   niiFiles = dicom2nifti.core.resolveOutputs(fileList, stageDir)
%
%   fileList: cell array of file names from out.files.
%   stageDir: the staging directory where outputs were written.
%   Returns a cell array of resolved absolute paths to .nii files.
%   Errors if zero or more than one .nii output is found.
%   Non-.nii outputs (e.g. .json sidecars) are silently ignored.

if isempty(fileList)
    error('dicom2nifti:core:ZeroOutputs', ...
        'spm_dicom_convert returned no output files.');
end

niiList = {};
for i = 1:numel(fileList)
    fileName = fileList{i};
    fileName = strtrim(fileName);
    if isempty(fileparts(fileName))
        resolved = fullfile(stageDir, fileName);
    else
        resolved = fileName;
    end
    if length(fileName) >= 4 && strcmpi(fileName(end-3:end), '.nii')
        niiList{end + 1} = resolved; %#ok<AGROW>
    end
end

niiCount = numel(niiList);
if niiCount == 0
    listing = sprintf('  %s\n', fileList{:});
    error('dicom2nifti:core:ZeroNiftiOutputs', ...
        'spm_dicom_convert produced no .nii output.\nOutput files:\n%s', ...
        listing);
elseif niiCount > 1
    listing = sprintf('  %s\n', niiList{:});
    error('dicom2nifti:core:MultipleNiftiOutputs', ...
        'spm_dicom_convert produced %d .nii outputs; expected exactly 1.\nNIfTI files:\n%s', ...
        niiCount, listing);
end
niiFiles = niiList;
end
