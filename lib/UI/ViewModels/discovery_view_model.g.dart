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
    r'8e9802acfc375b2655b221916307da8389266da8';

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

@ProviderFor(matchCount)
final matchCountProvider = MatchCountProvider._();

final class MatchCountProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  MatchCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'matchCountProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$matchCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return matchCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$matchCountHash() => r'3cb6600218ef7464839491186ded2b7f533d2086';
