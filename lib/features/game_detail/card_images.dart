/// Card files copied from the member site. The filename is the suit plus rank.
///
/// Scanner and manual entry emit `S1` for an ace. A camera code such as `SA`
/// is rewritten to `S1` before `dealCard`. `T` is rewritten to `10` the same
/// way. Those two aliases are accepted here so a token that skipped that
/// rewrite still finds the file. Any other token has no image.
const cardBackAsset = 'assets/images/cards/back.jpg';

final _faceToken = RegExp(r'^[SHCD](?:10|[1-9JQK])$');
final _aceAlias = RegExp(r'^([SHCD])A$');
final _tenAlias = RegExp(r'^([SHCD])T$');

/// The asset for a face token, or null when [code] is not a known card.
String? cardFaceAsset(String code) {
  final token = cardFaceToken(code);
  if (token == null) return null;
  return 'assets/images/cards/$token.jpg';
}

/// Suit and rank used by the image set, or null when [code] is unknown.
String? cardFaceToken(String code) {
  final text = code.trim().toUpperCase();
  if (text.isEmpty) return null;
  final ace = _aceAlias.firstMatch(text);
  if (ace != null) return '${ace.group(1)}1';
  final ten = _tenAlias.firstMatch(text);
  if (ten != null) return '${ten.group(1)}10';
  if (_faceToken.hasMatch(text)) return text;
  return null;
}
