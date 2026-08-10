import 'dart:convert';
import '../model/market.dart';
import 'package:rational/rational.dart';

String getBestOrdersToJson(GetBestOrders data) => json.encode(data.toJson());

class GetBestOrders {
  GetBestOrders({
    this.userpass,
    this.method = 'best_orders',
    this.mmrpc = '2.0',
    this.coin,
    this.volume,
    this.action,
    this.excludeMine = true,
  });

  String userpass;
  String method;
  String mmrpc;
  String coin;
  Rational volume;
  Market action;
  bool excludeMine;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'method': method,
        'userpass': userpass,
        'mmrpc': mmrpc,
        'params': {
          'coin': coin,
          'action': action == Market.BUY ? 'buy' : 'sell',
          'exclude_mine': excludeMine,
          'request_by': {
            'type': 'volume',
            'value': volume.toDecimalString(),
          }
        }
      };
}
