# FAF Caster UI Mod release preparation

## Branch policy

- `main` contains stable releases.
- `develop` contains integration and testing.
- Work on `feature/*` or `fix/*` branches and merge into `develop` through pull requests.
- Release only after testing a real observer game and promoting `develop` to `main`.

## Version scheme

User-facing releases use `YY.MM.N`, starting with `26.11.0` (first release in November 2026), followed by `26.11.1`. Git tags use `v26.11.0`.

FAF `mod_info.lua` currently uses a numeric `version` field. Keep that field numeric and increment it for published mod revisions. Do **not** assume the Vault accepts a dotted calendar version in that field without verification. Display the calendar version in release notes and, after validation, the mod description or name if appropriate.

## Vault checklist

1. Replace the current development identity (`FAF Caster Test`, `FAF-CASTER-TEST-001`) with an agreed stable mod identity and UID **before the first public release**. Do not silently change the UID on existing installed test builds.
2. Confirm the UI mod's observer telemetry behaviour in a live game, including observer focus and match transitions.
3. Run the GitHub Actions mod packaging workflow and download `FAF-Caster-UI-Mod.zip`.
4. Inspect the ZIP: it must contain a single top-level `FAF-Caster-UI-Mod/` folder and a root `mod_info.lua` inside that folder, alongside the Lua files.
5. Install the ZIP contents into the FAF client's UI mods location, enable the mod and test the desktop Bridge.
6. Upload the tested package manually to the FAF Mod Vault using the supported client workflow; CI packaging does **not** upload it automatically.
7. Tag the tested stable commit on `main` as `v26.11.0`.

Cloud session linking is **out of scope for 26.11.0**. OBS overlay configuration belongs to the separately built desktop Overlay Studio.
