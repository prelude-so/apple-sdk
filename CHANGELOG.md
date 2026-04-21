# Change Log

Prelude Apple SDK Change Log

## [0.5.1] - 2026-04-21

- Fix iOS build failure in `Device.collect()`: pass `nil` for the new
  `webProperties` and `androidProperties` fields on the UniFFI-generated
  `Device` record (unblocks Apple SDK 0.5.0 consumers, including the
  React Native SDK).

## [0.5.0] - 2026-04-17

- Improved Silent Network Authentication per carrier configuration.
- Strengthen device signals.
- Improved the signal dispatch algorithm.

## [0.4.0] - 2026-02-16

- Implemented auto-retries during Silent Network Authentication redirection flow.
- Optimized signals collection.

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
