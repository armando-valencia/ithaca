# Release Checklist

## Before Release

- Confirm the release branch is merged into `develop`.
- Build the `Ithaca` scheme in Release configuration.
- Run the available automated checks and resolve all failures.
- Verify the app launches, scans a workspace, opens each supported target, and
  registers its configured global shortcut.
- Update the marketing version and build number.

## Distribution

- Archive the Release build with the intended Developer ID certificate.
- Submit the archive for notarization and staple the notarization ticket.
- Verify the signed, stapled app on a clean macOS 26.2+ machine.
- Publish the archive with release notes and the versioned checksum.
