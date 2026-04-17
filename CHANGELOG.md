# Changelog

All notable changes to this project are documented in this file.

## v1.1.0 - 2026-04-17

### Added
- Added `Tests/RecipeManager.Tests.ps1` Pester regression tests for query behavior and parameter-set usage.
- Added explicit module metadata in `RecipeManager.psd1`: `GUID`, `PowerShellVersion`, `Description`, and explicit `FunctionsToExport`.

### Changed
- Improved module bootstrap in `RecipeManager.psm1` with fail-fast config loading and module root initialization.
- Updated `Invoke-DataProvider` to resolve storage path from module root and use temp-file replacement for safer writes.
- Updated `Set-Recipe` to validate category against runtime config enums and run `Invoke-RecipeValidation` before save.
- Updated `Remove-Recipe` to support `ByName` and `ById` parameter sets.
- Updated `Get-Recipe` default name matching to fuzzy substring (`-like`) and added optional `-Regex` mode.

### Notes
- Baseline commit created before optimization: `6ceb6cc`.
- Reliability optimization commit: `639fb85`.
