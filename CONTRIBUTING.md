# Contributing to photo_gallery_gdx_plus

Thank you for helping maintain `photo_gallery_gdx_plus`. Bug reports, feature requests, documentation improvements, tests, and code contributions are welcome.

## Before opening an issue

- Search [existing issues](https://github.com/47gurvinder/photo_gallery/issues) for a duplicate.
- Use the [feature request form](https://github.com/47gurvinder/photo_gallery/issues/new?template=feature_request.yml) for proposed enhancements.
- For bugs, include the package version, Flutter and Dart versions, platform and OS version, a minimal reproduction, expected behavior, actual behavior, and relevant logs.
- Do not disclose a security vulnerability in a public issue. Follow [SECURITY.md](SECURITY.md) instead.

## Pull Requests

1. Fork the repository and create a focused branch from `master`.
2. Keep changes scoped to one concern and preserve backward compatibility unless a breaking change has been discussed first.
3. Add or update tests for behavior changes.
4. Run the formatter, analyzer, and tests:

   ```shell
   dart format --set-exit-if-changed lib test example/lib
   flutter analyze
   flutter test
   flutter pub publish --dry-run
   ```

5. Update the changelog only for user-visible changes. Do not claim behavior that is not implemented and tested.
6. Open a [Pull Request](https://github.com/47gurvinder/photo_gallery/pulls) with a clear description and testing notes.

Generated files should only be changed by their owning tool. Do not remove copyright notices, license text, attribution, or third-party notices.

## Licensing and attribution

The project is licensed under the [BSD 3-Clause License](LICENSE). By contributing, you agree that your contribution may be distributed under that license and that you have the right to submit it.

This package continues the original [`Firelands128/photo_gallery`](https://github.com/Firelands128/photo_gallery) project. Preserve its authorship, license, and history. Neither the original copyright holder nor contributors may be represented as endorsing this maintained fork without permission.

## Community conduct

All participation is governed by the [Code of Conduct](CODE_OF_CONDUCT.md).
