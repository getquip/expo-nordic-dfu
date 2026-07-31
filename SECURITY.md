# Security Policy

`@getquip/expo-nordic-dfu` is an Expo module that wraps Nordic Semiconductor's
official iOS and Android Secure DFU libraries. This document explains which
versions receive security fixes and how to report a vulnerability.

## Supported Versions

Security fixes are applied only to the most recently published release line. In
keeping with the project's modern-only support policy (current Expo and Nordic
SDKs), older major versions do not receive backported fixes — please stay on the
latest release.

| Version | Supported          |
| ------- | ------------------ |
| latest major   | :white_check_mark: |
| < latest major | :x:                |

## Reporting a Vulnerability

Please report security vulnerabilities **privately** through GitHub — not through
public issues, pull requests, or discussions.

1. Go to the repository's **Security** tab and choose **Report a vulnerability**,
   or open a new private advisory directly:
   <https://github.com/getquip/expo-nordic-dfu/security/advisories/new>
2. Include as much of the following as you can:
   - The affected version (e.g. `3.0.2`) and platform (iOS or Android, plus OS version).
   - A clear description of the issue and its security impact.
   - Steps to reproduce, and a proof of concept if you have one.
   - Any suggested fix or mitigation.

This is a community-maintained project with limited capacity, so responses are
best-effort. We aim to acknowledge a report within 5 business days and will keep
you updated as we investigate. Please give us a reasonable opportunity to release
a fix before disclosing the issue publicly; we're glad to coordinate timing and to
credit you in the advisory if you'd like.

This module is a thin wrapper around upstream code. If the issue is in Nordic's
DFU libraries ([Android](https://github.com/NordicSemiconductor/Android-DFU-Library),
[iOS](https://github.com/NordicSemiconductor/IOS-DFU-Library)) or in
[Expo](https://github.com/expo/expo) / React Native, please report it to that
project. For issues in this module's own TypeScript API or its native (Kotlin /
Swift) bridge, use the process above.
