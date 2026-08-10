# Testing

## Automated validation

```sh
flutter test test/simple_dex_order_contract_test.dart
flutter build apk --debug
unzip -t build/app/outputs/flutter-apk/app-debug.apk
```

## Manual wallet checklist

- Create and import a test wallet
- Lock and unlock using PIN
- Activate representative assets and verify balances
- Receive and send small transactions
- Verify transaction history and log export
- Confirm state after Android background and resume

## Manual DEX checklist

- Confirm external and own orders appear correctly
- Test Simple and Advanced modes with small amounts
- Verify selected price, minimum, maximum, spend, and receive values
- Confirm fixed-size orders do not round below maker minimums
- Confirm a selected taker order starts rather than expiring
- Monitor payment, confirmations, completion, balances, and history

Successful development tests covered multiple small-value UTXO swaps involving Litecoin Cash SegWit and representative Litecoin, Syscoin, Pandacoin, MonaCoin, and VerusCoin paths. This does not guarantee future peer, asset, server, or order availability.
