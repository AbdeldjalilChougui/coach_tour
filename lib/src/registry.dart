import 'package:flutter/widgets.dart';

/// Maps anchor ids to keys so steps can be declared in one place while the
/// widgets they point at live anywhere in the tree.
class CoachTourRegistry {
  /// The registry used when none is given and no [CoachTourRegistryScope]
  /// is found.
  static final CoachTourRegistry global = CoachTourRegistry();

  /// The registry from the nearest [CoachTourRegistryScope], or [global].
  static CoachTourRegistry of(BuildContext context) =>
      CoachTourRegistryScope.maybeOf(context) ?? global;

  final Map<String, GlobalKey> _keys = {};

  /// The key for [id], created on first use. The same id always returns the
  /// same key, so rebuilding an anchor never remounts its child.
  GlobalKey keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  /// Registers a key you already own under [id].
  void register(String id, GlobalKey key) => _keys[id] = key;

  /// Removes [id].
  void unregister(String id) => _keys.remove(id);

  /// The key registered for [id], if any.
  GlobalKey? lookup(String id) => _keys[id];
}

/// Provides a [CoachTourRegistry] to a subtree.
class CoachTourRegistryScope extends InheritedWidget {
  /// Creates a scope exposing [registry].
  const CoachTourRegistryScope({
    required this.registry,
    required super.child,
    super.key,
  });

  /// The registry exposed to descendants.
  final CoachTourRegistry registry;

  /// The nearest registry, if any.
  static CoachTourRegistry? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CoachTourRegistryScope>()?.registry;

  @override
  bool updateShouldNotify(CoachTourRegistryScope oldWidget) =>
      registry != oldWidget.registry;
}

/// Marks [child] as a tour target named [id].
///
/// Each id must be mounted at most once at a time, since it maps to a single
/// [GlobalKey].
class CoachAnchor extends StatelessWidget {
  /// Creates an anchor.
  const CoachAnchor({
    required this.id,
    required this.child,
    this.registry,
    super.key,
  });

  /// Anchor id, matched by [CoachTarget.id].
  final String id;

  /// Registry to use; defaults to [CoachTourRegistry.of].
  final CoachTourRegistry? registry;

  /// The highlighted widget.
  final Widget child;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
        key: (registry ?? CoachTourRegistry.of(context)).keyFor(id),
        child: child,
      );
}
