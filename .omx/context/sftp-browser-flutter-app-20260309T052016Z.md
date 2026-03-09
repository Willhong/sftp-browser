Task statement
- Build an SFTP file browser Flutter app using `dartssh2`.

Desired outcome
- Material 3 Flutter app with dark mode support, SSH server management, remote directory browsing, and SFTP download/upload/delete/rename operations.

Known facts/evidence
- Repo is the default Flutter scaffold with `pubspec.yaml`, `lib/main.dart`, and the stock widget test.
- Flutter CLI commands are constrained by sandbox access to the SDK lockfile outside the workspace.
- `dart pub get` is available from the bundled Dart SDK.

Constraints
- Must add `dartssh2` to `pubspec.yaml`.
- Must implement all requested screens and finish by running `openclaw system event --text "Done: SFTP browser Flutter app built" --mode now`.
- Network access from shell is restricted; verification may need to rely on local tooling where possible.

Unknowns/open questions
- Exact locally available versions for additional Flutter packages.
- Whether all Flutter analyze/test commands can run under the SDK sandbox constraints.

Likely codebase touchpoints
- `/home/will/workspace/sftp_browser/pubspec.yaml`
- `/home/will/workspace/sftp_browser/lib/main.dart`
- `/home/will/workspace/sftp_browser/test/widget_test.dart`
