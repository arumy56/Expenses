import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/models/expense.dart';

class ExportEngine {
  /// Converts a list of expenses into a standard RFC-compliant CSV string
  static String generateCsvString(List<Expense> expenses) {
    final buffer = StringBuffer();
    // Standard Header
    buffer.writeln('ID,Date,Type,Amount (KSh),Category,Description');

    for (final item in expenses) {
      final id = _escapeCsvField(item.id);
      final date = _escapeCsvField(item.date);
      final type = item.isIncome ? 'Inflow' : 'Outlay';
      final amount = item.amount.toStringAsFixed(2);
      final category = _escapeCsvField(item.category);
      final description = _escapeCsvField(item.description);

      buffer.writeln('$id,$date,$type,$amount,$category,$description');
    }

    return buffer.toString();
  }

  /// Exports the transaction dataset into a local CSV file and invokes the native share sheet
  static Future<File> exportToCsv(List<Expense> expenses) async {
    final csvContent = generateCsvString(expenses);

    // Query application documents / downloads directory
    Directory directory;
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        directory = downloads;
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
    } catch (_) {
      directory = await getApplicationDocumentsDirectory();
    }

    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final fileName = 'vault_cashflow_export_$timestamp.csv';
    final filePath = '${directory.path}/$fileName';

    final file = File(filePath);
    await file.writeAsString(csvContent);

    // Invoke native sharing sheet to make it visible to public storage & external apps
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Vault Financial Data Matrix Export',
      );
    } catch (_) {
      // Graceful fallback if share intent is cancelled or not supported in test environment
    }

    return file;
  }

  static String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      final escaped = field.replaceAll('"', '""');
      return '"$escaped"';
    }
    return field;
  }
}
