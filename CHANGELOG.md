# Change Log

Prelude Apple SDK Change Log

## [0.3.0] - 2026-01-29

- Added specific configurations for Silent Verification requests, enabling carrier-specific behavior.

## [0.2.5] - 2025-12-16

- Change default timeouts and retry count for the dispatch signals request. By default, requests now time out after 5 seconds and retries happen automatically up to three times.
- Relax failure conditions for the dispatch signals request.
- Improved error messages for the SDK errors.

## [0.2.4] - 2025-09-22

- Added Silent Verification support for Bouygues

## [0.2.3] - 2025-09-02

- Updated to use SDK core version 0.1.2.
- Added new signal to detect when a user is connecting through a VPN application in the device and allow the connection.