<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

A Flutter package that integrates the Moamalat payment gateway for secure payment processing.

## Features

- Secure payment processing through Moamalat gateway
- Support for both test and production environments
- Real-time payment status callbacks
- Automatic WebView cleanup and resource management
- Customizable loading and error UI builders
- Smooth navigation transitions

## Getting started

Add `moamalat_pay` to your `pubspec.yaml` dependencies.

## Usage

Here is a complete example of how to use the `MoamalatPayment` widget:

```dart
import 'package:flutter/material.dart';
import 'package:moamalat_pay/moamalat_pay.dart';

class PaymentPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moamalat Payment')),
      body: MoamalatPayment(
        merchantId: "your_merchant_id",
        merchantReference: "unique_transaction_ref_${DateTime.now().millisecondsSinceEpoch}",
        terminalId: "your_terminal_id",
        amount: "10000", // Amount in smallest currency unit (e.g., 10000 = 10.000 LYD)
        merchantSecretKey: "your_secret_key",
        isTest: true, // Set to true for testing
        loadingBuilder: (context, progress) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(value: progress),
              const SizedBox(height: 16),
              const Text('Initializing Payment Gateway...'),
            ],
          ),
        ),
        errorBuilder: (context, retry) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Failed to load payment gateway.'),
              ElevatedButton(
                onPressed: retry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        onCompleteSucsses: (transaction) {
          // Handle successful payment
          print('Payment successful: ${transaction.systemReference}');
        },
        onError: (error) {
          // Handle payment error
          print('Payment failed: ${error.error}');
        },
      ),
    );
  }
}
```

## Additional information

- All monetary amounts should be in the smallest currency unit (dirham for LYD). For example, 1 Libyan Dinar (LYD) = 1000 Libyan Dirham.
- The `merchantSecretKey` should be stored securely.
- Set `isTest` to `false` for production releases.
