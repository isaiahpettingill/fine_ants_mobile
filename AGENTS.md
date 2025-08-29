* Use `fvm flutter pub` commands to manage packages. Do not edit pubspec by hand.
* Always run analyzers and fix before returning code.
* Split code out into different layers and modules.
* Always use `fvm flutter ...` to run flutter commands
* Never run the app
* Migrations and seeding should always be idempotent
* No need to call `bash -c` or `pwsh.exe -Command`. Shell commands work in a good default shell with no special configuration.
* You can use bash commands on windows via bash.exe (from mingw64)
* Prefer `just` commands when possible
