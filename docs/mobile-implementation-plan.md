# Flutter Member Dashboard Implementation Plan

**Status:** Phase 1 verification complete. No application code changes were made in this phase.

## Verified Git Baseline

At the start of Phase 1, `git status --short` showed these pre-existing changes, which were inspected and preserved:

- `lib/core/constants/app_constants.dart`: default non-web API host changed from `192.168.10.148` to `192.168.10.176`.
- `lib/features/lobby/lobby_page.dart`: existing lobby, refresh, result-grid, and trial-stamp work; this phase made no edits to it.
- `pubspec.lock`: resolved `url_launcher` 6.3.3 and its platform packages; `pubspec.yaml` already declares `url_launcher`.
- `docs/mobile-implementation-plan.md`: untracked planning document from the preceding planning phase.

No reset, revert, or overwrite was performed. Phase 1 only updates documentation and adds the two requested verification documents.

## Phase 4 - Flutter Socket.IO Integration

The Flutter lobby uses the backend's `/socket.io` endpoint, member JWT handshake authentication, and `desk:{deskId}:updateResult` events. A single Riverpod-owned `socket_io_client` 3.1.6 service validates and deduplicates round results, then updates the lobby's existing result data so all six Phase 2/3 roadmaps recalculate through their existing algorithms and painters. Reconnect and foreground resume synchronize from authenticated `/api/user/desks?site_name=user` history; logout and lobby disposal disconnect the client.

Phase 4 does not modify the Node.js backend or React frontend. Production native login remains blocked on the already documented backend guarantee for returning `accessToken` over secure requests without an Origin header.

## Scope and Role

The mobile dashboard is for the existing `member` role. It must use `POST /api/auth/player_login` and the member API mount (`/api/user`). Do not call `/api/auth/phone_user_login` or `/api/phone_user`, and do not adopt phone-user business rules. The backend's `/api/user` role list includes both `member` and `phone_user`; this plan uses it only with a member JWT.

The visual target is the supplied mobile screenshot: compact black/dark-gold header, scrolling announcement, blue game category tabs, dense table headings and statistics, and the historical result matrix plus the roadmap displays. Trial accounts receive the centered red outlined `试玩中` stamp over the road area.

## Existing Flutter Architecture

- Riverpod is the existing state-management solution.
- GoRouter owns navigation and auth-related pages.
- `ApiClient` uses `package:http`, supports Bearer and CSRF headers, and maps HTTP errors to `ApiException`.
- `SecureStorage` stores the auth token, CSRF token, member ID, account, name, trial flag, and balance.
- The current lobby and preload are in `lib/features/lobby/lobby_page.dart` and `lib/features/preload/lobby_preload.dart`.
- `pubspec.yaml` includes `flutter_riverpod`, `go_router`, `flutter_secure_storage`, `http`, and `web_socket_channel`; there is no Socket.IO-compatible Dart dependency in the current project.
- Flutter test support is configured, but no test files were found during this review.

Keep the feature within the existing `features/lobby` and `core` conventions. Separate models, API repository, providers, widgets, and roadmap calculations rather than growing the lobby page into the implementation of every responsibility.

## Verified Member Authentication and API Access

