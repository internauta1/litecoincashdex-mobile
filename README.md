# Litecoin Cash DEX Mobile

<p align="center">
  <img src="assets/branding/logo_app.png" alt="Litecoin Cash DEX Mobile logo" width="150">
</p>

Community-maintained, non-custodial Litecoin Cash wallet and decentralized exchange for Android.

- Website: [litecoincash.com.br](https://litecoincash.com.br)
- Repository: [internauta1/litecoincashdex-mobile](https://github.com/internauta1/litecoincashdex-mobile)
- Downloads: [GitHub Releases](https://github.com/internauta1/litecoincashdex-mobile/releases)

## Status

This project is an independent Litecoin Cash adaptation of Komodo Wallet Mobile. The Android application has been manually tested for wallet creation and import, coin activation, transfers, market data, orderbook access, and atomic swaps through the Simple and Advanced DEX modes.

Android is the currently tested platform. The inherited iOS source is included but has not been validated for this release.

This is experimental cryptocurrency software. Use only amounts you are prepared to lose and keep an offline backup of your recovery phrase.

## Features

- Non-custodial multi-coin wallet
- Litecoin Cash and Litecoin Cash SegWit support
- Peer-to-peer atomic swaps
- Simple and Advanced DEX interfaces
- Exact rational order-volume handling
- Electrum-based UTXO connectivity
- DEX orderbook and active-swap monitoring
- Fiat-price fallback providers
- Android PIN and biometric protection where supported
- Exportable diagnostic logs

## Safety

- Never share seed phrases, private keys, PINs, passwords, or wallet databases.
- Verify addresses, amounts, prices, and fees before confirming.
- Keep sufficient native coin balance for blockchain fees.
- Atomic swaps depend on peer, Electrum, blockchain, and network availability.
- Keep the application connected while a swap is active.
- Debug APKs are for testing and are not production releases.
- Verify the SHA-256 checksum of every downloaded APK.

See [SECURITY.md](SECURITY.md) for additional guidance.

## Building and testing

See [docs/BUILDING.md](docs/BUILDING.md) and [docs/TESTING.md](docs/TESTING.md).

Basic validation:

```sh
flutter pub get
flutter test test/simple_dex_order_contract_test.dart
flutter build apk --debug
```

Signing keys, KDF binaries, APK files, wallet data, and credentials must never be committed.

## Upstream and credits

This project is based on:

- [Komodo Wallet Mobile](https://github.com/KomodoPlatform/atomicdex-mobile)
- [Komodo DeFi Framework](https://github.com/KomodoPlatform/komodo-defi-framework)
- [Komodo Platform coin configuration](https://github.com/KomodoPlatform/coins)

We thank the Komodo developers, contributors, designers, translators, and testers whose open-source work made this community adaptation possible. See [CREDITS.md](CREDITS.md) for complete attribution.

This is an independent community project. It is not an official Komodo Platform product and is not endorsed by or affiliated with Komodo Platform.

## License

The inherited source is distributed under the MIT License. The original [COPYING](COPYING) file is preserved. Third-party dependencies, artwork, names, and trademarks remain subject to their respective licenses and ownership.
