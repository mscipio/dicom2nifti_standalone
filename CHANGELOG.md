# Changelog

`VERSION` is the authoritative semantic version.

## [1.2.2] - 2026-08-25

### Changed

- `tests/testCore.m`: strengthened assertions from existence/size checks to
  exact byte-for-byte equality for the uncompressed copy and `.nii.gz`
  decompression paths, and exact path equality for `resolveOutputs` results.
- `tests/testCore.m`: corrected the minimal NIfTI fixture written by
  `makeMinimalNifti` to be coherent (full 32-bit `sizeof_hdr=348`, `dim[0]`
  at the correct offset, and `bitpix=8` matching `datatype=uint8`).

### Unchanged

- No production behavior changed in this release. `dcm2nii.m`, the
  `+dicom2nifti/**` namespaces, and `config/**` are byte-identical to 1.2.1.
  The only tree delta is the strengthened test assertions and the corrected
  in-test fixture; no conversion algorithm, structured API, or facade
  behavior is affected.

## [1.2.1] - 2026-08-25

### Added

- Focused SPM-independent core test suite `tests/testCore.m` covering
  `dicom2nifti.core.fromNifti` (uncompressed copy and `.nii.gz`
  decompression) and centralizing the `dicom2nifti.core.resolveOutputs`
  cases (single output, sidecar ignored, zero-output rejection,
  non-NIfTI rejection, multiple-NIfTI rejection) that previously lived
  inline in `scripts/test_dcm2nii_integration.m`.

### Changed

- README clarifies the compatibility boundary: `dcm2nii()` is a
  facade for existing callers and scripts, and headless or structured
  consumers should call `dicom2nifti.api.run` directly to receive the
  four-field result. Notes that retiring or repurposing the facade is
  deferred to a future coordinated breaking release.

### Unchanged

- No conversion algorithm, structured API, or production facade
  behavior changed in this release. The only production-tree delta is
  documentation; all runtime paths through `dcm2nii()` and
  `dicom2nifti.api.run` remain byte-identical to 1.2.0.

## [1.2.0] - 2026-08-07

### Added

- New structured API entrypoint `dicom2nifti.api.run(inputFile, outputFile, ...)`
  with a four-field result struct (`status`, `outputs`, `message`, `details`).
  Supports headless conversion of DICOM (MR/CT/PET) and NIfTI (`.nii`/`.nii.gz`)
  with `'Compression'` and `'Overwrite'` name-value options. No GUI dependency.
- New config authority `config/defaults.m` containing the authoritative `spm_root`.
- Namespaced config helpers `+dicom2nifti/+config/load.m` and `validate.m` with
  caller-SPM-first, partial-rejection, and fallback logic.
- New `+dicom2nifti/+gui/mainWindow.m` namespace owning the Java chooser and
  overwrite confirmation only; delegates conversion to `api.run`.
- New `+dicom2nifti/+gui/` and `+dicom2nifti/+config/` namespaces.
- Focused test suites: `tests/testApi.m` (12 tests), `tests/testConfig.m` (6),
  `tests/testEntrypoint.m` (11), `tests/testGui.m` (6).

### Changed

- `dcm2nii.m` rewritten as a thin parsed-varargin facade (83% line reduction)
  dispatching to `dicom2nifti.api.run` or `dicom2nifti.gui.mainWindow`.
  All legacy call forms preserved; error identifiers remapped for backwards
  compatibility.
- `config/dicom2nifti_config.m` is now a deprecated thin wrapper around
  `dicom2nifti.config.load()`. Deployers should migrate `spm_root` to
  `config/defaults.m`.

### Preserved

- `+core`, `+dicom`, and `+io` packages are unchanged.
- Legacy `dcm2nii` path-return and `''`-on-cancellation contract preserved.
- Authorship and maintenance acknowledgement preserved.

## [1.1.1] - 2026-08-04

### Fixed

- `spm_dicom_convert` outputs are now resolved through
  `dicom2nifti.core.resolveOutputs`, which requires exactly one `.nii`
  output; zero or multiple outputs fail clearly instead of assuming
  `Temp_spm.nii`.
- Legacy `.i` input files are rejected up front with
  `dcm2nii:UnsupportedInput`; only DICOM and NIfTI (`.nii`, `.nii.gz`)
  input is accepted.
- Removed the mixed-SPM-directory guard while keeping the clear
  `dcm2nii:SpmIncomplete` failure for a partial caller SPM; the
  configured `spm_root` remains fallback-only.

### Added

- Focused integration test `scripts/test_dcm2nii_integration.m` covering
  input handling, output cardinality, SPM authority, state restoration,
  and edge cases. SPM-dependent checks self-report as UNVERIFIED when no
  SPM is on the MATLAB path.

### Validation

- Real DICOM conversion on the tested environment passed, confirming the
  SPM-dependent conversion and SPM-coexistence paths end to end.

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
