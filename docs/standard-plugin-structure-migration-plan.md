# dicom2nifti Standard Plugin Structure Migration Plan

dicom2nifti is migration step 2 and the first implementation repository. It is
the shared leaf dependency used directly by pseudoCT and correct_aliasing, so
its compatibility transition must land before either consumer changes.

## Objective

Extract GUI, non-interactive orchestration, and configuration responsibilities
from `dcm2nii.m` while retaining the proven `+core`, `+dicom`, and `+io`
packages. Introduce the minimal shared result without abruptly breaking callers
that currently expect a path string.

## Current-to-Target Mapping

| Current file or symbol | Target file or responsibility |
|---|---|
| `dcm2nii.m` | Thin, only public facade; GUI/API dispatch and compatibility return boundary. |
| Main conversion body in `dcm2nii` | `+dicom2nifti/+api/run.m`. |
| `requestFiles`, `chooseInputFile`, `chooseOutputFile`, interactive overwrite | `+dicom2nifti/+gui/mainWindow.m`. |
| `setupSpm` and `dicom2nifti_config` evaluation | `+dicom2nifti/+config/load.m`, `validate.m`. |
| `config/dicom2nifti_config.m` | `config/defaults.m`, with a temporary wrapper if deployed installs require the old name. |
| `dicom2nifti.core.*` | Retain under `+dicom2nifti/+core/`. |
| `dicom2nifti.dicom.*` | Retain as justified DICOM-specific support. |
| `dicom2nifti.io.*` | Retain because naming, logging, sidecars, and version reads are substantial I/O. |
| `scripts/test_dcm2nii_integration.m` | Split focused coverage into `tests/testEntrypoint.m`, `testApi.m`, `testConfig.m`, and `testCore.m`; retain resource-backed integration evidence. |

## Scope

In scope:

- Separate interactive selection from conversion orchestration.
- Add configuration load/validation before conversion mutation.
- Return `status`, `outputs`, `message`, and `details` from the new API.
- Preserve source files, explicit overwrite, routing, compression, sidecars,
  deterministic identifiers, and exact cwd/path restoration.
- Preserve `+core`, `+dicom`, and `+io` behavior unless a focused extraction
  requires a narrow signature change.

Non-goals:

- No converter algorithm rewrite or modality expansion.
- No universal transaction across NIfTI, version log, and PET sidecars.
- No mandatory provenance, timing, release folder, or packaging framework.
- No consumer migration in the same review unit.

## Phased Work Units

1. **Characterization:** lock current path return, cancellation `''`, routing,
   overwrite, sidecar warning, and state restoration behavior in focused tests.
2. **Config extraction:** add `dicom2nifti.config.load` and `validate`; keep the
   existing config entrypoint as a temporary deployment wrapper if required.
3. **API extraction:** move explicit-input orchestration to
   `dicom2nifti.api.run` and return the minimal result internally.
4. **GUI extraction:** move choosers and overwrite confirmation to
   `dicom2nifti.gui.mainWindow`; delegate accepted intent to the API.
5. **Facade transition:** reduce `dcm2nii` to dispatch and introduce a
   documented compatibility mechanism for path-return callers.
6. **Consumer canary:** verify unchanged pseudoCT and correct_aliasing calls
   still receive the expected output path during the transition.
7. **Contract release:** align README, VERSION, CHANGELOG, and tag; publish the
   version from which consumers may adopt the minimal result directly.

## Compatibility Strategy

Current callers assign `outputPath = dcm2nii(...)`, while the target facade
returns a result. Use a bounded transition rather than changing the meaning of
one output silently. The implementation design must select and document an
explicit compatibility seam, such as a temporary legacy wrapper or a separately
named result opt-in, then migrate pseudoCT and correct_aliasing before removing
it in a versioned breaking release. No compatibility branch should infer caller
identity from the stack.

GUI cancellation maps to `status='cancelled'` and no committed outputs in the
new contract; the compatibility seam continues to expose `''` to legacy path
callers. Existing deterministic exceptions remain for invalid invocation and
configuration contracts. Normal conversion failures return `failed` once the
new API contract is selected.

## Test and Evidence Plan

- `testEntrypoint`: GUI dispatch, explicit dispatch, compatibility return, and
  no package-internal public dependency.
- `testApi`: no UI for explicit input, all four statuses where applicable,
  committed `outputs`, overwrite refusal/approval, source preservation,
  compression, and cwd/path restoration.
- `testConfig`: caller SPM authority, partial SPM rejection, fallback root,
  shadowing, and validation before conversion.
- `testCore`: NIfTI pass-through, DICOM output cardinality, PET routing, and
  output resolution.
- Retain a resource-backed integration script for real MR/CT/PT evidence and
  mark unavailable fixtures `UNVERIFIED`.
- Add consumer canaries using the exact current calls from `run_pseudo_CT` and
  `alias.api.loadInput`.

## Definition of Done

- `dcm2nii.m` is the only public entrypoint.
- GUI interaction lives in `dicom2nifti.gui.mainWindow` and delegates to
  `dicom2nifti.api.run`.
- Config load and validation are namespaced and run before processing.
- The minimal result uses only `success|partial|failed|cancelled`; `outputs` is
  a cell array of committed paths and plugin data is under `details`.
- Existing pseudoCT and correct_aliasing path callers have a documented,
  tested transition.
- Input, overwrite, cwd/path, and current modality behavior remain protected.
- README, VERSION, CHANGELOG, and tag agree.

## Risks and Open Decisions

- **OPEN DECISION:** choose the explicit legacy path-return seam and its removal
  version before facade implementation.
- Version-log failure currently occurs after the main output and is warning-only;
  `details` must report this without misrepresenting the committed NIfTI.
- PET timing sidecars have weaker fixture evidence than NIfTI/MR paths.

## Relevant Files and Symbols

- `dcm2nii.m`: `requestFiles`, `chooseInputFile`, `chooseOutputFile`, `setupSpm`,
  `resolveOverwrite`, `compressTo`, `restoreSession`.
- `config/dicom2nifti_config.m`.
- `+dicom2nifti/+core/fromNifti.m`, `fromDicom.m`, `fromPet.m`, `resolveOutputs.m`.
- `+dicom2nifti/+dicom/readTags.m`, `collectSeries.m`.
- `+dicom2nifti/+io/proposeName.m`, `writeVersionLog.m`, `readVersion.m`, `logMessage.m`.
- `scripts/test_dcm2nii_integration.m`.
- `README.md`, `VERSION`, `CHANGELOG.md`.

## Cross-Repository Dependencies

Prerequisite: the shared template and compatibility policy in Piano's
architecture guide. Downstream consumers are pseudoCT's `run_pseudo_CT` local
and Launchpad staging paths, correct_aliasing's `alias.api.loadInput`, and
Piano's `piano.plugins.launchDicom2Nifti`.
