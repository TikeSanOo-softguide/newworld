# React Roadmap Algorithm Specification for Flutter

**Purpose:** Port the existing React member dashboard calculations without changing their rules. This is a source-derived specification and fixture set; it does not change application code or backend ordering.

## Input Contract

React road components receive `Result[]` (`../new-world-member/client/src/types/Result.ts`). The roadmap-relevant fields are:

```ts
type Result = {
  key: string;
  round_id?: number;
  round_no?: number | null;
  isGuess?: boolean;
};
```

The member desk API produces an ordered `results` list. Each desk result's `key` is a `|`-joined set of result keys for one round, for example `banker|bankerPair`. React passes the list through `CommonCardTable` without sorting. `isGuess` is an optional UI-only extension used by some React controls; it is not present in the backend desk result payload.

Use token membership (`key.split("|").includes(token)`), not string equality. Preserve the input list order. Do not normalize the order or invent result tokens in Flutter.

## Shared Result Classification

`FormatResultDisplay.ts` classifies display markers in this order:

1. `supertwoSix` or `superthreeSix` -> label `6`, red.
2. `banker` -> `庄`, red.
3. `player` -> `闲`, blue.
4. `tie` -> `和`, green.
5. `dragon` -> `龙`, red.
6. `tiger` -> `虎`, blue.

Pair indicators are independent flags: `bankerPair` is a red dot at the circle's top-left; `playerPair` is a blue dot at the bottom-right. If multiple recognized primary tokens occur, this display formatter's precedence determines the label.

The compact Home statistics use token membership per `Result` entry: count entries containing `banker`, `player`, `tie`, `dragon`, or `tiger`; count pair tokens separately. Pair counts do not change the main outcome count. The category selects Baccarat (`庄/闲/和`) or Longhu (`龙/虎/和`).

## Recent Result Matrix: MarkerRoad

Source: `../new-world-member/client/src/components/roadmaps/MarkerRoad.tsx`.

- Home layout uses six rows, 28px cells, eight visible columns (224px viewport); it expands the data column count as history grows and scrolls horizontally.
- Placement is column-major: `index = col * 6 + row`. Results 0-5 fill column 0 from row 0 through row 5; result 6 begins column 1, row 0.
- Every `Result` entry occupies a cell, including tie entries. The circle ring and pair dots use the shared classification above.
- Unused cells remain white with thin black borders.
- In scanner/manual detail pages, clicking a result can open video playback; this is outside the compact member Home matrix unless separately scoped.

## Big Road Display

Source: `../new-world-member/client/src/components/roadmaps/BigRoad.tsx`.

### Base outcome and group

For each input result, classify the main outcome by the first matching token in this order: `banker`, `player`, `tiger`, `dragon`; otherwise main is empty. The group is `banker-group` only when main equals one of `banker`, `supertwoSix`, or `superthreeSix`; otherwise it is the main value. Note that `getMainResult` itself does not return the latter two values, so preserve the source behavior rather than inferring a new special case.

### Positioning

- Logical cells are addressed by `(col,row)` and output as a record keyed by `${col}-${row}`.
- Initial state: `lastPos=(0,-1)`, empty previous group, horizontal mode false.
- A key containing `tie` increments `tieCount` on the current last cell and returns without adding a bead or updating position. A tie before any bead has no visible cell.
- A non-tie with a new group starts at row 0 in the first column whose row-0 cell is empty; it resets horizontal mode.
- A non-tie in the same group normally moves down one row. If the next row is 6 or already occupied in the current column, horizontal mode becomes true; this bead and following same-group beads go right on the same row. Horizontal mode persists until the main group changes. The implementation does not search for an empty right-side cell in horizontal mode; preserve that exact behavior.
- Home rendering is six rows and has a minimum 31 columns (`maxColUsed=30`, `colCount=maxColUsed+1`), 14px cells. Results may expand beyond the minimum width.
- Banker/dragon circles use a red outline; player/tiger and other occupied mains use blue. Pair dots are as above. A tie overlay draws a green diagonal and the tie count, colored according to the main outcome.

### Output cell

