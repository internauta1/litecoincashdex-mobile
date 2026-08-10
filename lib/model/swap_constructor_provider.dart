import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:rational/rational.dart';

import '../app_config/app_config.dart';
import '../blocs/coins_bloc.dart';
import '../model/best_order.dart';
import '../model/buy_response.dart';
import '../model/coin.dart';
import '../model/coin_balance.dart';
import '../model/get_best_orders.dart';
import '../model/get_buy.dart';
import '../model/get_max_taker_volume.dart';
import '../model/get_trade_preimage_2.dart';
import '../model/market.dart';
import '../model/rpc_error.dart';
import '../model/trade_preimage.dart';
import '../screens/dex/trade/pro/confirm/protection_control.dart';
import '../services/mm.dart';
import '../services/mm_service.dart';
import '../utils/log.dart';
import '../utils/utils.dart';

class ConstructorProvider extends ChangeNotifier {
  ConstructorProvider() {
    _timer ??= Timer.periodic(
        const Duration(seconds: 5), (_) => _updateMatchingOrder());
  }

  String _sellCoin;
  String _buyCoin;
  Rational _sellAmount;
  Rational _buyAmount;
  BestOrder _matchingOrder;
  TradePreimage _preimage;
  Rational _maxTakerVolume;
  String _warning;
  String _error;
  bool _inProgress = false;
  Timer _timer;

  String get error => _error;
  set error(String value) {
    _error = value;
    notifyListeners();
  }

  String get warning => _warning;
  set warning(String value) {
    _warning = value;
    notifyListeners();
  }

  bool get inProgress => _inProgress;
  set inProgress(bool value) {
    _inProgress = value;
    notifyListeners();
  }

  TradePreimage get preimage => _preimage;
  set preimage(TradePreimage value) {
    _preimage = value;
    notifyListeners();
  }

  bool get haveAllData {
    return _sellCoin != null &&
        _buyCoin != null &&
        (_buyAmount?.toDouble() ?? 0) > 0 &&
        (_sellAmount?.toDouble() ?? 0) > 0 &&
        _matchingOrder != null;
  }

  String get sellCoin => _sellCoin;
  set sellCoin(String value) {
    _sellCoin = value;
    _sellAmount = null;
    _updateMaxTakerVolume();
    if (value == null) {
      _matchingOrder = null;
      _preimage = null;
      _error = null;
    }
    _warning = null;
    notifyListeners();
  }

  String get buyCoin => _buyCoin;
  set buyCoin(String value) {
    _buyCoin = value;
    _buyAmount = null;
    if (value == null) {
      _matchingOrder = null;
      _preimage = null;
      _error = null;
    }
    _warning = null;
    notifyListeners();
  }

  Rational get sellAmount => _sellAmount;
  set sellAmount(Rational value) {
    _warning = null;

    if (value != null) {
      // if > than balance
      if (value > maxSellAmt) value = maxSellAmt;

      if (_matchingOrder != null) {
        final Rational price = _matchingOrder.tradePrice;
        final Rational maxOrderAmt = _matchingOrder.maxSellVolume;
        // if > than order max volume
        if (maxOrderAmt != null && value > maxOrderAmt) {
          value = maxOrderAmt;
          _warning = 'Sell amount was set to '
              '${cutTrailingZeros(value.toStringAsFixed(appConfig.tradeFormPrecision))} '
              '$_sellCoin, which is the max volume available for this price';
        }

        _buyAmount = value / price;
      }
    }

    _sellAmount = value;
    notifyListeners();

    _updatePreimage();
  }

  Rational get buyAmount => _buyAmount;
  set buyAmount(Rational value) {
    _warning = null;

    if (value != null) {
      if (_matchingOrder != null) {
        final Rational maxOrderAmt = _matchingOrder.maxBuyVolume;
        // if > than order max volume
        if (maxOrderAmt != null && value > maxOrderAmt) {
          value = maxOrderAmt;
          _warning = 'Buy amount was set to '
              '${cutTrailingZeros(value.toStringAsFixed(appConfig.tradeFormPrecision))} '
              '$_buyCoin, which is the max volume available for this price';
        }

        final Rational price = _matchingOrder.tradePrice;

        // if > than max sell balance
        if (value * price > maxSellAmt) {
          value = maxSellAmt / price;
        }

        _sellAmount = value * price;
      }
    }

    _buyAmount = value;
    notifyListeners();

    _updatePreimage();
  }

