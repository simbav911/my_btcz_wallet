class BitcoinZConstants {
  static const String NAME = "BitcoinZ";
  static const String SHORTNAME = "BTCZ";
  static const String NET = "mainnet";
  static const List<int> P2PKH_VERBYTE = [0x1C, 0xB8];
  static const List<List<int>> P2SH_VERBYTES = [[0x1C, 0xBD]];
  static const String GENESIS_HASH = 'f499ee3d498b4298ac6a64205b8addb7c43197e2a660229be65db8a4534d75c1';
  static const int REORG_LIMIT = 800;
  static const int TX_COUNT = 171976;
  static const int TX_COUNT_HEIGHT = 81323;
  static const int TX_PER_BLOCK = 3;
}
