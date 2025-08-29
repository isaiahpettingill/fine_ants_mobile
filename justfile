check:
    fvm flutter analyze
    fvm dart format .

test:
    fvm flutter test

fix:
    fvm dart fix --apply
