/// A class representing the data returned by a successful Moamalat transaction.
class MoamalatTransactionSuccess {
  const MoamalatTransactionSuccess({
    this.txnDate,
    this.systemReference,
    this.networkReference,
    this.merchantReference,
    this.amount,
    this.currency,
    this.paidThrough,
    this.payerAccount,
    this.payerName,
    this.providerSchemeName,
    this.secureHash,
    this.displayData,
    this.tokenCustomerId,
    this.tokenCard,
  });

  final String? txnDate;
  final String? systemReference;
  final String? networkReference;
  final String? merchantReference;
  final double? amount;
  final String? currency;
  final String? paidThrough;
  final String? payerAccount;
  final String? payerName;
  final String? providerSchemeName;
  final String? secureHash;
  final String? displayData;
  final String? tokenCustomerId;
  final String? tokenCard;

  factory MoamalatTransactionSuccess.fromJson(Map<String, dynamic> json) {
    return MoamalatTransactionSuccess(
      txnDate: json['TxnDate'],
      systemReference: json['SystemReference'],
      networkReference: json['NetworkReference'],
      merchantReference: json['MerchantReference'],
      amount: double.parse(json['Amount']),
      currency: json['Currency'],
      paidThrough: json['PaidThrough'],
      payerAccount: json['PayerAccount'],
      payerName: json['PayerName'],
      providerSchemeName: json['ProviderSchemeName'],
      secureHash: json['SecureHash'],
      displayData: json['DisplayData'],
      tokenCustomerId: json['TokenCustomerId'],
      tokenCard: json['TokenCard'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['TxnDate'] = txnDate;
    data['SystemReference'] = systemReference;
    data['NetworkReference'] = networkReference;
    data['MerchantReference'] = merchantReference;
    data['Amount'] = amount.toString();
    data['Currency'] = currency;
    data['PaidThrough'] = paidThrough;
    data['PayerAccount'] = payerAccount;
    data['PayerName'] = payerName;
    data['ProviderSchemeName'] = providerSchemeName;
    data['SecureHash'] = secureHash;
    data['DisplayData'] = displayData;
    data['TokenCustomerId'] = tokenCustomerId;
    data['TokenCard'] = tokenCard;
    return data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MoamalatTransactionSuccess &&
        other.txnDate == txnDate &&
        other.systemReference == systemReference &&
        other.networkReference == networkReference &&
        other.merchantReference == merchantReference &&
        other.amount == amount &&
        other.currency == currency &&
        other.paidThrough == paidThrough &&
        other.payerAccount == payerAccount &&
        other.payerName == payerName &&
        other.providerSchemeName == providerSchemeName &&
        other.secureHash == secureHash &&
        other.displayData == displayData &&
        other.tokenCustomerId == tokenCustomerId &&
        other.tokenCard == tokenCard;
  }

  @override
  int get hashCode {
    return txnDate.hashCode ^
        systemReference.hashCode ^
        networkReference.hashCode ^
        merchantReference.hashCode ^
        amount.hashCode ^
        currency.hashCode ^
        paidThrough.hashCode ^
        payerAccount.hashCode ^
        payerName.hashCode ^
        providerSchemeName.hashCode ^
        secureHash.hashCode ^
        displayData.hashCode ^
        tokenCustomerId.hashCode ^
        tokenCard.hashCode;
  }
}
