// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discovery_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DiscoveryFilterNotifier)
final discoveryFilterProvider = DiscoveryFilterNotifierProvider._();

final class DiscoveryFilterNotifierProvider
    extends $NotifierProvider<DiscoveryFilterNotifier, DiscoveryFilter> {
  DiscoveryFilterNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoveryFilterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoveryFilterNotifierHash();

  @$internal
  @override
  DiscoveryFilterNotifier create() => DiscoveryFilterNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiscoveryFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiscoveryFilter>(value),
    );
  }
}

String _$discoveryFilterNotifierHash() =>
    r'95466acab1b7278fc8ca5ec2bfbc0b6142264214';

abstract class _$DiscoveryFilterNotifier extends $Notifier<DiscoveryFilter> {
  DiscoveryFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DiscoveryFilter, DiscoveryFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DiscoveryFilter, DiscoveryFilter>,
              DiscoveryFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(DiscoveryViewModel)
final discoveryViewModelProvider = DiscoveryViewModelProvider._();

final class DiscoveryViewModelProvider
    extends $NotifierProvider<DiscoveryViewModel, DiscoveryState> {
  DiscoveryViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoveryViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoveryViewModelHash();

  @$internal
  @override
  DiscoveryViewModel create() => DiscoveryViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiscoveryState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiscoveryState>(value),
    );
  }
}

String _$discoveryViewModelHash() =>
    r'146a7e67d7af4728a3419eaf0865ecf6041cb8b5';

abstract class _$DiscoveryViewModel extends $Notifier<DiscoveryState> {
  DiscoveryState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DiscoveryState, DiscoveryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DiscoveryState, DiscoveryState>,
              DiscoveryState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Tổng số tin chưa đọc trên mọi match (badge ở icon chat).

@ProviderFor(unreadCount)
final unreadCountProvider = UnreadCountProvider._();

/// Tổng số tin chưa đọc trên mọi match (badge ở icon chat).

final class UnreadCountProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Tổng số tin chưa đọc trên mọi match (badge ở icon chat).
  UnreadCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unreadCountProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unreadCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return unreadCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$unreadCountHash() => r'8be18b98409330de38761664c150db8c508f84ff';
