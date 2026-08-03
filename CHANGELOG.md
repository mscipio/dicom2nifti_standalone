# Changelog

This project uses [Semantic Versioning](https://semver.org/). `VERSION` is the authoritative code-readable version; each released value must have one matching heading here.

## [1.0.0] - 2026-08-03

### Added

- A single R2019-compatible `dcm2nii` entrypoint for GUI and scripted conversion.
- Exact DICOM series collection by `SeriesInstanceUID`, duplicate SOP rejection, and deterministic ordering.
- PHI-neutral automatic DICOM output names based only on modality and series number.
- SPM8-backed MR conversion plus unvalidated CT and static PET paths.
- `.nii` copy, `.nii.gz` decompression, and staged gzip output.
- Runtime version reading from `VERSION` and `dcm2nii_version.txt` records beside delivered outputs.
- Timestamped, leveled console events without persistent logger state.

### Safety

- Replaced the partial 8 KiB Explicit-VR parser, which used incorrect PET tag identities, with MATLAB `dicominfo`.
- Isolated SPM conversion in destination-local temporary directories and restored both working directory and MATLAB path on success or failure.
- Disabled dynamic and gated PET conversion. The inherited 4D implementation had no representative test data and did not preserve a reliable spatial header or dependency boundary.
- Added ignore rules for DICOM/NIfTI clinical data, generated outputs, and local `.atl` internals.

### Validation

- MATLAB R2026a Update 2 `checkcode` parsed all 12 MATLAB files. Its only two advisories recommend `datetime` over the deliberately R2019-compatible `datestr(now, ...)` logger.
- Focused tests passed for version agreement, NIfTI copy, gzip/gunzip round trip, source preservation, relative paths, and version-record creation.
- The real MPRAGE test series collected exactly 208 MR instances from Series 11.
- Real MR conversion produced a `256 x 256 x 208` `int16` volume byte-identical to `tests/2.7.0/local-2026/MR_PET/MPRAGE_spm.nii`: SHA-256 `4fe73ee6695ee4b5bbb2bf9b0166ae160b396e247807c68c92b3e0561691caac`, maximum voxel difference `0`, RMS difference `0`, changed voxels `0`, and maximum affine difference `0`.
- Direct compressed MR conversion produced a 13,951,071-byte `.nii.gz`; decompression was voxel-exact to the same reference, left no intermediate `.nii`, and restored MATLAB path and working directory.

### Limitations

- CT and static PET conversion are implemented but unvalidated because no representative datasets are included.
- Dynamic and gated PET are unsupported in `1.0.0`.
- Runtime verification is bounded to the MATLAB/SPM versions stated above; it is not evidence of cross-runtime numerical parity.
