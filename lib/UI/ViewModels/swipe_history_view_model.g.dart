// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'swipe_history_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SwipeHistoryViewModel)
final swipeHistoryViewModelProvider = SwipeHistoryViewModelProvider._();

final class SwipeHistoryViewModelProvider
    extends $NotifierProvider<SwipeHistoryViewModel, SwipeHistoryState> {
  SwipeHistoryViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'swipeHistoryViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$swipeHistoryViewModelHash();

  @$internal
  @override
  SwipeHistoryViewModel create() => SwipeHistoryViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SwipeHistoryState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SwipeHistoryState>(value),
    );
  }
}

String _$swipeHistoryViewModelHash() =>
    r'0e1d3d670d8be230cf8cdf0e7ffef51826903978';

abstract class _$SwipeHistoryViewModel extends $Notifier<SwipeHistoryState> {
  SwipeHistoryState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SwipeHistoryState, SwipeHistoryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SwipeHistoryState, SwipeHistoryState>,
              SwipeHistoryState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