`{ main, tieCount, isGuess?, isBankerPair?, isPlayerPair? }` keyed by `${col}-${row}`.

## Shared No-L-Shape Base Road for Derived Roads

Source: `../new-world-member/client/src/utils/helper.ts`, `generateBigRoadWithNoLShape`.

- Uses the same main outcome precedence and group logic as the Big Road helper.
- A tie increments the last cell's `tieCount` and is not placed independently; a tie before the first bead is ignored.
- New group starts on row 0 in the first unoccupied row-0 column.
- Same group always moves straight down (`row + 1`). It has no six-row cap, collision handling, or rightward continuation. This is deliberately not the same placement algorithm as the displayed Big Road. Derived roads use this helper's column topology.
- Output is keyed by `${col}-${row}` with `{main,tieCount}`; pair flags and `isGuess` are not included.

Derived-road input columns are built from this helper result, scanning rows in ascending order. `nonTieResults` is the input list with entries containing `tie` removed; derived marker `isGuess` is copied by an advancing index into that list.

## Derived Roads: Big Eye Boy, Small Road, Cockroach

Sources: `BigEyeRoad.tsx`, `SmallRoad.tsx`, and `CockroachRoad.tsx` in `../new-world-member/client/src/components/roadmaps/`.

All three:

1. Build the No-L-Shape base road and its non-empty columns.
2. Derive a red/blue color per eligible base-road bead.
3. Place those colors in a six-row marker road with two logical subcolumns per display column.
4. Return a logical grid keyed `${col}-${row}-${subCol}` with `{color,isGuess?}`.
5. Home display renders three visual rows. Each visual cell contains a 2x2 arrangement of the logical subcolumn/row pairs. Home minimum widths are 16 visual columns for Big Eye and Small Road, and 15 for Cockroach Road (`colCount = max(maxColUsed + 1, pageConfig.maxColUsed)`). Home visual cells are 14px.

### Big Eye Boy

- Requires at least two base columns; otherwise empty.
- Starts at base column 1, entry 1. If base column 1 has exactly one bead, starts at column 2, entry 0.
- On a new base column, red when the immediately preceding base column depth equals the depth two columns before it; otherwise blue.
- Within a base column, compare the previous base column at the current row and one row above. Red if existence at those two rows is equal; otherwise blue.

### Small Road

- Requires at least three base columns; otherwise empty.
- Starts at column 2, entry 1. If base column 2 has exactly one bead, starts at column 3, entry 0.
- On a new base column, red when depth at `col-1` equals depth at `col-3`; otherwise blue.
- Within a base column, compare row and row-above existence in `col-2`. Equal booleans yield red; otherwise blue.

### Cockroach Road

- Requires at least four base columns; otherwise empty.
- Starts at column 3, entry 1. If base column 3 has exactly one bead, starts at column 4, entry 0.
- On a new base column, red when depth at `col-1` equals depth at `col-4`; otherwise blue.
- Within a base column, compare row and row-above existence in `col-3`. Equal booleans yield red; otherwise blue.
- Visual marks are diagonal slashes, red or blue.

### Derived marker collision/placement behavior

- The first marker or any marker whose color differs from the previous marker searches from column 0, row 0, subcolumn 0 for the first unoccupied top-row slot, checking subcolumns 0 then 1 before advancing a column. Vertical mode resets.
- Same-color markers move down one row while the next row is below six and the same logical subcolumn cell is free.
- If that row is out of bounds or occupied, horizontal mode becomes true. Subsequent same-color markers stay on the same row and advance subcolumn 0 -> 1 -> next column, preserving horizontal mode until color changes.
- The displayed 2x2 visual cell is only a rendering grouping; calculation coordinates remain `(col,row,subCol)`.

## Second Big Road

Source: `../new-world-member/client/src/components/roadmaps/SecondBigRoad.tsx`.

