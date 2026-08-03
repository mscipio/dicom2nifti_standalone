function version = readVersion()
%READVERSION Return the release version from the repository VERSION file.

rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
versionFile = fullfile(rootDir, 'VERSION');
fid = fopen(versionFile, 'rt');
if fid < 0
    error('dicom2nifti:version:Unreadable', ...
        'Could not read authoritative version file: %s', versionFile);
end
cleanup = onCleanup(@() fclose(fid));
version = strtrim(fgetl(fid));
if isempty(regexp(version, '^[0-9]+\.[0-9]+\.[0-9]+$', 'once'))
    error('dicom2nifti:version:Invalid', ...
        'VERSION must contain one semantic version (MAJOR.MINOR.PATCH).');
end
end
