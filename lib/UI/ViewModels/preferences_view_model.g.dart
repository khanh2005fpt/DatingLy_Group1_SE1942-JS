// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preferences_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PreferencesViewModel)
final preferencesViewModelProvider = PreferencesViewModelProvider._();

final class PreferencesViewModelProvider
    extends $NotifierProvider<PreferencesViewModel, PreferencesState> {
  PreferencesViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'preferencesViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$preferencesViewModelHash();

  @$internal
  @override
  PreferencesViewModel create() => PreferencesViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PreferencesState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PreferencesState>(value),
    );
  }
}

String _$preferencesViewModelHash() =>
    r'7fbe4f43f51cc9282c45378443f492b15fd2acae';

abstract class _$PreferencesViewModel extends $Notifier<PreferencesState> {
  PreferencesState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PreferencesState, PreferencesState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PreferencesState, PreferencesState>,
              PreferencesState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
