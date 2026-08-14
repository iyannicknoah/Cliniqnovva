import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_ext.dart';
import 'app_icon.dart';

/// Same visual shape/API as `LabeledDropdown` (optional label above a
/// bordered, filled field) but type-to-filter instead of a fixed tap-to-open
/// list — for pickers backed by longer name lists (doctors, currently)
/// where scrolling a plain dropdown is painful. 2026-07-26, explicit user
/// instruction: "make the doctor dropdown searchable across the whole
/// system" — this is the one shared component both doctor pickers
/// (`doctor_schedule_screen.dart`, `booking_screen.dart`) now use, so any
/// future doctor picker gets the same behavior for free.
///
/// Built on [RawAutocomplete] — no extra package needed. [items] is a list
/// of ids; [itemLabels] maps id -> display text (falls back to the raw id
/// when absent), same convention as `LabeledDropdown`.
class SearchableDropdown extends StatefulWidget {
  const SearchableDropdown({
    super.key,
    this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.itemLabels,
  });

  final String? label;
  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final Map<String, String>? itemLabels;

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  String _labelFor(String id) => widget.itemLabels?[id] ?? id;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _initialText());
    _focusNode.addListener(_onFocusChange);
  }

  String _initialText() => widget.value != null ? _labelFor(widget.value!) : '';

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // Clear on focus (2026-07-26, explicit user instruction) so clicking
      // the field immediately shows every option, like a normal dropdown —
      // not a text field you have to manually clear before search works.
      _controller.clear();
    } else {
      // Revert to the last confirmed selection's label if the field loses
      // focus mid-search without picking anything — otherwise a typed-but-
      // unselected query would silently blank out what's actually selected.
      _controller.text = _initialText();
    }
  }

  @override
  void didUpdateWidget(SearchableDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text = _initialText();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        LayoutBuilder(
          builder: (context, constraints) {
            return RawAutocomplete<String>(
              textEditingController: _controller,
              focusNode: _focusNode,
              displayStringForOption: _labelFor,
              optionsBuilder: (textValue) {
                final query = textValue.text.trim().toLowerCase();
                if (query.isEmpty) return widget.items;
                return widget.items.where(
                  (id) => _labelFor(id).toLowerCase().contains(query),
                );
              },
              onSelected: (id) {
                widget.onChanged(id);
                _controller.text = _labelFor(id);
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onSubmitted: (_) => onFieldSubmitted(),
                      style: TextStyle(color: context.appText, fontSize: 15),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: context.appCard,
                        hintText: widget.hint,
                        hintStyle: TextStyle(
                          color: context.appSubtext,
                          fontSize: 14,
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: AppIcon(
                            AppIcons.search,
                            size: 16,
                            color: context.appSubtext,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.inputRadius,
                          ),
                          borderSide: BorderSide(color: context.appBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.inputRadius,
                          ),
                          borderSide: BorderSide(color: context.appBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.inputRadius,
                          ),
                          borderSide: BorderSide(color: context.appPrimary),
                        ),
                      ),
                    );
                  },
              optionsViewBuilder: (context, onSelected, options) {
                final list = options.toList();
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: constraints.maxWidth,
                      constraints: const BoxConstraints(maxHeight: 240),
                      decoration: BoxDecoration(
                        color: context.appCard,
                        // 2026-08-14, explicit user instruction — dropdown
                        // popups use the same card radius + floating-shadow
                        // convention as the new AppSelect (was inputRadius,
                        // no shadow).
                        borderRadius: BorderRadius.circular(
                          AppTheme.cardRadius,
                        ),
                        border: Border.all(color: context.appBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: list.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Text(
                                'No matches.',
                                style: TextStyle(color: context.appSubtext),
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: list.length,
                              itemBuilder: (context, index) {
                                final option = list[index];
                                return InkWell(
                                  onTap: () => onSelected(option),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      _labelFor(option),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: context.appText,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
