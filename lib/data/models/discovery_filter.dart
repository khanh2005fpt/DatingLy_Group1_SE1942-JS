import 'package:flutter/foundation.dart';

/// Cấu hình bộ lọc Discovery (lưu bằng SharedPreferences)
@immutable
class DiscoveryFilter {
  static const int minAgeLimit = 18;
  static const int maxAgeLimit = 60;
  static const int minDistanceLimit = 1;
  static const int maxDistanceLimit = 100;

  static const int defaultMinAge = 18;
  static const int defaultMaxAge = 35;
  static const int defaultMaxDistance = 50;
  static const String anyGender = 'all';

  final int minAge;
  final int maxAge;
  final int maxDistanceKm;

  /// `Nữ` | `Nam` | `Khác` | `all`
  final String interestedIn;

  /// Chỉ hiện người có ít nhất 1 trong các sở thích này (rỗng = không lọc)
  final List<String> interests;

  /// Chỉ hiện người có ít nhất 1 sở thích chung với mình
  final bool requireCommonInterest;

  const DiscoveryFilter({
    this.minAge = defaultMinAge,
    this.maxAge = defaultMaxAge,
    this.maxDistanceKm = defaultMaxDistance,
    this.interestedIn = anyGender,
    this.interests = const [],
    this.requireCommonInterest = false,
  });

  bool get filtersByGender =>
      interestedIn.isNotEmpty && interestedIn != anyGender;

  DiscoveryFilter copyWith({
    int? minAge,
    int? maxAge,
    int? maxDistanceKm,
    String? interestedIn,
    List<String>? interests,
    bool? requireCommonInterest,
  }) {
    return DiscoveryFilter(
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      interestedIn: interestedIn ?? this.interestedIn,
      interests: interests ?? this.interests,
      requireCommonInterest:
          requireCommonInterest ?? this.requireCommonInterest,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DiscoveryFilter &&
      other.minAge == minAge &&
      other.maxAge == maxAge &&
      other.maxDistanceKm == maxDistanceKm &&
      other.interestedIn == interestedIn &&
      other.requireCommonInterest == requireCommonInterest &&
      listEquals(other.interests, interests);

  @override
  int get hashCode => Object.hash(
        minAge,
        maxAge,
        maxDistanceKm,
        interestedIn,
        requireCommonInterest,
        Object.hashAll(interests),
      );
}