| Purpose | Existing route | Member access and verified data |
|---|---|---|
| Login | `POST /api/auth/player_login` | The controller accepts the member login flow and rejects a successfully authenticated account unless its role is exactly `member`. Response includes `csrfToken`, `id`, `account`, `name`, `role`, `old_user_flg`, `trial_user_flg`, and `token_version`. It also sets member auth and CSRF cookies. `accessToken` is conditional, not guaranteed. |
| Member profile/points | `GET /api/user/profile` | Mounted behind JWT auth and the `member`-permitted role middleware. Reads `req.user.id`, excludes the password, and returns `data.user`; use its `account` and `balance` for the dashboard header. It also includes rate-limit data and unsettled commission. |
| Game categories | `GET /api/user/games` | Protected by the same member route mount. Returns member-eligible game rows with game result definitions. The React home omits `NIUNIU` from its category buttons. Preserve that existing member dashboard behavior unless product requirements change. |
| Tables, active session, result history | `GET /api/user/desks?site_name=user` | Protected member route. `site_name=user` filters to online-betting-enabled desks. Each desk contains its game, active session, last round, and `results` assembled from the active session's rounds. A result entry includes `round_id`, joined `key`, `round_no`, and timestamps. |
| Table result definitions | `GET /api/user/results_by_desk/:id` | Protected member route. Returns the result options for that desk's game; this is a definition list, not the historical road sequence. |
| Current round status/countdown | `GET /api/user/last_round_status/:desk_id` | Protected member route. Returns `lastRound.status` and `remaining_seconds`. |
| Member announcement | `GET /api/user/announce` | Protected member route returning the latest type-1 announcement. The React lobby's ticker instead reads a public parameter setting. |
| Public lobby parameters | `GET /api/public/user/parameter-settings` | Public route; currently returns a whitelist including `phone_bet_announcement`, `web_bet_announcement`, and `pc_popup_announcement`. Use the same `web_bet_announcement` source as the React member home for its ticker. |
| Public preload | `GET /api/public/user/games`, `/desks?site_name=user`, `/cameras`, `/announce` | These routes are explicitly mounted without JWT and are used by the React preload flow. For the authenticated mobile dashboard, prefer the member endpoints above for profile, games, desks, results, and status. Public settings remain suitable for the existing public-safe announcement parameters. |

`GET /api/user/users/:id` is mounted under the member-permitted route, but is not the member-profile contract to use: its controller returns the full model without a password projection or an owner check. Use `/api/user/profile`, which selects the caller from `req.user.id` and excludes the password. Record backend hardening for the ID-based handler separately; do not make the mobile dashboard depend on it.

The server mounts `/api/user` with `authMiddleware`, `requireRole(["member", "phone_user"])`, banned-member rejection, and CSRF middleware. GET requests do not require a CSRF header; mutations such as `PATCH /api/user/room` do. No phone-user login, API mount, or phone-specific settings should be introduced into this feature.

### Token Delivery Requirement

The backend supports JWT Bearer auth for REST and verifies a JWT from `handshake.auth.token` for Socket.IO. The member login controller returns `accessToken` conditionally through `loginAccessFields`. In production with secure cookies over HTTPS, `shouldReturnAccessToken` returns false when the request has no `Origin` header; a native Flutter request normally has no browser Origin. The existing Flutter `AuthService.login` requires `accessToken`, so the mobile login path is not reliable under that production condition.

**Backend requirement before release:** establish an explicit native-client token response contract on the existing member login route (for example, an agreed mobile-client header or equivalent explicit mode). Keep the role check as `member`, issue the same member JWT/CSRF claims, and continue using TLS. Do not solve this by using the phone-user login route. The JWT currently expires after seven days; no refresh-token endpoint was found. Session replacement is enforced by `token_version`.

## React Dashboard and Roadmap Findings

The React member dashboard is `../new-world-member/client/src/pages/user/Home.tsx`; compact table composition is in `../new-world-member/client/src/components/shared/CommonCardTable.tsx`.

- The Home category filter uses API game names, selects all or one game, and excludes `NIUNIU`.
- The Home desk list is filtered to `online_betting_flg` desks, ordered by game position and desk position, and refreshes the relevant desk/profile data after live events.
- React counts banker/player/tie or dragon/tiger/tie from each result's `key` split on `|`. Pair markers are derived from `bankerPair` and `playerPair` keys.
- `MarkerRoad.tsx` is the recent-result matrix displayed on the left of the compact road group. It uses six rows, column-major result placement, and red/blue/green result rings with pair dots.
- `BigRoad.tsx` places the primary road, applies banker/player/dragon/tiger group changes, moves down then right on collisions or after six rows, and attaches ties to the previous main cell.
- `BigEyeRoad.tsx`, `SmallRoad.tsx`, and `CockroachRoad.tsx` each derive their color sequence from the base Big Road and use different starting columns and comparisons. Their placement logic also wraps horizontal overflow across two subcolumns.
- `SecondBigRoad.tsx` draws a compact three-row alternate history in the web dashboard. Confirm whether it is part of the requested mobile dashboard; the implementation should not silently omit it if parity is expected.
- `../new-world-member/client/src/utils/helper.ts` exports `generateBigRoadWithNoLShape`, which is used by the derived roads. It is not identical to the display Big Road algorithm in `BigRoad.tsx`; port and test both behaviors as used. Do not replace these with a new generic roadmap rule.
- The backend does not return precomputed roadmap cells. The mobile client must compute them from the ordered result sequence using a Dart port of the React algorithms.