- This is not a derived red/blue road. It compacts each non-tie `Result` into a primary bead, recognizing main values in order: banker or supertwo/superthree -> banker; player; dragon; tiger; otherwise empty main.
- A result whose key contains `tie` increments the most recent compact bead's tie count and creates no bead. A tie before any non-tie is ignored.
- Pair flags are preserved from the original joined key.
- Output is rendered in three rows, column-major: `index = col * 3 + row`. Home has a minimum 15 columns; grows to `ceil(compactResultCount / 3)` when necessary; cells are 14px.
- Main circles are red for banker/dragon and blue for player/tiger. Banker/player pair dots and green tie diagonal/count match the Big Road style.

## Representative React-Derived Fixtures

Use these fixtures as pure calculation tests before painter tests. Inputs are ordered `Result.key` values; expected coordinates are algorithm output, not hardcoded production game data.

### Fixture 1: Matrix order and compact stats

Input:

```json
["banker|bankerPair", "banker", "player", "tie", "player|playerPair", "player", "dragon"]
```

Expected:

- MarkerRoad positions: indices 0-5 -> `(col=0,row=0..5)`; index 6 -> `(col=1,row=0)`.
- Main stats for the first six results: banker 2, player 3, tie 1; banker pair 1, player pair 1.
- The result at index 0 gets the banker-pair dot; index 4 gets the player-pair dot.

### Fixture 2: Big Road tie and pairs

Input:

```json
["banker|bankerPair", "banker", "player", "tie", "player|playerPair", "player"]
```

Expected Big Road cells:

| Position | Main | Tie count | Pair markers |
|---|---|---:|---|
| `(0,0)` | banker | 0 | banker pair |
| `(0,1)` | banker | 0 | none |
| `(1,0)` | player | 1 | none |
| `(1,1)` | player | 0 | player pair |
| `(1,2)` | player | 0 | none |

### Fixture 3: Big Road six-row overflow

Input: seven consecutive `banker` entries.

Expected display Big Road positions: `(0,0)` through `(0,5)`, then `(1,5)`. Horizontal mode remains active for the remainder of that group. In contrast, the No-L-Shape helper places seven same-group beads at `(0,0)` through `(0,6)`.

### Fixture 4: Derived-road start thresholds and colors

- Big Eye input `banker, player, banker`: the third base column is a one-bead column, so Big Eye starts at base col 2 entry 0; its first marker is red at `(col=0,row=0,subCol=0)` because depths of cols 1 and 0 are equal.
- Big Eye input `banker, player, player`: starts at base col 1 entry 1; at row 1 the left column contains row 0 but not row 1, so the first marker is blue at `(0,0,0)`.
- Small Road input `banker, player, banker, player`: third base column is a one-bead column, so it starts at base col 3 entry 0; depths of col 2 and col 0 match, producing first red marker at `(0,0,0)`.
- Cockroach input `banker, player, banker, player, banker`: fourth base column is a one-bead column, so it starts at base col 4 entry 0; depths of col 3 and col 0 match, producing first red slash at `(0,0,0)`.

### Fixture 5: Second Big Road compaction

Input:

```json
["banker|bankerPair", "banker", "player", "tie", "player|playerPair", "player"]
```

Expected compact positions (column-major, three rows): `(0,0)` banker/pair, `(0,1)` banker, `(0,2)` player with tie count 1, `(1,0)` player/pair, `(1,1)` player.

## Porting and Verification Rules

- Pure Dart transforms are implemented in `lib/features/lobby/roadmap/roadmap_calculations.dart`; immutable result, position, marker, and grid models are in `lib/features/lobby/roadmap/roadmap_models.dart`. They have no Flutter widget, painter, provider, or API dependency.
- Display Big Road and `generateBigRoadWithNoLShape` remain separate functions.
- The implementation preserves source token precedence, tie-before-first behavior, subcolumn search, six-row limits, horizontal-mode persistence, and React Home minimum columns.
- `flutter test` passes 21 source-derived fixture cases in `test/features/lobby/roadmap/roadmap_calculations_test.dart`. Each test records an input and independently written expected coordinates/marker attributes from the React source; expected values are not generated by Dart.
- A runtime React-versus-Dart differential fixture using actual API history has not yet been run. It remains required before declaring production-data parity or changing backend result ordering.
- Rendering should use server-provided result keys only. Do not invent missing rounds, markers, or a shuffle state.
