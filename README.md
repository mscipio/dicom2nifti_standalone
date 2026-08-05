# dcm2nii

Maintained by Michele Scipioni, PhD  
mscipioni@mgh.harvard.edu  
Last updated: August 5, 2026.

Small MATLAB/SPM8 converter for one DICOM series or an existing NIfTI file.
Converts MR, CT, and PET series to NIfTI (`.nii` or `.nii.gz`) from the
command line or through a GUI, with exact series selection, overwrite
protection, and optional gzip compression.

## Features

- **GUI and CLI** entry points from a single function.
- **MR / CT / static PET** to 3D NIfTI.
- **Dynamic or gated PET** to 4D NIfTI with a PMOD timing extension and
  `Frame_info.txt`.
- **NIfTI passthrough**: copy or decompress an existing `.nii` / `.nii.gz`.
- **Exact series selection** by `SeriesInstanceUID` using a fast selective
  DICOM metadata reader.
- **Safe by default**: existing destinations are never replaced without
  explicit confirmation.
- **SPM coexistence**: reuses a complete SPM already on the MATLAB path; the
  configured path is fallback-only.

## Requirements

- MATLAB (R2019-compatible syntax; no arguments blocks).
- SPM8 providing `spm_dicom_headers` and `spm_dicom_convert`.
- Dynamic/gated PET additionally needs the complete SPM NIfTI read/write
  stack, including `spm_vol_nifti`.

## Installation

1. Add this repository to the MATLAB path:

   ```matlab
   addpath('/path/to/dicom2nifti_standalone');
   ```

2. Set the deployer-owned SPM path in `config/dicom2nifti_config.m`:

   ```matlab
   config.spm_root = '/site/path/to/spm8';
   ```

   If the caller already has a complete SPM installation on the MATLAB path,
   dcm2nii reuses it and ignores the configured path. A partial SPM on the
   path (only one of the two required functions) fails clearly instead of
   mixing installations.

## Usage

```matlab
% GUI: Java chooser starts in caller pwd; save chooser starts beside input.
dcm2nii()

% CLI: destination is required for reproducible runs.
dcm2nii('/data/series/instance0001.dcm', '/results/mprage.nii');
dcm2nii('/data/series/instance0001.dcm', '/results/mprage.nii.gz');

% Explicitly replace an existing destination.
dcm2nii('/data/series/instance0001.dcm', '/results/mprage.nii', ...
    'Overwrite', true);
```

### Arguments

| Signature | Behavior |
| --- | --- |
| `dcm2nii()` | Interactive GUI. Input chooser starts in the caller's current folder; save chooser starts beside the selected input and proposes a name from the input basename. |
| `dcm2nii(inputFile)` | Converts `inputFile`, writing the output beside it with a name proposed from the input basename. |
| `dcm2nii(inputFile, outputFile)` | Converts `inputFile` to `outputFile` (`.nii` or `.nii.gz`). |
| `'Compression', 'gz'` | Write compressed `.nii.gz` output. |
| `'Overwrite', true` | Explicitly allow replacing an existing destination (CLI only; the GUI always asks for confirmation). |

The output extension controls compression: a `.nii.gz` destination is
compressed, a `.nii` destination is not. No automatic suffix is generated.

## What it converts

| Input | Workflow | Output |
| --- | --- | --- |
| MR or CT DICOM | Exact `SeriesInstanceUID` collection, then SPM conversion | 3D `.nii` or `.nii.gz` |
| Static PET DICOM | SPM conversion | 3D `.nii` or `.nii.gz` |
| Dynamic or gated PET DICOM | Acquisition-time grouping, optional `TriggerTime` gating, one SPM conversion per frame | 4D NIfTI, PMOD timing extension, `Frame_info.txt` |
| Existing `.nii` or `.nii.gz` | Copy or gunzip | Requested NIfTI destination |

Legacy `.i`/flat-format files are rejected up front with a clear error.

## Outputs and sidecars

- **`dcm2nii_version.txt`** is written beside the output on every successful
  run.
- **`Frame_info.txt`** is written beside the output for dynamic PET.
- Sidecars participate in the overwrite decision: they are protected the same
  way as the output file itself.

## Safety

- The CLI fails clearly when the destination, version record, or PET frame
  sidecar already exists; only `'Overwrite', true` replaces them.
- The GUI shows an explicit confirmation warning before replacing any
  generated file.
- Source DICOM/NIfTI files are never modified.
- SPM conversion and compression run in temporary staging directories;
  clinical source directories are not used as scratch space.
- DICOM candidates use a selective binary metadata reader with exact
  `SeriesInstanceUID` matching; full `dicominfo` is a representative-file
  fallback only.

## Limitations

- The known MR MPRAGE series produced `256 x 256 x 208` in approximately
  `12.0 s` conversion time on the tested environment. NIfTI copy, gzip,
  gunzip, overwrite protection, and selective series collection were
  smoke-tested.
- No representative PET dataset is included, so PET 3D/4D behavior is not
  claimed as clinically validated. The configured test SPM tree currently
  lacks `spm_vol_nifti`, so dynamic/gated PET correctly reports that
  dependency limitation rather than producing an unverified file.
- Out of scope: `.i`/flat-format conversion and registration; BrainPET-specific
  orientation/flipping and coregistration; MR cine conversion; denoising,
  Dixon water/fat processing, UTE/UMAP processing, and fusion; reorientation,
  reslicing, atlas, and unrelated utilities; the legacy `NIFTI_20121012`
  toolkit.

## Development

- `VERSION` is the authoritative semantic version; `CHANGELOG.md` records
  release history.
- `scripts/test_dcm2nii_integration.m` runs focused integration tests;
  SPM-dependent checks self-report as UNVERIFIED when no SPM is on the MATLAB
  path.
