// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'who_liked_you_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Danh sách người đã thích mình mà mình chưa quẹt lại (autoDispose mặc định).

@ProviderFor(whoLikedMe)
final whoLikedMeProvider = WhoLikedMeProvider._();

/// Danh sách người đã thích mình mà mình chưa quẹt lại (autoDispose mặc định).

final class WhoLikedMeProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<UserModel>>,
          List<UserModel>,
          FutureOr<List<UserModel>>
        >
    with $FutureModifier<List<UserModel>>, $FutureProvider<List<UserModel>> {
  /// Danh sách người đã thích mình mà mình chưa quẹt lại (autoDispose mặc định).
  WhoLikedMeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'whoLikedMeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$whoLikedMeHash();

  @$internal
  @override
  $FutureProviderElement<List<UserModel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<UserModel>> create(Ref ref) {
    return whoLikedMe(ref);
  }
}

String _$whoLikedMeHash() => r'34a328e720c505a6f9eef3dc02b003df441543c2';
