import 'dart:convert';
import 'dart:developer';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:moamalat_pay/src/domain/moamalat_transaction_failed.dart';
import 'package:moamalat_pay/src/domain/moamalat_transaction_success.dart';

/// A Flutter widget that integrates Moamalat payment gateway for secure payment processing.
///
/// This widget provides a complete payment solution using Moamalat's payment gateway,
/// handling the entire payment flow from initialization to completion or error handling.
///
/// ## Features
/// - Secure payment processing through Moamalat gateway
/// - Support for both test and production environments
/// - Real-time payment status callbacks
/// - Automatic WebView cleanup and resource management
/// - Customizable loading UI builder
/// - Smooth navigation transitions
///
/// ## Usage
/// ```dart
/// MoamalatPayment(
///   merchantId: "your_merchant_id",
///   merchantReference: "unique_transaction_ref",
///   terminalId: "your_terminal_id",
///   amount: "1000", // Amount in smallest currency unit (dirham)
///   merchantSecretKey: "your_secret_key",
///   isTest: false, // Set to true for testing
///   loadingBuilder: (context, progress) => Center(
///     child: CircularProgressIndicator(value: progress),
///   ),
///   errorBuilder: (context, retry) => Center(
///     child: ElevatedButton(
///       onPressed: retry,
///       child: const Text('Retry'),
///     ),
///   ),
///   onCompleteSucsses: (transaction) {
///     // Handle successful payment
///     print('Payment successful: ${transaction.systemReference}');
///   },
///   onError: (error) {
///     // Handle payment error
///     print('Payment failed: ${error.error}');
///   },
/// )
/// ```
///
/// ## Important Notes
/// - All monetary amounts should be in the smallest currency unit (dirham for LYD)
/// - 1 Libyan Dinar (LYD) = 1000 Libyan Dirham
/// - The merchant secret key should be stored securely and never exposed in client code
/// - Test mode should only be used during development
class MoamalatPayment extends StatefulWidget {
  /// Custom builder for the loading widget displayed while the payment gateway initializes.
  ///
  /// Receives the build context and current loading progress (0.0 to 1.0).
  /// This allows fully customizing the UI during initialization.
  /// If not provided, no loading UI will be displayed.
  final Widget Function(BuildContext context, double progress)? loadingBuilder;

  /// Custom builder for the error widget displayed when the payment gateway fails to load.
  ///
  /// Receives the build context and a [VoidCallback] to retry loading.
  /// This allows fully customizing the error UI and providing a retry mechanism.
  /// If not provided, no error UI will be displayed.
  final Widget Function(BuildContext context, VoidCallback retry)? errorBuilder;

  final DateTime timeStamp;

  /// Determines the environment for payment processing.
  ///
  /// - `true`: Uses test environment (tnpg.moamalat.net:6006)
  /// - `false`: Uses production environment (npg.moamalat.net:6006)
  ///
  /// **Warning**: Always set to `false` for production releases.
  final bool isTest;

  /// Unique identifier for the merchant account.
  ///
  /// This is provided by Moamalat during merchant registration.
  /// Must be a valid merchant ID registered with Moamalat.
  ///
  /// Example: `"10038160862"`
  final String merchantId;

  /// Unique reference for this specific transaction.
  ///
  /// Should be unique for each payment attempt to avoid conflicts.
  /// Used for transaction tracking and reconciliation.
  ///
  /// Example: `"ORDER_${DateTime.now().millisecondsSinceEpoch}"`
  final String merchantReference;

  /// Terminal identifier associated with the merchant account.
  ///
  /// Provided by Moamalat during terminal setup.
  /// Links the transaction to a specific payment terminal.
  ///
  /// Example: `"93082651"`
  final String terminalId;

  /// Transaction amount in the smallest currency unit.
  ///
  /// For LYD (Libyan Dinar):
  /// - 1 LYD = 1000 dirham
  /// - For 10.500 LYD, pass "10500"
  /// - For 1 LYD, pass "1000"
  ///
  /// **Important**: Must be a string representation of an integer.
  final String amount;

