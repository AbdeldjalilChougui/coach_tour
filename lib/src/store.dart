/// Remembers which tours a user has already seen.
///
/// Implement it over whatever storage your app uses (shared_preferences,
/// a database, a server); the package itself depends on none of them.
abstract interface class CoachTourStore {
  /// Whether the tour [tourId] was already seen.
  Future<bool> hasSeen(String tourId);

  /// Records that the tour [tourId] was seen.
  Future<void> markSeen(String tourId);

  /// Forgets [tourId] so the tour shows again.
  Future<void> reset(String tourId);
}

/// A [CoachTourStore] kept in memory; lost when the app restarts.
class MemoryCoachTourStore implements CoachTourStore {
  final Set<String> _seen = {};

  @override
  Future<bool> hasSeen(String tourId) async => _seen.contains(tourId);

  @override
  Future<void> markSeen(String tourId) async => _seen.add(tourId);

  @override
  Future<void> reset(String tourId) async => _seen.remove(tourId);
}