  BestOrder get matchingOrder => _matchingOrder;
  set matchingOrder(BestOrder value) {
    _matchingOrder = value;
    notifyListeners();
  }

  Rational get maxSellAmt {
    if (_sellCoin == null) return null;

    if (_maxTakerVolume != null) return _maxTakerVolume;

    final CoinBalance coinBalance = coinsBloc.getBalanceByAbbr(_sellCoin);
    if (coinBalance == null) return null;

    return deci2rat(coinBalance.balance.balance);
  }

  /// Percentage buttons start from the spendable wallet balance, then cap the
  /// amount to the exact maker order selected by the user.
  Rational sellAmountForPercentage(double pct) {
    if (maxSellAmt == null) return null;

    Rational amount = maxSellAmt *
        Rational.parse('$pct') /
        Rational.parse('100');
    final Rational orderMax = _matchingOrder?.maxSellVolume;
    if (orderMax != null && amount > orderMax) amount = orderMax;
    return amount;
  }

  void onBuyAmtFieldChange(String newText) {
    Rational newAmount;
    try {
      newAmount = Rational.parse(newText);
    } catch (_) {
      _buyAmount = null;
      if (_matchingOrder != null) _sellAmount = null;
      _preimage = null;
      notifyListeners();
      return;
    }

    if (_buyAmount != null) {
      final String currentText = cutTrailingZeros(
          _buyAmount.toStringAsFixed(appConfig.tradeFormPrecision));
      if (newText == currentText) return;
    }

    buyAmount = newAmount;
  }

  void onSellAmtFieldChange(String newText) {
    Rational newAmount;
    try {
      newAmount = Rational.parse(newText);
    } catch (_) {
      _sellAmount = null;
      if (_matchingOrder != null) _buyAmount = null;
      _preimage = null;
      notifyListeners();
      return;
    }

    if (_sellAmount != null) {
      final String currentText = cutTrailingZeros(
          _sellAmount.toStringAsFixed(appConfig.tradeFormPrecision));
      if (newText == currentText) return;
    }

    sellAmount = newAmount;
  }

  Future<BestOrders> getBestOrders(Market coinsListType) async {
    String coin;
    Rational amount;
    Market action;

    if (coinsListType == Market.SELL) {
      coin = _buyCoin;
      amount = _buyAmount;
      action = Market.BUY;
    } else {
      coin = _sellCoin;
      amount = _sellAmount;
      action = Market.SELL;
    }

    final BestOrders bestOrders = await MM.getBestOrders(GetBestOrders(
      coin: coin,
      action: action,
      volume: amount,
    ));

    if (bestOrders.error != null) return bestOrders;
    if (bestOrders.result == null) return bestOrders;

    final LinkedHashMap<String, Coin> known = await coins;
    final List<String> tickers = List.from(bestOrders.result.keys);
    for (String ticker in tickers) {
      if (!known.containsKey(ticker)) {
        bestOrders.result.remove(ticker);
      }
      if (appConfig.walletOnlyCoins.contains(ticker)) {
        bestOrders.result.remove(ticker);
      }
      final Coin coin = coinsBloc.getCoinByAbbr(ticker);
      if (coin?.suspended == true) {
        bestOrders.result.remove(ticker);
      }
    }

    return bestOrders;
  }

