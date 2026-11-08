// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'who_liked_me_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WhoLikedMeViewModel)
final whoLikedMeViewModelProvider = WhoLikedMeViewModelProvider._();

final class WhoLikedMeViewModelProvider
    extends $NotifierProvider<WhoLikedMeViewModel, WhoLikedMeState> {
  WhoLikedMeViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'whoLikedMeViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$whoLikedMeViewModelHash();

  @$internal
  @override
  WhoLikedMeViewModel create() => WhoLikedMeViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WhoLikedMeState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WhoLikedMeState>(value),
    );
  }
}

String _$whoLikedMeViewModelHash() =>
    r'9c391b09f409f148cf9e680192c852217b03598c';

abstract class _$WhoLikedMeViewModel extends $Notifier<WhoLikedMeState> {
  WhoLikedMeState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WhoLikedMeState, WhoLikedMeState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WhoLikedMeState, WhoLikedMeState>,
              WhoLikedMeState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Số người chưa match đã like mình (badge).

@ProviderFor(whoLikedMeCount)
final whoLikedMeCountProvider = WhoLikedMeCountProvider._();

/// Số người chưa match đã like mình (badge).

final class WhoLikedMeCountProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Số người chưa match đã like mình (badge).
  WhoLikedMeCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'whoLikedMeCountProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$whoLikedMeCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return whoLikedMeCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$whoLikedMeCountHash() => r'd259519f887cd9b00822201ad35138a0eae11c01';

/// ID những người đã like mình (chưa match), dùng cho huy hiệu "Đã thích bạn".

@ProviderFor(whoLikedMeUserIds)
final whoLikedMeUserIdsProvider = WhoLikedMeUserIdsProvider._();

/// ID những người đã like mình (chưa match), dùng cho huy hiệu "Đã thích bạn".

final class WhoLikedMeUserIdsProvider
    extends $FunctionalProvider<Set<String>, Set<String>, Set<String>>
    with $Provider<Set<String>> {
  /// ID những người đã like mình (chưa match), dùng cho huy hiệu "Đã thích bạn".
  WhoLikedMeUserIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'whoLikedMeUserIdsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$whoLikedMeUserIdsHash();

  @$internal
  @override
  $ProviderElement<Set<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<String> create(Ref ref) {
    return whoLikedMeUserIds(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$whoLikedMeUserIdsHash() => r'85645db6e61219ebd28dc21f32936201cb95c04d';
