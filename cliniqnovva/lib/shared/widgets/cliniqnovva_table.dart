import 'package:flutter/material.dart';

import '../../core/theme/theme_ext.dart';

/// The single table-header component — a row of secondaryText column labels
/// (one per `Expanded` cell), bracketed by hairline dividers above and
/// below, matching the reference design language's table pattern exactly.
class CliniqnovvaTableHeader extends StatelessWidget {
  const CliniqnovvaTableHeader({super.key, required this.columns});

  final List<String> columns;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(height: 1, thickness: 1, color: context.appBorder),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(0, 20, 0, 20),
          child: Row(
            children: [
              for (final column in columns)
                Expanded(
                  child: Text(
                    column,
                    style: TextStyle(color: context.appSubtext),
                  ),
                ),
            ].divideWith(const SizedBox(width: 20)),
          ),
        ),
        Divider(height: 1, thickness: 1, color: context.appBorder),
      ],
    );
  }
}

/// The single table-row component — one `Expanded` cell per entry, tappable,
/// same column rhythm as [CliniqnovvaTableHeader]. Pass an [AvatarWidget] +
/// name inside the first cell for "table row with image" layouts, plain
/// `Text`/[StatusBadge] for the rest.
class CliniqnovvaTableRow extends StatelessWidget {
  const CliniqnovvaTableRow({super.key, required this.cells, this.onTap});

  final List<Widget> cells;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(0, 16, 0, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final cell in cells) Expanded(child: cell),
          ].divideWith(const SizedBox(width: 20)),
        ),
      ),
    );
  }
}

extension _DivideWidgets on List<Widget> {
  List<Widget> divideWith(Widget separator) {
    if (isEmpty) return this;
    final result = <Widget>[];
    for (var i = 0; i < length; i++) {
      if (i > 0) result.add(separator);
      result.add(this[i]);
    }
    return result;
  }
}
