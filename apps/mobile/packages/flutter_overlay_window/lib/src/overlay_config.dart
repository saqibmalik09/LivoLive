enum OverlayAlignment {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight
}

enum PositionGravity {
  none,

  right,

  left,

  auto,
}

enum OverlayFlag {
  @Deprecated('Use "clickThrough" instead.')
  flagNotTouchable,

  @Deprecated('Use "defaultFlag" instead.')
  flagNotFocusable,

  @Deprecated('Use "focusPointer" instead.')
  flagNotTouchModal,

  clickThrough,

  defaultFlag,

  focusPointer,
}

enum NotificationVisibility {
  visibilityPublic,

  visibilitySecret,

  visibilityPrivate
}

class WindowSize {
  WindowSize._();

  static const int matchParent = -1;

  static const int fullCover = -1999;
}
