import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The member's chosen denomination for this visit.
///
/// Every desk uses the same chip images. The choice lives above the desk
/// page, so switching desks or returning through the lobby does not replace
/// it. The tray's scroll offset is not stored here.
class SelectedChipNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int value) => state = value;

  /// Picks 50, or the first coin, only when the member has not chosen one.
  /// A value that is already set is left unchanged.
  void useDefaultIfUnset(List<int> displayed) {
    if (state != null || displayed.isEmpty) return;
    state = displayed.contains(50) ? 50 : displayed.first;
  }
}

final selectedChipProvider = NotifierProvider<SelectedChipNotifier, int?>(
  SelectedChipNotifier.new,
);