  Future<void> selectOrder(BestOrder order) async {
    final Rational requestedSellAmount = _sellAmount;
    final Rational requestedBuyAmount = _buyAmount;
    _matchingOrder = order;

    Log('LCC_SIMPLE_SELECTED',
        'uuid=${order.uuid} action=${order.action} '
        'buy=${order.buyCoin} sell=${order.sellCoin} '
        'rawPrice=${order.price} tradePrice=${order.tradePrice} '
        'minBuy=${order.minBuyVolume} maxBuy=${order.maxBuyVolume} '
        'minSell=${order.minSellVolume} maxSell=${order.maxSellVolume} '
        'isMine=${order.isMine}');

    if (order.action == Market.BUY) {
      sellCoin = order.sellCoin;
      await _updateMaxTakerVolume();
    } else {
      buyCoin = order.buyCoin;
    }

    // Fixed-volume maker orders must use the exact rational values supplied
    // by KDF. Recalculating through the visible amount and price introduces
    // tiny rounding differences that make FillOrKill wait and expire.
    final bool isFixedVolumeOrder =
        order.minBuyVolume != null &&
        order.maxBuyVolume != null &&
        order.minSellVolume != null &&
        order.maxSellVolume != null &&
        order.minBuyVolume == order.maxBuyVolume &&
        order.minSellVolume == order.maxSellVolume;

    if (isFixedVolumeOrder) {
      _buyAmount = order.maxBuyVolume;
      _sellAmount = order.maxSellVolume;
      _warning = null;

      Log('LCC_SIMPLE_FIXED_ORDER_EXACT',
          'uuid=${order.uuid} buy=$_buyAmount sell=$_sellAmount '
          'price=${order.tradePrice}');

      notifyListeners();
      await _updatePreimage();
      return;
    }

    if (order.action == Market.BUY) {
      buyAmount = requestedBuyAmount;

      if (_buyAmount == order.maxBuyVolume) {
        _warning = 'Buy amount was set to '
            '${cutTrailingZeros(_buyAmount.toStringAsFixed(appConfig.tradeFormPrecision))} '
            '$_buyCoin, which is the max volume available for this price';
      }
    } else {
      sellAmount = requestedSellAmount;

      if (_sellAmount == order.maxSellVolume) {
        _warning = 'Sell amount was set to '
            '${cutTrailingZeros(_sellAmount.toStringAsFixed(appConfig.tradeFormPrecision))} '
            '$_sellCoin, which is the max volume available for this price';
      }
    }
  }

  Future<void> makeSwap({
    ProtectionSettings protectionSettings,
    BuyOrderType buyOrderType,
    Function(dynamic) onSuccess,
    Function(dynamic) onError,
  }) async {
    final Rational price = _matchingOrder.tradePrice;
    final Rational volume = _buyAmount;

    if (_matchingOrder.uuid == null || _matchingOrder.uuid.isEmpty) {
      onError('The selected order has no UUID and cannot be matched safely.');
      return;
    }

    Log('LCC_SIMPLE_POSTBUY',
        'target=${_matchingOrder.uuid} base=$_buyCoin rel=$_sellCoin '
        'volume=$volume price=$price sell=$_sellAmount');

    final dynamic re = await MM.postBuy(
      mmSe.client,
      GetBuySell(
        base: _buyCoin,
        rel: _sellCoin,
        orderType: buyOrderType,
        baseNota: protectionSettings.requiresNotarization,
        baseConfs: protectionSettings.requiredConfirmations,
        volume: {
          'numer': volume.numerator.toString(),
          'denom': volume.denominator.toString(),
        },
        price: {
          'numer': price.numerator.toString(),
          'denom': price.denominator.toString(),
        },
      ),
    );

    Log('LCC_SIMPLE_POSTBUY',
        'responseType=${re.runtimeType} response=$re');

    if (re is BuyResponse) {
      onSuccess(re);
    } else {
      onError(re);
    }
  }

  BestOrder getTickerTopOrder(List<BestOrder> tickerOrdersList, Market type) {
    final List<BestOrder> sorted = List.from(tickerOrdersList);
    // This code appears to remove orders placed by the current wallet
    // so that the user doesn't trade with themselves
    sorted.removeWhere((BestOrder order) {
      if (order.isMine == true) return true;

      final String coin = order.selectionCoin;
      final CoinBalance coinBalance = coinsBloc.getBalanceByAbbr(coin);

      // ZHTLC address is null (Shielded), so we can't check it.
      // This removes the protection against users taking their own maker orders
      if (coinBalance == null || order.address == null) {
        return false;
      }
      return coinBalance.balance.address.toLowerCase() ==
          order.address.toLowerCase();
    });
    // Compare the normalized KDF buy price (sell per buy), not the raw
    // best_orders orientation, which is reversed for action=SELL.
    sorted.sort((a, b) =>
        a.tradePrice.toDouble().compareTo(b.tradePrice.toDouble()));
    return sorted.isNotEmpty ? sorted[0] : null;
  }

