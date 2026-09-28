class RoomSharedAudioQueueLogic {
  const RoomSharedAudioQueueLogic._();

  static ({List<T> items, int currentIndex}) reorder<T>({
    required List<T> items,
    required int oldIndex,
    required int newIndex,
    required int currentIndex,
  }) {
    if (oldIndex < 0 || oldIndex >= items.length) {
      return (items: List<T>.from(items), currentIndex: currentIndex);
    }

    var insertAt = newIndex.clamp(0, items.length - 1);

    final next = List<T>.from(items);
    final item = next.removeAt(oldIndex);
    next.insert(insertAt, item);

    var idx = currentIndex;
    if (idx == oldIndex) {
      idx = insertAt;
    } else if (oldIndex < idx && insertAt >= idx) {
      idx -= 1;
    } else if (oldIndex > idx && insertAt <= idx) {
      idx += 1;
    }
    return (items: next, currentIndex: idx);
  }

  static int nextIndex({required int currentIndex, required int length}) {
    if (length <= 0) return -1;
    if (currentIndex < 0) return 0;
    return (currentIndex + 1) % length;
  }

  static int remapIndexAfterRemove({
    required int removedIndex,
    required int currentIndex,
  }) {
    if (currentIndex < 0) return -1;
    if (removedIndex == currentIndex) return -1;
    if (removedIndex < currentIndex) return currentIndex - 1;
    return currentIndex;
  }
}
