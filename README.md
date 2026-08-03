# dcm2nii

`dcm2nii` converts one DICOM series or stages an existing NIfTI file for Biograph mMR MATLAB workflows. The initial release validates the MR path; dynamic and gated PET intentionally fail closed.

## Quick usage

1. Set `config.spm_root` in `config/dicom2nifti_config.m` to the deployment's SPM8 directory.
2. Add this repository root to the MATLAB path.
3. Run either GUI or scripted conversion:

```matlab
addpath('/path/to/dicom2nifti_standalone');

% GUI input and output selection
dcm2nii()

% One representative DICOM instance; all matching series instances are used
output = dcm2nii('/data/series/instance0001.dcm', '/results/mprage.nii');

% Compression can be selected by extension or option
output = dcm2nii('/data/series/instance0001.dcm', '/results/mprage.nii.gz');
output = dcm2nii('/data/series/instance0001.dcm', '/results/mprage.nii', ...
    'Compression', 'gz');
```

The returned path is the delivered `.nii` or `.nii.gz` file. Each successful invocation also writes `dcm2nii_version.txt` beside that output.

## Configuration

`config/dicom2nifti_config.m` is deployer-owned:

```matlab
config.spm_root = '/site/path/to/spm8';
```

The configured directory must provide `spm_dicom_headers.m` and `spm_dicom_convert.m`. DICOM conversion adds only that SPM root for the duration of the call and restores the caller's MATLAB path afterward.

## Behavior

| Input | Release status | Behavior |
|---|---|---|
| MR DICOM | Validated | Collect exact `SeriesInstanceUID`, reject duplicate SOP instances, order by unique `InstanceNumber`, convert through SPM8 |
| CT DICOM | Implemented, not validated with CT data | Same SPM8 path as MR |
| Static PET DICOM | Implemented, not validated with PET data | Uses the SPM8 path only when metadata does not indicate multiple times or gates |
| Dynamic or gated PET DICOM | Unsupported | Fails with `dicom2nifti:core:DynamicPetUnsupported` |
| `.nii` | Validated with a synthetic fixture | Copy to the requested destination; an identical source/destination is a no-op |
| `.nii.gz` | Validated with a synthetic fixture | Decompress to `.nii`, or preserve an identical compressed input |
| Compressed output | Validated with a synthetic fixture | Stage gzip output and promote it as `.nii.gz` without deleting the source NIfTI |

The selected DICOM file must be in the same directory as the other instances in its series. Series collection uses MATLAB `dicominfo`, not filename prefixes or a partial binary parser, so transfer syntax is handled by MATLAB.
Automatic DICOM names use only modality and series number, such as `mr_series_0011.nii`; source filenames are not propagated because they may contain identifying data.

## Dependencies

- MATLAB R2019-compatible source. Verification for this release ran on MATLAB R2026a Update 2.
- Image Processing Toolbox DICOM support (`dicominfo`).
- A deployment-provided SPM8 tree for DICOM conversion.
- No NIfTI toolbox is required for pass-through or compression.

## Verification status

Release verification covers parsing, helper tests, real MR conversion, exact comparison with `tests/2.7.0/local-2026/MR_PET/MPRAGE_spm.nii`, gzip creation/naming, and NIfTI pass-through. CT and PET behavior has no representative test dataset in this repository and MUST NOT be treated as clinically validated.

See `CHANGELOG.md` for exact release evidence and `VERSION` for the authoritative semantic version.

## Version convention

`VERSION` is the only code-readable version authority and contains one `MAJOR.MINOR.PATCH` value. `dicom2nifti.io.readVersion` reads it at runtime, the matching release heading is recorded in `CHANGELOG.md`, and `dicom2nifti.io.writeVersionLog` writes the delivered-output record. Update `VERSION` and `CHANGELOG.md` together for each release; do not hard-code the version in MATLAB source.
