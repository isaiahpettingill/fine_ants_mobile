check:
    fvm flutter analyze
    fvm dart format .

test:
    fvm flutter test

fix:
    fvm dart fix --apply

# Copy app icons from new_icons into platform folders
set-icons:
    fvm dart run tool/set_icons.dart

icons: set-icons