**Ordering verification:** React's `DeskCardTables` maps `desk.results` directly into its result sequence and does not sort it. The backend fetches active-session rounds in `round_no ASC`, but then groups `RoundResult` rows in an object keyed by numeric `round_id` and emits `Object.keys(resultsMap)`. JavaScript integer-like object keys enumerate in numeric order, so the returned sequence is effectively ascending `round_id`, not explicitly the fetched `round_no` order. Also, the `RoundResult.findAll` has no explicit row order within a round. This is not a proven chronological contract: auto-increment IDs may happen to align with round numbers in current data, but no production DB sample was inspected.

**Do not change ordering yet.** First capture representative API responses and feed them unchanged to the React roadmap calculations. Confirm expected order against `round_no`, and verify whether multi-key order changes rendering. If `round_no ASC` is confirmed as the intended sequence, the smallest safe backend correction is to build the response by iterating the already ordered `rounds` array and looking up each round's results, rather than enumerating `Object.keys(resultsMap)`. Choose and test a deterministic within-round key order only if the React fixtures show it affects output.

## Real-Time Updates and Statuses

The backend uses Socket.IO. The member web client listens for per-desk `desk:{id}:updateStatus`, `desk:{id}:updateTimer`, `desk:{id}:updateResult`, and `desk:{id}:finish-session`, plus member events such as `member_balance:change` and `online_player:force_logout`. The Socket.IO auth middleware accepts the same member JWT in `handshake.auth.token` and checks `token_version`.

The Flutter project currently has `web_socket_channel`, not a Socket.IO client. It cannot be treated as a Socket.IO client. For parity, add a compatible Dart Socket.IO dependency after approval; authenticate the handshake with the stored member JWT, subscribe to the existing broadcast event names, and re-fetch desk/status data after reconnect to recover missed events. Do not invent server event names or assume per-desk socket rooms; the reviewed backend broadcasts these events globally.

`GameRound.status` is an unconstrained string column. The reviewed backend/UI paths use `active`, `betting`, `dealing`, and `finished`; no `shuffle`/`shuffling` status was found. `shuffle_type` is session configuration, not evidence that a round is currently shuffling. To show `洗牌中...` as a real status, the backend must document or emit a current shuffle state. Until then, do not map another status to it or display it as though it came from the server.

## Flutter Component and Data Plan

1. **Repository and models:** add typed models for member profile, game category, desk, round result, and live status. Parse the existing response envelope and preserve the `key` token list and round order. Use the `/api/user/profile` result for account and balance rather than `/api/user/users/:id`.
2. **Riverpod dashboard state:** load member profile, member games, member desks, announcement settings, and initial per-desk statuses. Track loading, partial failure, empty results, refresh, selected category, and per-desk live state. Avoid reloading all data for every timer tick.
3. **Header and announcement widgets:** use `assets/images/logo.png`, profile values, trial flag, and `web_bet_announcement`; animate long text in a clipped ticker. The screenshot's separately displayed service/contact number is not present in the public parameter whitelist.
4. **Category and table widgets:** derive tabs from the same API game rows and React's member filter; show desk name and statistics calculated from actual result keys. Keep the compact dark header and dense vertical table list.
5. **Roadmap calculation layer (Phase 2 complete):** six pure Dart transforms now produce immutable grid/marker models in `lib/features/lobby/roadmap/`. Dashboard painting and widgets remain for a later approved phase. The Flutter tests verify 21 hand-derived expected cases from the React source; a runtime React/API differential fixture and production result-order confirmation remain outstanding.
6. **Status rendering:** display only values actually returned by the backend. Add `洗牌中...` after the backend defines a corresponding status/event.
7. **Socket lifecycle:** connect with the member JWT, handle auth rejection/session supersession, apply per-desk events, and resync on reconnect. Keep REST as initial load and recovery path.

