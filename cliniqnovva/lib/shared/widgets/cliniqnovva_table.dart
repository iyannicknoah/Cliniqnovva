import 'package:flutter/material.dart';

import '../../core/theme/theme_ext.dart';

/// The single table-header component — a row of semi-bold column labels
/// (2026-08-14, explicit user instruction: "semi-bold, not that hard bold" —
/// corrects the same day's earlier `w700` pass down to `w600`; was
/// regular-weight `appSubtext` before that), one per `Expanded` cell,
/// bracketed by hairline dividers above and below.
class CliniqnovvaTableHeader extends StatelessWidget {
  const CliniqnovvaTableHeader({
    super.key,
    required this.columns,
    this.lastColumnEndPadding = 0,
  });

  final List<String> columns;

  /// 2026-08-14, explicit user instruction — 50px of right padding on the
  /// Actions column specifically (the label here, and each row's action
  /// content in [CliniqnovvaTableRow] below), not the whole table/row. Pass
  /// 50 at every call site whose last column is an Actions column; leave at
  /// the 0 default everywhere else (e.g. a table whose last column is
  /// Status, which was never part of this instruction).
  final double lastColumnEndPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(height: 1, thickness: 1, color: context.appBorder),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(0, 20, 0, 20),
          child: Row(
            children: [
              for (var i = 0; i < columns.length; i++)
                Expanded(
                  child: Padding(
                    padding: i == columns.length - 1
                        ? EdgeInsetsDirectional.only(end: lastColumnEndPadding)
                        : EdgeInsets.zero,
                    child: Text(
                      columns[i],
                      // 2026-08-14, explicit user instruction — the last
                      // column (Actions/Status/whatever it is per screen)
                      // reads as flush against the table's right edge
                      // instead of sitting left-aligned with empty space
                      // trailing it, matching where its row content (a
                      // right-aligned action menu, badge, etc. — see
                      // CliniqnovvaTableRow below) actually sits.
                      textAlign: i == columns.length - 1
                          ? TextAlign.right
                          : TextAlign.left,
                      style: TextStyle(
                        color: context.appSubtext,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
  const CliniqnovvaTableRow({
    super.key,
    required this.cells,
    this.onTap,
    this.lastColumnEndPadding = 0,
  });

  final List<Widget> cells;
  final VoidCallback? onTap;

  /// Must match the [CliniqnovvaTableHeader.lastColumnEndPadding] passed
  /// alongside this row's header, so the Actions value lines up under the
  /// Actions label at the same 50px inset from the table's right edge.
  final double lastColumnEndPadding;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            // 2026-08-14, explicit user instruction — "increase the height
            // of row a little" on all tables (was 26 top/bottom).
            padding: const EdgeInsetsDirectional.fromSTEB(0, 32, 0, 32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < cells.length; i++)
                  Expanded(
                    // Last cell right-aligned to match the header above —
                    // see CliniqnovvaTableHeader.
                    child: i == cells.length - 1
                        ? Padding(
                            padding: EdgeInsetsDirectional.only(
                              end: lastColumnEndPadding,
                            ),
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: cells[i],
                            ),
                          )
                        : cells[i],
                  ),
              ].divideWith(const SizedBox(width: 20)),
            ),
          ),
          Divider(height: 1, thickness: 1, color: context.appBorder),
        ],
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
