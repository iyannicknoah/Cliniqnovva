import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_ext.dart';
import 'app_icon.dart';

/// One option in an [AppSelect].
class AppSelectOption {
  const AppSelectOption({required this.value, required this.label});

  final String value;
  final String label;
}

/// The standard dropdown for this app (2026-08-14, explicit user
/// instruction — "look how the dropdowns in smart feed are designed and
/// apply that... they are the dialog that pops up with search on top and
/// have radius on their border... other dropdowns also must have search").
/// Ported from the Smart Feed Rwanda reference's `Select.tsx`: a CLOSED
/// trigger field (selected label + a chevron that rotates open) rather than
/// an always-editable text field — tapping it opens a floating panel
/// (`AppTheme.cardRadius`, bordered, shadowed — same floating-popover
/// convention `cliniqnovva_sidebar.dart`'s profile menu already uses) with
/// a dedicated search box at the TOP and a scrollable, checkmark-annotated
/// option list below. Built on the same `OverlayEntry` +
/// `CompositedTransformFollower`/`Target` mechanism as that profile menu —
/// not `DropdownButtonFormField` (no search box, no border-radius on its
/// native popup) and not [SearchableDropdown] (an always-editable
/// type-to-filter text field, a different interaction model from the
/// reference's closed-button-then-popup pattern).
class AppSelect extends StatefulWidget {
  const AppSelect({
    super.key,
    this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint = 'Select…',
    this.searchHint = 'Search…',
    this.enabled = true,
  });

  final String? label;
  final String? value;
  final List<AppSelectOption> options;
  final ValueChanged<String?> onChanged;
  final String hint;
  final String searchHint;

  /// Set false for a "changing this isn't allowed right now" case (e.g. a
  /// staff role once the account already exists) — greys the trigger out
  /// and blocks opening the panel, same intent as passing `onChanged: null`
  /// to a `DropdownButtonFormField` (not directly possible here since
  /// [onChanged] is non-nullable).
  final bool enabled;

  @override
  State<AppSelect> createState() => _AppSelectState();
}

class _AppSelectState extends State<AppSelect> {
  final _layerLink = LayerLink();
  final _fieldKey = GlobalKey();
  OverlayEntry? _entry;
  bool _open = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
    if (_open && mounted) setState(() => _open = false);
  }

  void _toggle() {
    if (!widget.enabled) return;
    if (_entry != null) {
      _removeOverlay();
      return;
    }
    final box = _fieldKey.currentContext!.findRenderObject() as RenderBox;
    final width = box.size.width;
    final overlay = Overlay.of(context);
    var query = '';

    _entry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeOverlay,
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 6),
            child: StatefulBuilder(
              builder: (context, setPanelState) {
                final filtered = query.trim().isEmpty
                    ? widget.options
                    : widget.options
                          .where(
                            (o) => o.label.toLowerCase().contains(
                              query.trim().toLowerCase(),
                            ),
                          )
                          .toList();
                return Material(
                  color: Colors.transparent,
                  child: Container(
                    width: width,
                    constraints: const BoxConstraints(maxHeight: 280),
                    decoration: BoxDecoration(
                      color: context.appCard,
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      border: Border.all(color: context.appBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: context.appBorder),
                            ),
                          ),
                          child: Row(
                            children: [
                              AppIcon(
                                AppIcons.search,
                                size: 16,
                                color: context.appSubtext,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  autofocus: true,
                                  style: TextStyle(
                                    color: context.appText,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    border: InputBorder.none,
                                    hintText: widget.searchHint,
                                    hintStyle: TextStyle(
                                      color: context.appSubtext,
                                      fontSize: 14,
                                    ),
                                  ),
                                  onChanged: (v) =>
                                      setPanelState(() => query = v),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: filtered.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 22,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'No results',
                                      style: TextStyle(
                                        color: context.appSubtext,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView(
                                  padding: const EdgeInsets.all(8),
                                  shrinkWrap: true,
                                  children: [
                                    for (final option in filtered)
                                      InkWell(
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.inputRadius,
                                        ),
                                        onTap: () {
                                          widget.onChanged(option.value);
                                          _removeOverlay();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  option.label,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color:
                                                        option.value ==
                                                            widget.value
                                                        ? context.appPrimary
                                                        : context.appText,
                                                    fontWeight:
                                                        option.value ==
                                                            widget.value
                                                        ? FontWeight.w600
                                                        : FontWeight.w400,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              if (option.value == widget.value)
                                                AppIcon(
                                                  AppIcons.check,
                                                  size: 16,
                                                  color: context.appPrimary,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
    overlay.insert(_entry!);
    setState(() => _open = true);
  }

  @override
  Widget build(BuildContext context) {
    String? selectedLabel;
    for (final option in widget.options) {
      if (option.value == widget.value) {
        selectedLabel = option.label;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              color: context.appText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        CompositedTransformTarget(
          link: _layerLink,
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.6,
            child: InkWell(
              key: _fieldKey,
              borderRadius: BorderRadius.circular(AppTheme.inputRadius),
              onTap: _toggle,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: context.appCard,
                  borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                  border: Border.all(
                    color: _open ? context.appPrimary : context.appBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedLabel ?? widget.hint,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          color: selectedLabel != null
                              ? context.appText
                              : context.appSubtext,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: AppIcon(
                        AppIcons.chevronDown,
                        size: 16,
                        color: context.appSubtext,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
