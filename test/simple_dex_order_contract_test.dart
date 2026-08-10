import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_dex/model/best_order.dart';
import 'package:komodo_dex/model/get_best_orders.dart';
import 'package:komodo_dex/model/get_buy.dart';
import 'package:komodo_dex/model/market.dart';
import 'package:rational/rational.dart';

Map<String, dynamic> _numeric(String numer, String denom) =>
    <String, dynamic>{
      'decimal': (Rational.parse(numer) / Rational.parse(denom))
          .toDecimalString(),
      'fraction': <String, String>{'numer': numer, 'denom': denom},
    };

BestOrder _parseOrder({
  Market action,
  String requestedCoin,
  String counterCoin,
  Map<String, dynamic> price,
  Map<String, dynamic> baseMax,
  Map<String, dynamic> relMax,
}) {
  final BestOrders parsed = BestOrders.fromJson(<String, dynamic>{
    'request': GetBestOrders(
      coin: requestedCoin,
      action: action,
      volume: Rational.parse('1'),
    ),
    'result': <String, dynamic>{
      'orders': <String, dynamic>{
        counterCoin: <Map<String, dynamic>>[
          <String, dynamic>{
            'coin': counterCoin,
            'price': price,
            'base_max_volume': baseMax,
            'base_min_volume': baseMax,
            'rel_max_volume': relMax,
            'rel_min_volume': relMax,
            'address': <String, dynamic>{'address_data': 'test-address'},
            'uuid': '11111111-2222-3333-4444-555555555555',
            'pubkey': 'test-pubkey',
            'is_mine': false,
          },
        ],
      },
    },
  });

  return parsed.result[counterCoin].single;
}

void main() {
  test('SELL LCC order normalizes to KDF buy LTC with inverse raw price', () {
    final BestOrder order = _parseOrder(
      action: Market.SELL,
      requestedCoin: 'LCC-segwit',
      counterCoin: 'LTC-segwit',
      price: _numeric('337971', '10000000000'),
      baseMax: _numeric('35818536439', '100000000'),
      relMax: _numeric('12105620597', '1000000000000'),
    );

    expect(order.sellCoin, 'LCC-segwit');
    expect(order.buyCoin, 'LTC-segwit');
    expect(order.selectionCoin, 'LTC-segwit');
    expect(order.maxSellVolume,
        Rational.parse('35818536439') / Rational.parse('100000000'));
    expect(order.maxBuyVolume,
        Rational.parse('12105620597') / Rational.parse('1000000000000'));
    expect(order.tradePrice,
        Rational.parse('10000000000') / Rational.parse('337971'));
    expect((order.maxSellVolume / order.tradePrice).toDouble(),
        closeTo(order.maxBuyVolume.toDouble(), 0.00000001));
  });

  test('BUY LTC order keeps raw price and base/rel volumes', () {
    final BestOrder order = _parseOrder(
      action: Market.BUY,
      requestedCoin: 'LTC-segwit',
      counterCoin: 'LCC-segwit',
      price: _numeric('10000000000', '337971'),
      baseMax: _numeric('12105620597', '1000000000000'),
      relMax: _numeric('35818536439', '100000000'),
    );

    expect(order.buyCoin, 'LTC-segwit');
    expect(order.sellCoin, 'LCC-segwit');
    expect(order.selectionCoin, 'LCC-segwit');
    expect(order.tradePrice,
        Rational.parse('10000000000') / Rational.parse('337971'));
    expect((order.maxSellVolume / order.tradePrice).toDouble(),
        closeTo(order.maxBuyVolume.toDouble(), 0.00000001));
  });

  test('requests exclude own orders and target the selected UUID', () {
    final Map<String, dynamic> bestOrdersJson = jsonDecode(
      getBestOrdersToJson(GetBestOrders(
        coin: 'LCC-segwit',
        action: Market.SELL,
        volume: Rational.parse('1'),
      )),
    );
    expect(bestOrdersJson['params']['exclude_mine'], isTrue);

    final Map<String, dynamic> buyJson = jsonDecode(
      getBuyToJson(GetBuySell(
        base: 'LTC-segwit',
        rel: 'LCC-segwit',
        volume: '0.012105620597',
        price: '29588.35208125785',
        orderType: BuyOrderType.FillOrKill,
        matchBy: <String, dynamic>{
          'type': 'Orders',
          'data': <String>['11111111-2222-3333-4444-555555555555'],
        },
      )),
    );
    expect(buyJson['base'], 'LTC-segwit');
    expect(buyJson['rel'], 'LCC-segwit');
    expect(buyJson['match_by']['type'], 'Orders');
    expect(buyJson['match_by']['data'].single,
        '11111111-2222-3333-4444-555555555555');
  });
}
