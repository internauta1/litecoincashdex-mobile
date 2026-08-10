import '../model/get_best_orders.dart';
import '../model/market.dart';
import '../utils/utils.dart';
import 'package:rational/rational.dart';
import '../model/error_string.dart';

class BestOrders {
  BestOrders({this.result, this.error, this.request});

  factory BestOrders.fromJson(Map<String, dynamic> json) {
    final BestOrders bestOrders = BestOrders(request: json['request']);
    if (json['result'] == null) return bestOrders;

    final Market action = bestOrders.request.action;
    final Map<String, dynamic> result = json['result'];
    final Map<String, dynamic> resultOrders =
        result['orders'] as Map<String, dynamic>;

    resultOrders.forEach((String ticker, dynamic items) {
      bestOrders.result ??= {};
      final List<BestOrder> list = [];
      for (final Map<String, dynamic> item in items) {
        list.add(BestOrder.fromJson(
          item,
          requestedCoin: bestOrders.request.coin,
          counterCoin: ticker,
          action: action,
        ));
      }
      bestOrders.result[ticker] = list;
    });

    return bestOrders;
  }

  Map<String, List<BestOrder>> result;
  ErrorString error;
  GetBestOrders request;
}

class BestOrder {
  BestOrder({
    this.price,
    this.maxVolume,
    this.minVolume,
    this.baseMaxVolume,
    this.baseMinVolume,
    this.relMaxVolume,
    this.relMinVolume,
    this.coin,
    this.otherCoin,
    this.requestedCoin,
    this.counterCoin,
    this.buyCoin,
    this.sellCoin,
    this.address,
    this.uuid,
    this.pubkey,
    this.isMine,
    this.action,
  });

  factory BestOrder.fromJson(
    Map<String, dynamic> json, {
    String requestedCoin,
    String counterCoin,
    Market action,
  }) {
    final Map<String, dynamic> price = json['price'];
    final Map<String, dynamic> address = json['address'];
    final Rational baseMaxVolume = _parseVolume(json['base_max_volume']);
    final Rational baseMinVolume = _parseVolume(json['base_min_volume']);
    final Rational relMaxVolume = _parseVolume(json['rel_max_volume']);
    final Rational relMinVolume = _parseVolume(json['rel_min_volume']);

    // best_orders keeps the requested coin on the raw base side. With BUY the
    // taker receives that base coin; with SELL the taker spends it. Normalize
    // only the semantic buy/sell coin names here and keep the raw fields intact.
    final String normalizedBuyCoin =
        action == Market.BUY ? requestedCoin : counterCoin;
    final String normalizedSellCoin =
        action == Market.BUY ? counterCoin : requestedCoin;

    return BestOrder(
      price: fract2rat(price['fraction']) ?? Rational.parse(price['decimal']),
      // Keep the old fields as aliases for code outside the Simple DEX.
      maxVolume: baseMaxVolume,
      minVolume: baseMinVolume,
      baseMaxVolume: baseMaxVolume,
      baseMinVolume: baseMinVolume,
      relMaxVolume: relMaxVolume,
      relMinVolume: relMinVolume,
      coin: json['coin'] ?? counterCoin,
      otherCoin: action == Market.SELL ? requestedCoin : counterCoin,
      requestedCoin: requestedCoin,
      counterCoin: counterCoin,
      buyCoin: normalizedBuyCoin,
      sellCoin: normalizedSellCoin,
      address: address == null ? null : address['address_data'],
      uuid: json['uuid'],
      pubkey: json['pubkey'],
      isMine: json['is_mine'] == true,
      action: action,
    );
  }

  /// Raw best_orders price: rel units per one raw base unit.
  Rational price;

  // Legacy aliases. Prefer the explicit base/rel or buy/sell fields below.
  Rational maxVolume;
  Rational minVolume;

  Rational baseMaxVolume;
  Rational baseMinVolume;
  Rational relMaxVolume;
  Rational relMinVolume;
  String coin;
  String otherCoin;
  String requestedCoin;
  String counterCoin;
  String buyCoin;
  String sellCoin;
  String address;
  String uuid;
  String pubkey;
  bool isMine;
  Market action;

  /// Price required by KDF `buy`: sell/rel units per one buy/base unit.
  Rational get tradePrice =>
      action == Market.BUY ? price : price?.inverse;

  Rational get maxBuyVolume =>
      action == Market.BUY ? baseMaxVolume : relMaxVolume;
  Rational get minBuyVolume =>
      action == Market.BUY ? baseMinVolume : relMinVolume;
  Rational get maxSellVolume =>
      action == Market.BUY ? relMaxVolume : baseMaxVolume;
  Rational get minSellVolume =>
      action == Market.BUY ? relMinVolume : baseMinVolume;

  /// Coin shown in the missing side of the Simple DEX selector.
  String get selectionCoin => action == Market.BUY ? sellCoin : buyCoin;
}

Rational _parseVolume(dynamic value) {
  if (value == null) return null;
  final Map<String, dynamic> volume = value as Map<String, dynamic>;
  return fract2rat(volume['fraction']) ?? Rational.parse(volume['decimal']);
}
