import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';

/// Builds a CSV string from [headers] + [rows] (values already stringified
/// by the caller) — commas/quotes/newlines inside a cell are escaped per
/// RFC 4180.
String buildCsv(List<String> headers, List<List<String>> rows) {
  String cell(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  final lines = [headers, ...rows].map((row) => row.map(cell).join(','));
  return lines.join('\r\n');
}

/// Triggers a CSV "download" in the browser — a `data:text/csv` URI opened
/// via [launchUrl]. No `dart:html`/blob plumbing and no extra package: this
/// reuses `url_launcher`, already a dependency. Chrome/Edge don't render
/// `text/csv` inline, so navigating straight to the data URI downloads it;
/// the browser picks a generic filename rather than [suggestedName] (data
/// URIs have no `download`-attribute equivalent for a direct navigation) —
/// an accepted tradeoff for a Part 14-scope export, not a full save-dialog
/// integration.
Future<void> downloadCsv(String csvContent) async {
  final uri = Uri.dataFromString(
    csvContent,
    mimeType: 'text/csv',
    encoding: utf8,
  );
  await launchUrl(uri, webOnlyWindowName: '_blank');
}
