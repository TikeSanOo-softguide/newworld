# Mobile Member API Contract

**Phase:** Verification only. This document describes the existing Node.js contract for the Flutter `member` role. It does not propose a new phone-user flow and does not change application code.

## Member Authentication

### Login

- Route: `POST /api/auth/player_login`
- Request fields used by the existing clients: `account`, `password`, `equipment`, `browser`; `ip_address` is read by the controller and is optional from the request shape.
- The controller checks the account/password and then explicitly requires role name `member`. Wrong role returns HTTP 403. Disabled accounts are rejected. Login attempts are rate limited and three failed attempts lock the account temporarily.
- Successful response is not the standard `{success,message,data}` envelope. It contains `csrfToken`, `id`, `account`, `name`, `role`, `old_user_flg`, `trial_user_flg`, and `token_version`.
- The response also sets `member_auth_token` and `member_csrf_token` cookies.
- `accessToken` is conditionally added by `loginAccessFields`; it is not guaranteed by the login handler.

**Verified native token issue:** `shouldReturnAccessToken` returns false when cookies are secure, the request is HTTPS, and there is no `Origin` header. Native Flutter requests normally do not send a browser Origin. The existing Flutter `AuthService.login` reads `json['accessToken']` and fails if absent. Production native login therefore needs a stable, explicit token response mode on this same member route. Do not route the app through `/api/auth/phone_user_login`.

### Token and CSRF handling

- `generateToken` signs `id`, `token_version`, and the CSRF token claim; expiry is seven days.
- REST auth middleware accepts `Authorization: Bearer <JWT>` or the member auth cookie, verifies JWT expiry, active-account state, and `token_version`.
- Flutter `ApiClient` already attaches Bearer and `X-CSRF-Token` headers when provided.
- The login body includes `csrfToken`. Protected GET requests do not require CSRF; protected POST/PUT/PATCH/DELETE requests do.
- No refresh-token endpoint was found. New member login increments `token_version`; earlier sessions become superseded.

## Member Endpoint Matrix

The server mounts `/api/user` behind JWT auth and `requireRole(["member", "phone_user"])`; the endpoints below are therefore member-accessible. The mobile app must log in with `player_login` as role `member` and call this mount only. The separate `/api/phone_user` mount is out of scope.

| Workflow | Endpoint | Verified response/use |
|---|---|---|
| Profile and points | `GET /api/user/profile` | Standard response envelope; `data.user` is selected by `req.user.id`, excludes `password`, and includes `balance`, account/profile values, rate-limit data, and unsettled commission. Use this for the header. |
| Game catalog | `GET /api/user/games` | Standard envelope; `data.games`. Backend filters to member game types and includes game desks/result definitions. The React Home hides `NIUNIU` from category buttons. |
| Member desk list and history | `GET /api/user/desks?site_name=user` | Standard envelope; `data.desks`. `site_name=user` filters `online_betting_flg`. Desk object includes game, active session, last round, limits/settings, and `results` assembled from rounds in the active session. Each emitted result has `round_id`, joined `key`, `round_no`, `createdAt`, and `updatedAt`. |
| Result options | `GET /api/user/results_by_desk/:id` | Standard envelope; `data.results`, ordered by result `position`. These are result definitions, not historical outcomes. |
| Active round state | `GET /api/user/last_round_status/:desk_id` | Standard envelope with `data.lastRound.status` and `data.remaining_seconds`. |
| Member announcement | `GET /api/user/announce` | Standard envelope with latest type-1 announcement. The React Home ticker uses public parameter settings instead. |
| Safe public settings | `GET /api/public/user/parameter-settings` | Standard envelope; `data.parameterSettings`, a whitelist of `{type,value}`. Includes `web_bet_announcement`, `phone_bet_announcement`, and popup settings. |
| Public announcement | `GET /api/public/user/announce` | Public endpoint backed by the same latest user-facing announcement controller. |
| Presence update | `PATCH /api/user/room` | Protected mutation, Joi-validates `room`, requires Bearer/cookie and CSRF header. Body is `{room: "home" | desk label | ...}`; existing Flutter lobby sets `home`. |
| Logout | `POST /api/auth/player_logout` | Existing auth route accepts `{userId}`; clears member cookies and updates member/phone-user login state when it represents the current session. Existing Flutter service attempts logout then clears secure session locally. |

`GET /api/user/users/:id` is intentionally **not** the mobile profile contract. Its controller looks up the path ID without checking ownership and returns the full model without excluding the password field. Use `/api/user/profile`; backend hardening for the ID route is a separate security task.

## Desk Results and Ordering Contract

