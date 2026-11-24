# Code Signing Policy

This policy documents how official binary releases of **CCS Sleep Studio** (`https://github.com/CCS-NIMHANS/CCS_SleepStudio`) are built, verified, and code-signed for distribution under the **MIT License** ([LICENSE](LICENSE)).

## Attribution

> Free code signing provided by SignPath.io, certificate by SignPath Foundation.

## Platform Signing Overview

| Platform | Signing Authority / Mechanism | Scope |
| :--- | :--- | :--- |
| **Windows** (`.exe` app binaries, `analyse-nidra.exe`, bundled `.dll`s, Inno Setup installers for Full & Lite) | **SignPath Foundation** (`SignPath.io` open-source Authenticode EV certificate) | Eliminates Windows 11 Smart App Control blocks and Microsoft Defender SmartScreen warnings |
| **macOS** (`.app` inside `.zip` & `.dmg` for Full & Lite) | **Apple Developer ID Application** (Team `Y445J7MR4Q` — Arun Sasidharan) + **Hardened Runtime** + **Apple Notarization** & stapling | Eliminates macOS Gatekeeper quarantine warnings without requiring terminal commands |
| **Linux** (`.deb`, `.rpm`) | Automated AlmaLinux 8/9 & Ubuntu 22.04 Docker validation in CI | Reproducible GLIBC 2.28+ desktop bundles |

## Build Environment & Trust Model

- **GitHub-Hosted CI Runners Only:** All signed release binaries and installers are built exclusively from source in this public GitHub repository (`CCS-NIMHANS/CCS_SleepStudio`) on GitHub-hosted runners (`windows-2022`, `macos-15`, `ubuntu-22.04`).
- **Branch & Tag Controls:** Production release signing runs only on protected release tags (`v*`) pushed from `main` (or explicit maintainer `workflow_dispatch`), never from pull requests or fork workflows.
- **No Unreviewed External Code in Signed Artifacts:** External pull requests cannot access repository secrets or trigger signing workflows and must be reviewed and merged by a repository maintainer before any release tag is cut.

## Team Roles

| Role | Responsibility | Members |
| :--- | :--- | :--- |
| **Committers & Reviewers** | Author source code, review pull requests, run automated test suites (`flutter test`), and maintain dependency hygiene | CCS-NIMHANS maintainers led by **Dr. Arun Sasidharan** (`@arunsasidharan84`, Centre for Consciousness Studies, Department of Neurophysiology, NIMHANS) |
| **Approvers** | Approve release tags (`v*`), verify release notes, and approve SignPath signing requests when required | Repository administrators of `CCS-NIMHANS/CCS_SleepStudio` |
| **Contributors** | External community contributors submitting issues or pull requests (no direct commit or signing access) | Open-source contributors via pull requests |

## Privacy Policy

CCS Sleep Studio is an offline desktop polysomnography and sleep EEG analysis application. It processes recordings, hypnograms, and sleep reports strictly **locally on the user's machine**, does **not** collect telemetry or analytics, and does **not** transfer any data to external networked systems unless explicitly requested by the user (e.g., checking GitHub Releases for app updates).
