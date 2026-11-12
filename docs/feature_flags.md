# Feature flags (Flipper)

Anything a listener, contributor or speaker can see ships behind a flag, off by default.

- **Naming:** `f<issue-number>_<slug>`, e.g. `f72_example`.
- **Check in code:** `Flipper.enabled?(:f72_example, current_user)` in a controller, view or helper. Always make the code work with the flag on and off.
- **Turn on:** admins open `/flipper` (admin only; anyone else gets a 404). A flag can be enabled for the `admins` group, named users (actors), a percentage of users, or everyone.
- **In tests:** Flipper uses an in-memory adapter (`config.flipper.test_help`). Enable with `Flipper.enable(:f72_example)` and test both on and off; state resets between tests.
- **Delete a flag** once it is on for everyone and stable: remove the checks from code, then remove the flag in `/flipper`.