## Phase 2 Files

- `lib/features/lobby/roadmap/roadmap_models.dart`: immutable roadmap result, position, marker, and grid models.
- `lib/features/lobby/roadmap/roadmap_calculations.dart`: pure transforms for MarkerRoad, display Big Road, the No-L-Shape base helper, Big Eye Boy, Small Road, Cockroach Road, and Second Big Road.
- `test/features/lobby/roadmap/roadmap_calculations_test.dart`: 19 source-derived fixture tests.
- `test/features/lobby/roadmap/roadmap_calculations_test.dart`: 21 source-derived fixture tests.
- `docs/roadmap-algorithm-specification.md`: corrected React Home minimum widths and algorithm specification.

No dashboard UI, CustomPainter, provider, API repository, or Socket.IO implementation was added in Phase 2. React, backend, and database files remain untouched.

## Remaining Backend/Product Requirements

1. **Required for native production login:** return the existing member JWT consistently to an explicitly identified native client. Current secure-HTTPS/no-Origin behavior omits `accessToken`, but Flutter requires it.
2. **Required only if the screenshot must display a separate support contact:** provide a public-safe customer-service field/API. `customer_service_qq` exists in the general parameter setting types but is excluded from `PUBLIC_PARAMETER_SETTING_TYPES`; do not expose private settings wholesale.
3. **Required for a genuine shuffle indicator:** define and expose the current shuffle status over REST and Socket.IO, or confirm an existing status contract not found in the reviewed source.
4. **Recommended for faithful roadmap parity:** guarantee deterministic order for round history and document the joined result-key semantics; verify with API contract fixtures before porting the JavaScript algorithms.
5. **Development preview only:** add the local Flutter web origin to backend CORS or use the existing development proxy when testing in Chrome. Native Android/iOS API calls are not subject to browser CORS.

No additional game, stats, profile, announcement, or standard round-status endpoint was identified as missing for the planned member dashboard. The source/API checks above confirm those existing endpoints are routed through the member-permitted `/api/user` mount.

## Test and Acceptance Plan

- Model tests: parse login/profile, game, desk, joined result keys, status, missing/null optional fields, and malformed envelopes.
- Road algorithm tests: **21 tests pass** against expected outputs transcribed independently from the React source. They cover empty/single histories, streaks, alternating groups, ties, combined/pair keys, overflow, derived thresholds and collisions, special-six keys, guess markers, and long histories. React component algorithms are not exported as a runtime test API, so direct executable React-versus-Dart differential testing remains a follow-up; expected fixture values were not generated by Dart.
- Statistics tests: counts agree with the React key-splitting logic for Baccarat and Longhu.
- Widget tests: category selection, table list, trial watermark, loading/error/empty states, refresh behavior, and live status rendering.
- Painter/widget tests: grid dimensions at narrow and wide constraints; markers stay within cells; colors and pair/tie decorations render at the expected coordinates.
- API integration tests: member login and Bearer access, role rejection for non-members, profile/desk/status/announcement parsing, CSRF on mutations, and session supersession behavior.
- Socket integration tests: member JWT handshake, existing event names and payload variants, reconnect resync, invalid token, and superseded token handling.
- Visual comparison: capture target-size Android/iOS screenshots and compare header, banner, tabs, table statistics, matrix, road proportions, and trial watermark against the supplied reference.

## Approval Gate

Phase 2 is complete and awaits review. The calculation layer and focused tests are implemented, but no dashboard UI or Socket.IO integration has started. Before a later release phase, resolve native token delivery, shuffle-status behavior, public support-contact requirements if applicable, and result-order parity. No backend result ordering was changed.
