import 'package:flutter/material.dart';

class SliverPinnedHeader extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double extent;

  const SliverPinnedHeader({required this.child, required this.extent});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final bg = Theme.of(context).colorScheme.surface;
    final border = BorderSide(
      color: Theme.of(context).dividerColor,
      width: 0.5,
    );
    return Material(
      color: bg,
      child: SafeArea(
        bottom: false,
        child: ClipRect(
          child: SizedBox(
            height: extent,
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border(bottom: border)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPinnedHeader oldDelegate) {
    return oldDelegate.child != child || oldDelegate.extent != extent;
  }
}
