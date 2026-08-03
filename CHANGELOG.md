# Changelog

`VERSION` is the authoritative semantic version.

## [1.1.0] - 2026-08-03

### Added

- Restored the minimal modular layout under `+dicom2nifti`.
- Added exact `SeriesInstanceUID` collection with selective DICOM metadata reads.
- Added PET static routing and legacy-style PET 4D acquisition-time/TriggerTime grouping.
- Added `ActualFrameDuration`, per-frame SPM conversion, PMOD timing extension output, and `Frame_info.txt`.

### Changed

- Kept `dcm2nii.m` as the orchestration, GUI/CLI, routing, overwrite, and reporting entry point.
- GUI uses Java input/save choosers with the required caller/input-folder initialization and NIfTI filters.
- CLI output collisions now fail by default. GUI collisions require an explicit confirmation warning.
- Added the explicit CLI escape hatch `'Overwrite', true`; no automatic suffixes are generated.
- Preserved source DICOM and NIfTI files and kept temporary conversion work outside source folders.
- Reuses a complete caller-provided SPM installation instead of prepending the
  configured SPM path; the configured path is fallback-only.

### Validation

- Real MR MPRAGE conversion produced `256 x 256 x 208` in approximately `12.0 s` conversion time on the tested environment.
- Selective exact-series collection found all 208 MR instances.
- NIfTI copy, gzip, gunzip, synthetic overwrite protection, and MATLAB diagnostics were exercised.

### Limitations

- No representative PET dataset is available; PET 3D/4D behavior is not claimed as clinically validated.
- The configured SPM tree lacks `spm_vol_nifti`, so dynamic/gated PET fails clearly before writing output until a complete SPM NIfTI stack is configured.
- `.i`/flat conversion, registration, BrainPET orientation, denoising, Dixon, UTE/UMAP, reslicing, fusion, and unrelated legacy utilities remain excluded.

## [1.0.1] - 2026-08-03

### Changed

- Java input and save choosers replaced native dialogs for the standalone workflow.
- Exact series matching, NIfTI copy/decompression, optional gzip output, and temporary SPM staging were retained.

### Validation

- Real 208-slice MPRAGE conversion produced a `256 x 256 x 208` NIfTI.
- CT and PET remained unvalidated without representative datasets.

## [1.0.0] - 2026-08-03

- Initial standalone release boundary.
