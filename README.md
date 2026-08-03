# dcm2nii

Small MATLAB/SPM8 converter for one DICOM series or an existing NIfTI file.
The entry point is orchestration only; conversion, DICOM selection, and IO
helpers live in the `+dicom2nifti` package.

## Quick Path

```matlab
addpath('/path/to/dicom2nifti_standalone');

% GUI: Java chooser starts in caller pwd; save chooser starts beside input.
dcm2nii()

% CLI: destination is required for reproducible runs.
dcm2nii('/data/series/instance0001.dcm', '/results/mprage.nii');
dcm2nii('/data/series/instance0001.dcm', '/results/mprage.nii.gz');

% Explicitly replace an existing destination.
dcm2nii('/data/series/instance0001.dcm', '/results/mprage.nii', ...
    'Overwrite', true);
```

## Workflows

| Input | Workflow | Output |
| --- | --- | --- |
| MR or CT DICOM | Exact `SeriesInstanceUID` collection, then SPM conversion | 3D `.nii` or `.nii.gz` |
| Static PET DICOM | SPM conversion | 3D `.nii` or `.nii.gz` |
| Dynamic or gated PET DICOM | Acquisition-time grouping, optional `TriggerTime` gating, one SPM conversion per frame | 4D NIfTI, PMOD timing extension, `Frame_info.txt` |
| Existing `.nii` or `.nii.gz` | Copy or gunzip | Requested NIfTI destination |

MR and CT conversion uses `+dicom2nifti/+core/fromDicom.m`. PET routing and
the legacy 4D timing behavior are in `fromPet.m`. NIfTI copy and gunzip are in
`fromNifti.m`.

## Safety And Performance

- CLI fails clearly when the destination, version record, or PET frame sidecar already exists. Use only `'Overwrite', true` to replace them.
- GUI shows an explicit confirmation warning before replacing any generated file.
- No automatic suffix is generated, and source DICOM/NIfTI files are never modified.
- The GUI input chooser is a Java chooser initialized with caller `pwd`.
- The GUI save chooser is a Java chooser initialized in the selected input folder and offers `.nii` and `.nii.gz` filters.
- DICOM candidates use a selective binary metadata reader and exact `SeriesInstanceUID` matching. Full `dicominfo` is a representative-file fallback only.
- SPM conversion and compression use temporary staging directories; clinical source directories are not used as scratch space.

Successful runs write `dcm2nii_version.txt` beside the output. Dynamic PET
also writes `Frame_info.txt` beside the output. These sidecars participate in
the overwrite decision.

## Configuration

Set the deployer-owned SPM path in `config/dicom2nifti_config.m`:

```matlab
config.spm_root = '/site/path/to/spm8';
```

SPM must provide `spm_dicom_headers` and `spm_dicom_convert`. Dynamic/gated PET
also needs the complete SPM NIfTI read/write stack, including
`spm_vol_nifti`; if it is unavailable, the converter fails clearly before
writing a PET 4D output. If the caller already has a complete SPM installation
on the MATLAB path, dcm2nii reuses it. The configured SPM path is only a
fallback; mixed or incomplete SPM installations fail clearly. The source uses
MATLAB R2019-compatible syntax and does not use arguments blocks.

## Validation Status

The known MR MPRAGE series produced `256 x 256 x 208` in approximately
`12.0 s` conversion time on the tested environment. NIfTI copy, gzip, gunzip,
overwrite protection, and selective series collection were smoke-tested.

No representative PET dataset is included, so PET 3D/4D behavior is not
claimed as clinically validated. The configured test SPM tree currently lacks
`spm_vol_nifti`, so dynamic/gated PET correctly reports that dependency
limitation rather than producing an unverified file.

## Legacy Scope

Integrated from the Aether reference:

- acquisition-time grouping;
- optional TriggerTime gating;
- `ActualFrameDuration` in seconds;
- per-frame SPM conversion;
- 4D NIfTI output;
- PMOD frame start/duration extension layout;
- `Frame_info.txt`.

Intentionally excluded because they are separate workflows or formats:

- `.i`/flat-format conversion and registration;
- BrainPET-specific orientation/flipping and coregistration;
- MR cine conversion;
- denoising, Dixon water/fat processing, UTE/UMAP processing, and fusion;
- reorientation, reslicing, atlas, and unrelated utilities;
- the legacy `NIFTI_20121012` toolkit and its bundled helper files.

`VERSION` is the authoritative semantic version and `CHANGELOG.md` records
release history. No standalone test framework is added.
