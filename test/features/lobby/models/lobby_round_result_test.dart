import 'package:flutter_test/flutter_test.dart';
import 'package:newsworld/features/lobby/models/lobby_round_result.dart';

void main() {
  group('LobbyRoundResult', () {
    test('parses API history and socket result payloads', () {
      final apiResult = LobbyRoundResult.fromApi(4, {
        'round_id': '20',
        'round_no': 7,
        'key': 'banker|bankerPair',
      });
      final socketResult = LobbyRoundResult.fromSocket(4, {
        'round_id': 21,
        'result': 'player',
        'userNetAmounts': const [],
      });

      expect(apiResult.key, 'banker|bankerPair');
      expect(apiResult.roundNo, 7);
      expect(socketResult.roundId, 21);
      expect(socketResult.key, 'player');
      expect(socketResult.toApiJson()['key'], 'player');
    });

    test('rejects missing identifiers and empty result keys', () {
      expect(
        () => LobbyRoundResult.fromApi(4, {'key': 'banker'}),
        throwsFormatException,
      );
      expect(
        () => LobbyRoundResult.fromSocket(4, {'round_id': 21, 'result': ''}),
        throwsFormatException,
      );
    });

    test(
      'merges by round id, replaces duplicate events, and sorts history',
      () {
        final merged = mergeLobbyRoundResults(
          const [
            LobbyRoundResult(deskId: 4, roundId: 3, key: 'tie'),
            LobbyRoundResult(deskId: 4, roundId: 1, key: 'banker'),
          ],
          const [
            LobbyRoundResult(deskId: 4, roundId: 3, key: 'player'),
            LobbyRoundResult(deskId: 4, roundId: 2, key: 'banker'),
          ],
        );

        expect(merged.map((result) => result.roundId), [1, 2, 3]);
        expect(merged.last.key, 'player');
      },
    );
  });
}
