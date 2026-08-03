function name = proposeName(inputFile)
%PROPOSENAME Use the selected input basename for the output suggestion.

[~, name, extension] = fileparts(inputFile);
if strcmpi(extension, '.gz') && length(name) >= 4 && ...
        strcmpi(name(end - 3:end), '.nii')
    [~, name, ~] = fileparts(name);
end
name = [name '.nii'];
end
