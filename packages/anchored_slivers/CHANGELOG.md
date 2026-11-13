## 0.1.0-dev

- Prototype: `SliverAnchoredList`, `SliverAnchoredMasonry`, `SliverAnchorController`.
- Fix: changing the lane count while the leading edge is on screen now refills
  the lanes in index order, so the head of the list matches a layout that
  started with the new lane count (a 1 -> 2 column change used to leave the
  first item in the right column). Covered by `test/lane_count_change_test.dart`.