  /// Merchant's secret key for transaction signing.
  ///
  /// **Security Warning**: This key should be:
  /// - Stored securely (preferably server-side)
  /// - Never committed to version control
  /// - Rotated regularly for security
  ///
  /// Used to generate HMAC-SHA256 signatures for transaction verification.
  final String merchantSecretKey;

  /// Callback invoked when payment completes successfully.
  ///
  /// Receives a [MoamalatTransactionSuccess] object containing:
  /// - System reference number
  /// - Network reference
  /// - Transaction details
  /// - Payment method information
  ///
  /// Example:
  /// ```dart
  /// onCompleteSucsses: (transaction) {
  ///   print('Payment completed: ${transaction.systemReference}');
  ///   // Navigate to success page
  ///   Navigator.pushReplacement(context, SuccessPage(transaction));
  /// }
  /// ```
  final void Function(MoamalatTransactionSuccess transactionSucsses) onCompleteSucsses;

  /// Callback invoked when payment fails or encounters an error.
  ///
  /// Receives a [MoamalatTransactionFailed] object containing:
  /// - Error message
  /// - Transaction details
  /// - Failure reason
  ///
  /// Example:
  /// ```dart
  /// onError: (error) {
  ///   print('Payment failed: ${error.error}');
  ///   showDialog(context: context, builder: (_) => ErrorDialog(error));
  /// }
  /// ```
  final void Function(MoamalatTransactionFailed paymentError) onError;

  /// Creates a new MoamalatPayment widget.
  ///
  /// All required parameters must be provided for proper payment processing.
  /// The widget will automatically handle the payment flow and invoke the
  /// appropriate callback based on the transaction result.
  ///
  /// **Important**: Ensure all required string parameters are not empty.
  MoamalatPayment({
    super.key,
    required this.merchantId,
    required this.merchantReference,
    required this.terminalId,
    required this.amount,
    required this.merchantSecretKey,
    required this.onCompleteSucsses,
    required this.onError,
    this.loadingBuilder,
    this.errorBuilder,
    this.isTest = false,
    DateTime? timeStamp,
  }) : timeStamp = timeStamp ?? DateTime.now();

  @override
  State<MoamalatPayment> createState() => _MoamalatPaymentState();
}

/// Private state class for [MoamalatPayment] widget.
///
/// Manages the WebView lifecycle, payment flow, and transaction processing.
class _MoamalatPaymentState extends State<MoamalatPayment> {
  double _progress = 0;

  /// WebView controller for managing the payment interface.
  InAppWebViewController? _controller;

  /// Generates current timestamp in Unix epoch format for transaction identification.
  ///
  /// Returns a string representation of seconds since Unix epoch.
  /// This timestamp is used for transaction tracking and security hashing.
  ///
  /// Example return value: `"1640995200"` (represents 2022-01-01 00:00:00 UTC)
  String get _timeStamp => (widget.timeStamp.millisecondsSinceEpoch ~/ 1000).toString();

  /// Payment gateway URL (test or production).
  late final _gatewayUrl = widget.isTest
      ? 'https://tnpg.moamalat.net:6006/js/lightbox.js'
      : 'https://npg.moamalat.net:6006/js/lightbox.js';

  /// Loading state indicator for the payment interface.
  bool _isLoading = true;

  /// Error state indicator for the payment interface.
  bool _isError = false;

  /// Visibility state for smooth navigation transitions.
  bool _isWebViewVisible = true;

  /// Retry loading the payment gateway.
  void _retry() {
    setState(() {
      _isError = false;
      _isLoading = true;
      _progress = 0;
    });
    _controller?.reload();
  }

