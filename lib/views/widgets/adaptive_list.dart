import 'package:flutter/material.dart';

/// A scrolling list that becomes a 1, 2 or 3 column grid depending on the
/// available width. Rows size themselves to their tallest card, so content can
/// grow (large fonts, long names) without overflowing.
class AdaptiveList<T> extends StatelessWidget {
  const AdaptiveList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.header,
    this.emptyState,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 96),
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Scrolls with the list, shown above the items at full width.
  final Widget? header;

  /// Shown below the header when [items] is empty.
  final Widget? emptyState;
  final EdgeInsets padding;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100 ? 3 : (width >= 680 ? 2 : 1);
        final rowCount = (items.length / columns).ceil();
        final hasHeader = header != null;
        final showEmpty = items.isEmpty && emptyState != null;
        final count = (hasHeader ? 1 : 0) + (showEmpty ? 1 : rowCount);

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: ListView.builder(
              padding: padding,
              itemCount: count,
              itemBuilder: (context, index) {
                var i = index;
                if (hasHeader) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: _gap),
                      child: header,
                    );
                  }
                  i -= 1;
                }
                if (showEmpty) return emptyState!;

                final start = i * columns;
                return Padding(
                  padding: const EdgeInsets.only(bottom: _gap),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var c = 0; c < columns; c++) ...[
                          if (c > 0) const SizedBox(width: _gap),
                          Expanded(
                            child: start + c < items.length
                                ? itemBuilder(context, items[start + c])
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
