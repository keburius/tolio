# Vendored dependencies

Third-party code is vendored here so builds need no network access and are
pinned to an exact, verifiable release.

## GRDB

| | |
|---|---|
| Version | 7.12.0 |
| Source | https://github.com/groue/GRDB.swift/archive/refs/tags/v7.12.0.zip (redirects to `codeload.github.com/groue/GRDB.swift/zip/refs/tags/v7.12.0`) |
| Archive SHA-256 | `998c40fb667269a1443b755b2eab83f7a3120b439d33a1b72bb9ba6a9fd56866` |
| Archive size | 7,933,868 bytes |
| License | MIT, see `GRDB/LICENSE` |
| Local changes | None. `GRDB/` is the archive's `GRDB.swift-7.12.0/` folder, unmodified |
| Used by | `OmniKit/Package.swift` → `.package(path: "../Vendor/GRDB")`, product `GRDB` (module `FeatureClipboard`) |

Why vendored: SwiftPM's remote fetch clones the full GRDB history (over 215 MB)
and stalled twice on this machine. The release archive is 7.9 MB.

### How to upgrade GRDB

1. Pick a release on https://github.com/groue/GRDB.swift/releases and read its changelog for breaking changes.
2. Download the archive into an empty scratch folder and record its hash:
   ```sh
   curl -L -o GRDB.zip https://github.com/groue/GRDB.swift/archive/refs/tags/vX.Y.Z.zip
   shasum -a 256 GRDB.zip
   ```
3. Extract with `ditto -x -k GRDB.zip out/` (not `unzip`: some demo-app file names contain `×`, which `unzip` can't write).
4. Replace the folder: `rm -rf Vendor/GRDB && ditto out/GRDB.swift-X.Y.Z Vendor/GRDB`. Keep `LICENSE`.
5. Check that `Vendor/GRDB/Package.swift` still adds no remote dependencies by default (the docc plugin is only added when `SPI_BUILDER=1`).
6. Update the version, URL, hash, and size in the table above.
7. Run `make build test`, then commit the folder and this README together.

### Known warnings

With Swift 6.2 (Xcode 26.1), GRDB 7.12.0 emits two warnings, which are left as is
because vendored code stays unmodified:

- `GRDB/Record/EncodableRecord.swift:243`: type 'Any' does not conform to the 'Sendable' protocol
- `GRDB/Record/FetchableRecord.swift:269`: type 'Any' does not conform to the 'Sendable' protocol

`Scripts/check-warnings.sh` lists warnings under `Vendor/` without failing the build;
warnings in Omni's own code still fail it. Recheck this list on every upgrade.