The relevant source is `../new-world/server/controllers/user/user.controller.js` (`getDesks`). It fetches the active `GameSession`, fetches its `GameRound` rows with `round_no ASC`, then queries `RoundResult` for those round IDs without an explicit SQL order. It groups result keys by `round_id` and constructs the `results` array with `Object.keys(resultsMap).map(...)`.

React `DeskCardTables` maps `desk.results` in the received order and does not sort before handing it to the roadmap components. Therefore React currently consumes the backend's resulting order as-is. Integer-like object keys enumerate in numeric key order, so the current response effectively orders grouped rounds by numeric `round_id`, not necessarily the earlier `round_no ASC` order. The per-round keys also have no explicit query order before joining with `|`. This is a verified ordering risk, not a confirmed production-data mismatch.

Do not change backend ordering until a fixture made from a real API response is passed through the current React algorithms and its expected sequence is recorded. If `round_no ASC` is confirmed as the product chronology, the smallest safe change is to serialize results by iterating the already ordered `rounds` array and looking up the grouped results per round. Add a deterministic within-round key order only if a React fixture demonstrates that it is needed.

## Socket.IO Contract

- Transport endpoint path: `/socket.io`.
- Authentication: send the existing member JWT as `handshake.auth.token`. Backend socket auth verifies JWT signature/expiry and `token_version`, then attaches `{id, role, account}` to the socket.
- Existing backend-to-client events include:
  - `desk:{deskId}:updateStatus` (operator status payload is forwarded as provided; React uses string statuses).
  - `desk:{deskId}:updateTimer` (countdown value).
  - `desk:{deskId}:updateResult` (round result payload).
  - `desk:{deskId}:dealCard` and `desk:{deskId}:deleteLastCard`.
  - `desk:{deskId}:finish-session` and `desk:{deskId}:invalid-game`.
  - `member_balance:change` and `online_player:force_logout` from member-related server utilities.
- Backend broadcasts these events globally; the reviewed code does not establish per-desk room subscriptions. Filter per-desk events in Flutter by desk ID.
- Current Flutter dependencies have `web_socket_channel`, which is not the Socket.IO protocol client. A compatible Dart Socket.IO dependency must be selected and approved before live events are implemented.
- On socket reconnect, reload authenticated desk/status/history data because events may have been missed. Surface superseded/invalid JWT state and return to member login.

## Missing or Unclear Backend Requirements

1. **Required for production native login:** return the member `accessToken` consistently for an explicitly identified native client. Current secure-HTTPS/no-Origin requests omit it.
2. **Required only for a separately displayed customer-service contact:** there is a general `customer_service_qq` setting, but it is excluded from `PUBLIC_PARAMETER_SETTING_TYPES`. The web ticker can use public `web_bet_announcement`; no public-safe contact field/API was verified. Add a narrow public field only if product requires a separate contact label.
3. **Required only to render a real shuffle state:** `GameRound.status` is an unconstrained string. Observed application statuses include `active`, `betting`, `dealing`, and `finished`; no current `shuffle`/`shuffling` event or API state was found. Define an explicit backend state/event before mapping it to `洗牌中...`.
4. **Recommended for roadmap parity:** confirm real member desk responses follow the intended chronological order and add deterministic result query/serialization ordering only after comparison with React fixtures.

No new game catalog, profile, desk, historical result, announcement, or standard round-status endpoint is required for the planned member dashboard. Endpoints above are routed through the member-permitted `/api/user` mount or a deliberately public-safe route.

## Source Files Verified

- Backend: `../new-world/server/routes/user/auth.routes.js`, `../new-world/server/routes/user/user.routes.js`, `../new-world/server/routes/user/public.routes.js`, `../new-world/server/server.js`, `../new-world/server/controllers/user/auth.controller.js`, `../new-world/server/controllers/user/user.controller.js`, `../new-world/server/middleware/auth.middleware.js`, `../new-world/server/middleware/csrf.middleware.js`, `../new-world/server/utils/crossOrigin.js`, `../new-world/server/utils/jwt.js`, `../new-world/server/socket/auth.middleware.js`, `../new-world/server/socket/game.socket.js`.
- Flutter: `lib/features/auth/auth_service.dart`, `lib/core/storage/secure_storage.dart`, `lib/core/network/api_client.dart`, `lib/core/constants/app_constants.dart`, `lib/features/preload/lobby_preload.dart`, `lib/features/lobby/lobby_page.dart`.
- React: `../new-world-member/client/src/api/user/playerAuth.ts`, `../new-world-member/client/src/api/user/index.ts`, `../new-world-member/client/src/lib/socket.ts`, `../new-world-member/client/src/pages/user/Home.tsx`, `../new-world-member/client/src/components/shared/CommonCardTable.tsx`.