  /// WebView configuration optimized for payment processing.
  ///
  /// Key settings:
  /// - `useHybridComposition`: Ensures proper rendering on Android
  /// - `clearCache`: Prevents cached payment data
  /// - `cacheEnabled`: Disabled for security
  /// - `javaScriptEnabled`: Required for payment gateway
  /// - `domStorageEnabled`: Enables local storage for payment flow
  final _options = InAppWebViewSettings(
    useHybridComposition: true, // Great for Android rendering
    cacheEnabled: false, // Prevents new caching
    javaScriptEnabled: true, // Essential for payment gateways
    domStorageEnabled: true, // Essential for payment gateways
  );

  /// Initializes the payment widget state.
  ///
  /// Sets up the payment environment and generates transaction timestamp.
  @override
  void initState() {
    super.initState();
    InAppWebViewController.clearAllCache();
  }

  /// Cleans up WebView resources when the widget is disposed.
  ///
  /// Ensures proper cleanup to prevent memory leaks and security issues.
  /// Called automatically when the widget is removed from the widget tree.
  @override
  void dispose() {
    _controller?.stopLoading();
    _controller?.dispose();
    super.dispose();
  }

  /// Encodes payment parameters into a query string format for hash calculation.
  ///
  /// Creates a standardized string containing all transaction parameters
  /// in the format required by Moamalat's security specification.
  ///
  /// Returns a string in format:
  /// `"Amount=1000&DateTimeLocalTrxn=1640995200&MerchantId=123&MerchantReference=REF&TerminalId=456"`
  ///
  /// This encoded string is used as input for HMAC-SHA256 signature generation.
  String _encodeData() {
    return 'Amount=${widget.amount}&DateTimeLocalTrxn=$_timeStamp&MerchantId=${widget.merchantId}&MerchantReference=${widget.merchantReference}&TerminalId=${widget.terminalId}';
  }

  /// Generates HMAC-SHA256 signature for transaction security.
  ///
  /// Creates a cryptographic signature using the merchant's secret key
  /// and encoded transaction data to ensure payment integrity.
  ///
  /// Process:
  /// 1. Converts hex-encoded secret key to bytes (or uses UTF-8 if not hex)
  /// 2. Encodes transaction data using [_encodeData]
  /// 3. Generates HMAC-SHA256 hash
  /// 4. Returns uppercase hex string
  ///
  /// Returns: Uppercase hex string (e.g., "A1B2C3D4E5F6...")
  ///
  /// **Security Note**: This signature prevents tampering and ensures
  /// the payment request originates from an authorized merchant.
  String _hash() {
    List<int> keyBytes = [];
    String hexKey = widget.merchantSecretKey;

    try {
      // Check if the key is a valid hex string
      if (_isValidHexString(hexKey)) {
        // Convert hex key to bytes
        for (int i = 0; i < hexKey.length; i += 2) {
          String hexPair = hexKey.substring(i, i + 2);
          keyBytes.add(int.parse(hexPair, radix: 16));
        }
      } else {
        // If not hex, use UTF-8 encoding of the key
        keyBytes = utf8.encode(hexKey);
      }
    } catch (e) {
      // Fallback: use UTF-8 encoding if hex parsing fails
      keyBytes = utf8.encode(hexKey);
    }

    String msg = _encodeData();
    var hmac = Hmac(sha256, keyBytes);
    var hash = hmac.convert(utf8.encode(msg)).toString().toUpperCase();
    return hash;
  }

  /// Validates if a string is a valid hexadecimal string.
  ///
  /// Returns true if the string contains only valid hex characters (0-9, A-F, a-f)
  /// and has even length (required for proper byte conversion).
  bool _isValidHexString(String str) {
    // Must have even length for proper byte conversion
    if (str.length % 2 != 0) return false;

    // Check if all characters are valid hex
    final hexRegex = RegExp(r'^[0-9A-Fa-f]+$');
    return hexRegex.hasMatch(str);
  }

