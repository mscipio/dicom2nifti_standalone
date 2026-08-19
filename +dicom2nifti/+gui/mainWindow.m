function result = mainWindow(options)
%MAINWINDOW GUI chooser + overwrite-confirmation entrypoint.
%   Delegates conversion to dicom2nifti.api.run. Returns four-field struct.

% Default result (headless-safe)
result = struct('status', 'cancelled', 'outputs', {{}}, ...
    'message', 'Selection cancelled.', 'details', struct());

% Parse caller compression preference
callerCompression = 'none';
for i = 1:2:numel(options)
    if i >= numel(options), break; end
    k = options{i}; v = options{i+1};
    if ischar(k) && strcmpi(k, 'Compression')
        callerCompression = lower(strtrim(v));
    end
end

% Input chooser
try
    [inputFile, cancelled] = chooseInput();
catch ME %#ok<NASGU>
    result.message = 'Input selection unavailable (headless or no Java display).';
    return;
end
if cancelled
    result.message = 'Input selection cancelled.';
    return;
end

defaultName = dicom2nifti.io.proposeName(inputFile);
try
    [outputFile, compressed, cancelled] = chooseOutput(inputFile, defaultName, callerCompression);
catch ME %#ok<NASGU>
    result.message = 'Output selection unavailable (headless or no Java display).';
    return;
end
if cancelled
    result.message = 'Output selection cancelled.';
    return;
end

% Overwrite confirmation
expected = {outputFile, fullfile(fileparts(outputFile), 'dcm2nii_version.txt')};
existing = {};
for i = 1:numel(expected)
    if exist(expected{i}, 'file') == 2
        existing{end + 1} = expected{i}; %#ok<AGROW>
    end
end
if ~isempty(existing)
    details = sprintf('  %s\n', existing{:});
    question = sprintf(['The following output file(s) already exist:\n\n%s\n' ...
        '\nOverwrite them? Existing source files will not be changed.'], details);
    answer = questdlg(question, 'Confirm overwrite', 'Overwrite', 'Cancel', 'Cancel');
    if ~strcmp(answer, 'Overwrite')
        result.message = 'Overwrite cancelled.';
        return;
    end
    % Add Overwrite=true to the options forwarded to api.run
    options{end + 1} = 'Overwrite';
    options{end + 1} = true;
end

% Delegate to api.run
compression = 'none';
if compressed, compression = 'gz'; end
options{end + 1} = 'Compression';
options{end + 1} = compression;
result = dicom2nifti.api.run(inputFile, outputFile, options{:});
end

% Local chooser helpers
function [inputFile, cancelled] = chooseInput()
cancelled = false;
inputDir = pwd;
if exist('javaObjectEDT', 'file') == 2
    chooser = javaObjectEDT('javax.swing.JFileChooser', inputDir);
else
    chooser = javaObject('javax.swing.JFileChooser', inputDir);
end
chooser.setDialogTitle('Select DICOM or NIfTI input');
chooser.setDialogType(javax.swing.JFileChooser.OPEN_DIALOG);
chooser.setCurrentDirectory(javaObject('java.io.File', inputDir));
dcmFilter = javaObject('javax.swing.filechooser.FileNameExtensionFilter', ...
    'DICOM (*.dcm, *.DCM, *.ima, *.IMA)', {'dcm', 'DCM', 'ima', 'IMA'});
niiFilter = javaObject('javax.swing.filechooser.FileNameExtensionFilter', ...
    'NIfTI (*.nii, *.nii.gz)', {'nii', 'gz'});
chooser.setAcceptAllFileFilterUsed(true);
chooser.addChoosableFileFilter(dcmFilter);
chooser.addChoosableFileFilter(niiFilter);
chooser.setFileFilter(dcmFilter);
if chooser.showOpenDialog([]) ~= 0
    inputFile = ''; cancelled = true; return;
end
selected = chooser.getSelectedFile();
if isempty(selected)
    inputFile = ''; cancelled = true; return;
end
inputFile = char(selected.getAbsolutePath());
end

function [outputFile, compressed, cancelled] = chooseOutput(inputFile, defaultName, defaultCompression)
cancelled = false; compressed = strcmp(defaultCompression, 'gz');
inputDir = fileparts(inputFile);
if exist('javaObjectEDT', 'file') == 2
    chooser = javaObjectEDT('javax.swing.JFileChooser', inputDir);
else
    chooser = javaObject('javax.swing.JFileChooser', inputDir);
end
chooser.setDialogTitle('Save NIfTI output');
chooser.setDialogType(javax.swing.JFileChooser.SAVE_DIALOG);
chooser.setCurrentDirectory(javaObject('java.io.File', inputDir));
chooser.setSelectedFile(javaObject('java.io.File', fullfile(inputDir, defaultName)));
niiFilter = javaObject('javax.swing.filechooser.FileNameExtensionFilter', ...
    'NIfTI (*.nii)', {'nii'});
gzFilter = javaObject('javax.swing.filechooser.FileNameExtensionFilter', ...
    'NIfTI compressed (*.nii.gz)', {'gz'});
chooser.setAcceptAllFileFilterUsed(false);
chooser.addChoosableFileFilter(niiFilter);
chooser.addChoosableFileFilter(gzFilter);
if compressed
    chooser.setFileFilter(gzFilter);
else
    chooser.setFileFilter(niiFilter);
end
if chooser.showSaveDialog([]) ~= 0
    outputFile = ''; cancelled = true; return;
end
selected = chooser.getSelectedFile();
if isempty(selected)
    outputFile = ''; cancelled = true; return;
end
outputFile = char(selected.getAbsolutePath());
desc = char(chooser.getFileFilter().getDescription());
if strcmp(desc, 'NIfTI compressed (*.nii.gz)')
    outputFile = normalizeName(outputFile, true);
    compressed = true;
else
    outputFile = normalizeName(outputFile, false);
    compressed = false;
end
end

function outFile = normalizeName(outFile, compressed)
if compressed
    if endsWith(lower(outFile), '.nii.gz'), return; end
    if length(outFile) >= 4 && strcmpi(outFile(end - 3:end), '.nii')
        outFile = [outFile '.gz'];
    else
        outFile = [outFile '.nii.gz'];
    end
else
    if endsWith(lower(outFile), '.nii.gz')
        outFile = outFile(1:end - 3);
    elseif ~strcmpi(ext(outFile), '.nii')
        outFile = [outFile '.nii'];
    end
end
end

function e = ext(p)
[~, ~, e] = fileparts(p);
end
