# Feature flags (Flipper)

Anything a listener, contributor or speaker can see ships behind a flag, off by default.

- **Naming:** `f<issue-number>_<slug>`, e.g. `f72_example`.
- **Describe it:** add one plain-English line (what changes, where to try it) to `config/flipper_descriptions.yml` in the same PR. `/flipper` shows it with a link to the issue (built from the number in the name); a test fails if a flag has no description.
- **Check in code:** `Flipper.enabled?(:f72_example, current_user)` in a controller, view or helper. Always make the code work with the flag on and off.
- **Turn on:** admins open `/flipper` (admin only; anyone else gets a 404). A flag can be enabled for the `admins` group, named users (actors), a percentage of users, or everyone.
- **In tests:** Flipper uses an in-memory adapter (`config.flipper.test_help`). Enable with `Flipper.enable(:f72_example)` and test both on and off; state resets between tests.
- **Delete a flag** once it is on for everyone and stable: remove the checks from code, then remove the flag in `/flipper`.

## Admin-only changes

Admin pages and tools ship without a flag. `/admin` lists every admin page (including Feature flags and Jobs); add a new admin page to `AdminNavigation` (`app/services/admin_navigation.rb`) so it appears in the admin menu on every admin page.