  bool anyLists() {
    if (buyCoin != null && sellCoin != null) return false;
    if (sellCoin != null && (sellAmount?.toDouble() ?? 0) == 0) return false;
    if (buyCoin != null && (buyAmount?.toDouble() ?? 0) == 0) return false;

    return true;
  }

  void reset() {
    _sellCoin = null;
    _buyCoin = null;
    _sellAmount = null;
    _buyAmount = null;
    _matchingOrder = null;
    _maxTakerVolume = null;
    _preimage = null;
    _error = null;
    _warning = null;

    notifyListeners();
  }

  Future<void> _updateMatchingOrder() async {
    // Keep the exact order explicitly selected by the user.
    // Percentage buttons may change the requested volume, but must never
    // replace the selected maker order with another order from the queue.
    // KDF validates its availability when preimage/postBuy is executed.
    if (_matchingOrder == null) return;
  }

  Future<void> _updatePreimage() async {
    if (haveAllData) {
      inProgress = true;
      Log('LCC_SIMPLE_PREIMAGE',
          'target=${_matchingOrder.uuid} base=$_buyCoin rel=$_sellCoin '
          'volume=$_buyAmount price=${_matchingOrder.tradePrice} '
          'sell=$_sellAmount');
      final TradePreimage preimage = await MM.getTradePreimage2(
          GetTradePreimage2(
              swapMethod: 'buy',
              base: _buyCoin,
              rel: _sellCoin,
              volume: _buyAmount,
              price: _matchingOrder.tradePrice));
      inProgress = false;

      if (_validatePreimage(preimage)) {
        _preimage = preimage;
      } else {
        _preimage = null;
      }
    } else {
      _preimage = null;
    }

    notifyListeners();
  }

  bool _validatePreimage(TradePreimage preimage) {
    bool isValid = true;

    if (preimage.error != null) {
      isValid = false;
      _error = _getHumanPreimageError(preimage.error);
    } else {
      // check active coins
      for (CoinFee coinFee in preimage.totalFees) {
        final CoinBalance coinBalance =
            coinsBloc.getBalanceByAbbr(coinFee.coin);
        if (coinBalance == null) {
          isValid = false;
          _error =
              '${coinFee.coin} needs to be active in order to pay swap fees.'
              ' Please activate and try again.';
          break;
        }
      }

      // Do not reinterpret maker base_min_volume locally.
      // Its denomination depends on the best_orders orientation and older
      // mobile code can compare it against the opposite side of the pair.
      // trade_preimage and postBuy validate the actual KDF minimum safely.
    }

    if (isValid) _error = null;
    return isValid;
  }

  String _getHumanPreimageError(RpcError error) {
    String str;
    switch (error.type) {
      case RpcErrorType.NotSufficientBaseCoinBalance:
        str = '${error.data['coin']} balance is not sufficient'
            ' to pay fees';
        break;
      case RpcErrorType.NotSufficientBalance:
        str = '${error.data['coin']} balance is not sufficient for trade, '
            'Min required balance is '
            '${cutTrailingZeros(formatPrice(error.data['required']))}. '
            '${error.data['coin']}';
        break;
      case RpcErrorType.VolumeTooLow:
        str =
            'Min volume is ${cutTrailingZeros(formatPrice(error.data['threshold']))}.'
            ' ${error.data['coin']}';
        break;
      case RpcErrorType.Transport:
        str =
            "Trade can't be started, Please check if you have enough funds for gas."
            ' Error: ${error.data}';
        break;
      default:
        str = error.message ?? 'Something went wrong, please try again.';
    }

    return str;
  }

  Future<void> _updateMaxTakerVolume() async {
    _error = null;

    if (_sellCoin == null) {
      _maxTakerVolume = null;
      return;
    }

    try {
      _maxTakerVolume =
          await MM.getMaxTakerVolume(GetMaxTakerVolume(coin: _sellCoin));

      if (_maxTakerVolume.toDouble() == 0) {
        _error = '$_sellCoin balance is not sufficient for trade';
      }
    } catch (e) {
      _maxTakerVolume = null;
    }

    notifyListeners();
  }
}
