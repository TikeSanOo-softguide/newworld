# Baccarat Game Detail Page

## Reference behavior

The member website enters a table from the home page and loads desk, result, camera, and member data. Baccarat result options are selected by `key` (`player`, `banker`, `tie`, `playerPair`, `bankerPair`); the backend `id` is submitted as `result_id`, and the displayed odds are the configured `ratio`. Taps stage chips locally; the separate **下注** action submits them. **取消** clears pending chips or cancels accepted bets during betting, except in the final five seconds. The inspected website has no working re-bet action.

The website's normal selector is configured with `100`, `1,000`, `5,000`, `10,000`, and `50,000`; its full chip asset set also contains `1`, `5`, `10`, `50`, `500`, and `100,000`. Flutter verifies the website's default denominations against the bundled asset manifest, shows four chips at a time with horizontal scrolling, and uses the complete asset denomination list when selecting the submitted chip image. There is no backend chip-configuration endpoint.

## Detail page visual layout

The detail screen uses a 16:9 video area, a compact balance row, a wide three-column betting board, and a single compact row for four visible chips and the cancel/submit/disabled re-bet actions. The Bead Plate and Big Road share the first roadmap row; the four supported derived roads use two further rows. Roadmap grids keep a responsive fixed cell size and scroll horizontally rather than shrinking their columns as history grows.

## Backend API mapping

Member routes require an authenticated member/phone-user session. Mutating routes also use the existing CSRF protection. Public lobby/camera routes do not require authentication. The API response envelope is `{ success, message, data }`.

| Purpose | Method and path | Relevant request / response |
|---|---|---|
| Desk and result history | `GET /api/user/desks?site_name=user` | `data.desks[]` includes desk/game/session/last-round data and results shaped as `{ round_id, key, round_no, ... }`. |
| Betting options and odds | `GET /api/user/results_by_desk/:desk_id` | `data.results[]`: `{ id, game_id, position, key, name, ratio }`. |
| Round status/countdown | `GET /api/user/last_round_status/:desk_id` | `data.lastRound.status`, `data.remaining_seconds`. |
| Existing bets | `GET /api/user/confirm_bets/:last_round` | `data.confirmedBets` keyed by outcome and `data.totalBetAmount`. |
| Table pool totals | `GET /api/user/round_pool_totals/:round_id` | `data.{round_id,pool_type,totals,display_totals}`. |
| Place bets | `POST /api/user/bet_results` | `{ last_round, bets: [{ result_id, amount, image }] }`; successful data includes `totalBetAmount`, `remainingBalance`, and `confirmedBets`. |
| Cancel accepted bets | `POST /api/user/cancle_bet_results` | `{ last_round }` (the spelling `cancle` is the backend route). |
| Member balance | `GET /api/user/profile` | `data.user.balance`. |
| Betting records | `GET /api/user/member_ledger` | Query: `startDate`, `endDate`, `page`, `limit`, optional table/shoe/bureau filters. Data includes `memberReports`, `totalReport`, and `pagination`. |
| Camera metadata | `GET /api/public/user/cameras` | Camera rows have `desk_id`, `camera_no`, `position`, and `url`. |
| HLS camera proxy | `GET /api/public/user/camera-proxy/:protocol/:encodedHost/:path` | Proxy accepts configured HTTP(S) hosts and `/hls/` paths; `transcode=1` is available for transport-stream paths. |
| Player room | `PATCH /api/user/room` | `{ room: <desk id> }` on entry, `home` on exit. |

The backend's bet handler validates balance, online-betting eligibility, member/result limits, and desk limits. The member profile supplies user-specific result limits; the desk response supplies its online result limits and table maximum. Flutter mirrors these checks when the latest pool totals are available, but the backend remains authoritative.

The inspected backend handler does not validate round status before accepting a bet. The cancellation handler also does not validate the round status or enforce a cancellation deadline. The website's final-five-seconds cancellation restriction is only a client-side rule. These are backend security/business-rule concerns; backend code was not modified.

## Socket.IO events

Flutter reuses the lobby's single Socket.IO connection and filters updates by desk ID:

| Event | Payload used by the app |
|---|---|
| `desk:<id>:updateResult` | `{ round_id, result, userNetAmounts? }` |
| `desk:<id>:updateTimer` | Numeric seconds |
| `desk:<id>:updateStatus` | Status string or `{ status }` |
| `desk:<id>:roundPoolTotals` | `{ round_id, pool_type, totals, display_totals }` |
| `desk:<id>:finish-session` | Triggers a detail/history refresh |

Result history continues to update the shared lobby preload state and uses the existing six roadmap calculations and painters. Incoming detail results are validated and deduplicated by round ID before updating the shared lobby state and roadmaps. Round status and countdown display in the video header; the roadmap panel has no persistent centered status overlay. Reconnection and app resume trigger API reconciliation for desk history, round status, profile, confirmed bets, and pool totals.

## Implementation limits

- The native video panel plays HLS sources through the existing camera proxy. Other website playback modes (WebRTC and generic iframe streams) are not implemented in the Flutter app.
- The camera API serializes more fields than a playback client needs, including camera IP and credentials. Flutter projects only the desk ID, camera ID/number, display order, and URL before storing camera rows, and strips URL user-info. However, the current server still sends those extra fields in the API response; a backend allowlisted camera response is still needed, and backend changes were outside this implementation.
- The reference website's customer-service messages are local-browser storage only and have no message API/socket. The Flutter action explains this limitation instead of pretending a message was delivered.
- The website has no re-bet button handler/API, so the screenshot's **续投** control is disabled.
- Bet placement and cancellation use the backend response as the source of truth; displayed balance and confirmed bets are refreshed from API data.
- The screen ticker uses the existing public `web_bet_announcement` preload setting.
