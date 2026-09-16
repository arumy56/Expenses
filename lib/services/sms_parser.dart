import 'package:uuid/uuid.dart';

/// Specialized parser for Kenyan M-Pesa SMS confirmation messages.
/// Extracts transaction reference, amount, inflow/outlay direction,
/// recipient/sender description, and transaction date with zero cloud dependency.
class SmsParser {
  static const _uuid = Uuid();

  /// Parses an incoming SMS text and extracts key financial transaction metadata.
  /// Returns null if the SMS is not an M-Pesa transaction confirmation.
  static Map<String, dynamic>? parseMpesaSms(String messageBody) {
    final cleanBody = messageBody.trim();
    if (cleanBody.isEmpty) return null;

    final upper = cleanBody.toUpperCase();

    // Fast-fail check: Must contain M-Pesa or transaction confirmation indicators
    final hasMpesaKeyword = upper.contains('M-PESA') ||
        upper.contains('MPESA') ||
        upper.contains('SAFARICOM') ||
        upper.contains('CONFIRMED') ||
        ((upper.contains('SENT') ||
                upper.contains('PAID') ||
                upper.contains('RECEIVED')) &&
            (upper.contains('KSH') || upper.contains('KES')));

    if (!hasMpesaKeyword) {
      return null;
    }

    // 1. Extract Amount (handles Ksh1,500.00, Ksh 500.00, Ksh. 1,200.00, KES 200, KSh. 1,000, etc.)
    final amountRegex = RegExp(
      r'(?:Ksh|KES|KSh)\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );
    final amountMatch = amountRegex.firstMatch(cleanBody);
    if (amountMatch == null) {
      return null;
    }

    final rawAmountStr = amountMatch.group(1)?.replaceAll(',', '');
    final amount = double.tryParse(rawAmountStr ?? '');
    if (amount == null || amount <= 0) {
      return null;
    }

    // 2. Extract Transaction Code (e.g. QA45TY7890, SK12345678, QK71XXXXXX)
    final codeRegex =
        RegExp(r'\b([A-Z0-9]{8,12})\s+(?:Confirmed|confirmed)', caseSensitive: false);
    final codeMatch = codeRegex.firstMatch(cleanBody);
    final transactionCode = codeMatch?.group(1)?.toUpperCase() ?? '';
    final id = transactionCode.isNotEmpty
        ? 'mpesa_$transactionCode'
        : 'sms_${_uuid.v4().substring(0, 8)}';

    // 3. Determine Inflow vs Outflow
    final lower = cleanBody.toLowerCase();
    final bool isIncome;
    if (lower.contains('received') ||
        lower.contains('give you') ||
        lower.contains('transferred from') ||
        lower.contains('deposited')) {
      isIncome = true;
    } else {
      // All payments, send money, paybill, till, airtime, withdraw, transfers out are Outlays
      isIncome = false;
    }

    // 4. Extract Description / Party Name
    String description = '';

    if (isIncome) {
      // "You have received Ksh1,500.00 from JOHN DOE 0712345678 on 22/8/26"
      // "Ksh1,500.00 received from JOHN DOE on 22/8/26"
      // "transferred from Equity Bank..."
      final receivedRegex = RegExp(
        r'from\s+([^.]+?)(?:\s+on\s+\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}|\.\s*New|\.|$)',
        caseSensitive: false,
      );
      final match = receivedRegex.firstMatch(cleanBody);
      if (match != null && match.group(1) != null) {
        final sender = match.group(1)!.trim();
        description = sender.isNotEmpty ? sender : 'Received Funds';
      } else {
        description = 'Received Funds';
      }
    } else {
      // --- Outflow Extraction Handlers ---
      if (lower.contains('paid')) {
        // "Ksh2,450.00 paid to QUICKMART SUPERMARKET on 22/8/26"
        // "You have paid Ksh 3,000.00 to KPLC PREPAID for account 123 on 22/8/26"
        final paidRegex = RegExp(
          r'(?:paid\s+to|paid\s+(?:Ksh|KES|KSh)?\.?\s*[\d,\.]+\s+to)\s+([^.]+?)(?:\s+for\s+account|\s+on\s+\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}|\.\s*New|\.|$)',
          caseSensitive: false,
        );
        final match = paidRegex.firstMatch(cleanBody);
        if (match != null && match.group(1) != null) {
          var merchant = match.group(1)!.trim();
          description = merchant.isNotEmpty ? merchant : 'Merchant Payment';
        } else {
          description = 'Merchant Payment';
        }
      } else if (lower.contains('sent to') ||
          lower.contains('transferred to') ||
          lower.contains('sent')) {
        // Matches:
        // "Ksh1,200.00 sent to JANE DOE 0722334455 on 22/8/26"
        // "You have sent Ksh1,200.00 to JANE DOE 0722334455 on 22/8/26"
        // "Ksh. 500.00 sent to 0712345678 - JANE DOE on 22/8/26"
        // "transferred to Airtel Money 0733..."
        final sentRegex = RegExp(
          r'(?:sent\s+to|transferred\s+to|sent\s+(?:Ksh|KES|KSh)?\.?\s*[\d,\.]+\s+to)\s+([^.]+?)(?:\s+on\s+\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}|\.\s*New|\.|$)',
          caseSensitive: false,
        );
        final match = sentRegex.firstMatch(cleanBody);
        if (match != null && match.group(1) != null) {
          final recipient = match.group(1)!.trim();
          description = recipient.isNotEmpty ? recipient : 'Sent Money';
        } else {
          description = 'Sent Money';
        }
      } else if (lower.contains('withdrawn')) {
        // "Ksh5,000.00 withdrawn from 123456 - AGENT NAME on 22/8/26"
        final withdrawRegex = RegExp(
          r'withdrawn from\s+([^.]+?)(?:\s+on\s+\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}|\.\s*New|\.|$)',
          caseSensitive: false,
        );
        final match = withdrawRegex.firstMatch(cleanBody);
        if (match != null && match.group(1) != null) {
          final agent = match.group(1)!.trim();
          description = agent.isNotEmpty ? 'ATM/Agent: $agent' : 'Cash Withdrawal';
        } else {
          description = 'Cash Withdrawal';
        }
      } else if (lower.contains('bought') || lower.contains('airtime')) {
        description = 'Airtime Purchase';
      } else if (lower.contains('fuliza')) {
        description = 'Fuliza M-Pesa';
      } else {
        description = 'Sent Money';
      }
    }

    // Clean up description if any extra periods or whitespace
    description = description.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (description.endsWith('.')) {
      description = description.substring(0, description.length - 1).trim();
    }

    // 5. Extract Date
    String formattedDate = '';
    final dateRegex = RegExp(
      r'on\s+(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})',
      caseSensitive: false,
    );
    final dateMatch = dateRegex.firstMatch(cleanBody);
    if (dateMatch != null) {
      final dayStr = dateMatch.group(1)!.padLeft(2, '0');
      final monthStr = dateMatch.group(2)!.padLeft(2, '0');
      var yearStr = dateMatch.group(3)!;
      if (yearStr.length == 2) {
        yearStr = '20$yearStr';
      }
      formattedDate = '$yearStr-$monthStr-$dayStr';
    } else {
      final now = DateTime.now();
      formattedDate =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }

    return {
      'id': id,
      'referenceCode': transactionCode,
      'amount': amount,
      'isIncome': isIncome,
      'description': description,
      'date': formattedDate,
      'rawMessage': cleanBody,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}