  /// Converts a hexadecimal string to ASCII text.
  ///
  /// Takes a hex-encoded string and converts each pair of hex digits
  /// to their corresponding ASCII character.
  ///
  /// Example:
  /// - Input: `"48656C6C6F"`
  /// - Output: `"Hello"`
  ///
  /// **Note**: Currently unused in the payment flow but kept for compatibility.
  ///
  /// [hex] The hexadecimal string to convert (must have even length)
  /// Returns the decoded ASCII string
  String hex2a(String hex) {
    var str = '';
    var i = 0;
    while (i < hex.length) {
      str += String.fromCharCode(int.parse(hex.substring(i, i + 2), radix: 16));
      i += 2;
    }
    return str;
  }

  /// Builds the payment interface using an embedded WebView.
  ///
  /// Creates a full-screen WebView that loads the Moamalat payment gateway
  /// with proper navigation handling and loading states.
  ///
  /// Features:
  /// - Smooth navigation transitions with [PopScope]
  /// - Loading indicator with customizable message
  /// - Automatic WebView cleanup on navigation
  /// - Responsive payment form interface
  ///
  /// The WebView loads an HTML page that:
  /// 1. Includes the Moamalat Lightbox JavaScript library
  /// 2. Configures payment parameters and callbacks
  /// 3. Displays the payment form interface
  /// 4. Handles success/error/cancel scenarios
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Hide the WebView immediately to prevent visual glitch
          setState(() {
            _isWebViewVisible = false;
          });
          _controller?.stopLoading();
        }
      },
      child: Stack(
        children: [
          Visibility(
            visible: _isWebViewVisible,
            child: InAppWebView(
              initialData: InAppWebViewInitialData(
                data:
                    '''
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Load file or HTML string example</title>
    <style>
      html, body {
      width: 100%;
      height: 100%;
      margin: 0;
      padding: 0;
      overflow: hidden;
      }
      #lightbox {
      width: 100%;
      height: 100%;
      position: absolute;
      top: 0;
      left: 0;
      }
    </style>
    </head>
    
    <body>
    <div id="lightbox">
    
      <script src="$_gatewayUrl"></script>
        <script>
        Lightbox.Checkout.configure = {
          MID: '${widget.merchantId}',
          TID: '${widget.terminalId}',
          AmountTrxn: '${widget.amount}',
          MerchantReference: '${widget.merchantReference}',
          TrxDateTime: '$_timeStamp',
          SecureHash: '${_hash()}',
          completeCallback: function (data) {
            window.flutter_inappwebview.callHandler('sucsses', JSON.stringify(data));
            window.complete.postMessage('Payment completed successfully');
          },
          errorCallback: function (error) {
            window.flutter_inappwebview.callHandler('error', JSON.stringify(error));
            console.log()
          },
          cancelCallback: function () {
            window.cancel.postMessage('Payment cancelled');
          }
        };
      
        Lightbox.Checkout.showLightbox();
        </script>
      </div>
      </body>
      </html>
        ''',
              ),
              initialSettings: _options,
              onWebViewCreated: (controller) {
                _controller = controller;

                // Clear any existing cache and data

                controller.addJavaScriptHandler(
                  handlerName: 'error',
                  callback: (args) {
                    handleError(args[0]);
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: 'sucsses',
                  callback: (args) {
                    log("This is args received $args");
                    handleComplete(args[0]);
                  },
                );
              },
              onLoadStart: (controller, url) {
                setState(() {
                  _isLoading = true;
                });
              },
              onLoadStop: (controller, url) {
                setState(() {
                  _isLoading = false;
                });
              },
              onReceivedError: (controller, request, errorResponse) {
                setState(() {
                  _isLoading = false;
                  _isError = true;
                });
              },
              onReceivedHttpError: (controller, request, errorResponse) {
                setState(() {
                  _isLoading = false;
                  _isError = true;
                });
              },
              onProgressChanged: (controller, progress) {
                setState(() {
                  _progress = progress / 100.0;
                });
              },
              onLoadResource: (controller, resource) {},
            ),
          ),
          // Loading indicator overlay
          if (_isLoading && widget.loadingBuilder != null)
            Positioned.fill(child: widget.loadingBuilder!(context, _progress)),

          // Error indicator overlay
          if (_isError && widget.errorBuilder != null)
            Positioned.fill(child: widget.errorBuilder!(context, _retry)),
        ],
      ),
    );
  }

  /// Handles successful payment completion from the WebView.
  ///
  /// Parses the JSON response from Moamalat's payment gateway and creates
  /// a [MoamalatTransactionSuccess] object with all transaction details.
  ///
  /// **Response Data Includes:**
  /// - Transaction references (system, network, merchant)
  /// - Payment amount and currency
  /// - Payer information and payment method
  /// - Security hash for verification
  /// - Tokenization data (if applicable)
  ///
  /// [message] JSON string containing transaction success data
  /// Returns [MoamalatTransactionSuccess] object with parsed transaction details
  ///
  /// **Note**: Automatically invokes [onCompleteSucsses] callback
  MoamalatTransactionSuccess handleComplete(String message) {
    Map<String, dynamic> successObject = json.decode(message);

    // Parse the response into a `Transaction` instance
    MoamalatTransactionSuccess transaction = MoamalatTransactionSuccess(
      txnDate: successObject['TxnDate'],
      systemReference: successObject['SystemReference'],
      networkReference: successObject['NetworkReference'],
      merchantReference: successObject['MerchantReference'],
      amount: double.parse(successObject['Amount']),
      currency: successObject['Currency'],
      paidThrough: successObject['PaidThrough'],
      payerAccount: successObject['PayerAccount'],
      payerName: successObject['PayerName'],
      providerSchemeName: successObject['ProviderSchemeName'],
      secureHash: successObject['SecureHash'],
      displayData: successObject['DisplayData'],
      tokenCustomerId: successObject['TokenCustomerId'],
      tokenCard: successObject['TokenCard'],
    );

    widget.onCompleteSucsses(transaction);

    return transaction;
  }

  /// Handles payment errors and failures from the WebView.
  ///
  /// Parses error responses from Moamalat's payment gateway and creates
  /// a [MoamalatTransactionFailed] object with failure details.
  ///
  /// **Error Data Includes:**
  /// - Error message describing the failure
  /// - Transaction amount and reference
  /// - Timestamp of the failed transaction
  /// - Security hash for verification
  ///
  /// **Common Error Scenarios:**
  /// - Invalid payment credentials
  /// - Insufficient funds
  /// - Network connectivity issues
  /// - Payment gateway timeouts
  /// - User cancellation
  ///
  /// [consoleMessage] JSON string containing error details from payment gateway
  /// Returns [MoamalatTransactionFailed] object with parsed error data, or null if parsing fails
  ///
  /// **Note**: Automatically invokes [onError] callback when error is successfully parsed
  MoamalatTransactionFailed? handleError(String consoleMessage) {
    try {
      // Parse the JSON error response
      Map<String, dynamic> errorObject = json.decode(consoleMessage);

      // Extract error details from the response
      String errorMessage = errorObject['error'];
      String amount = errorObject['Amount'];
      String merchantReference = errorObject['MerchantReferenece'];
      String dateTimeLocalTrxn = errorObject['DateTimeLocalTrxn'];
      String secureHash = errorObject['SecureHash'];

      // Create PaymentError instance with parsed data
      MoamalatTransactionFailed paymentError = MoamalatTransactionFailed(
        error: errorMessage,
        amount: amount,
        merchantReference: merchantReference,
        dateTimeLocalTrxn: dateTimeLocalTrxn,
        secureHash: secureHash,
      );

      // Notify the parent widget of the error
      widget.onError(paymentError);

      return paymentError;
    } catch (e) {
      // Return null if JSON parsing fails
      // This allows the calling code to handle malformed error responses
      return null;
    }
  }
}
