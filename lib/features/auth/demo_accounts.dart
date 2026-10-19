import '../../core/constants/app_constants.dart';

/// Local fake accounts for testing the two UI styles (no API required).
abstract final class DemoAccounts {
  static const List<DemoAccount> all = [
    DemoAccount(
      username: 'user1',
      password: '123456',
      uiStyle: UiStyle.u1,
      userId: 'demo-u1',
    ),
    DemoAccount(
      username: 'user2',
      password: '123456',
      uiStyle: UiStyle.u2,
      userId: 'demo-u2',
    ),
  ];

  static DemoAccount? match(String username, String password) {
    final user = username.trim().toLowerCase();
    for (final account in all) {
      if (account.username == user && account.password == password) {
        return account;
      }
    }
    return null;
  }
}

class DemoAccount {
  const DemoAccount({
    required this.username,
    required this.password,
    required this.uiStyle,
    required this.userId,
  });

  final String username;
  final String password;
  final UiStyle uiStyle;
  final String userId;
}
