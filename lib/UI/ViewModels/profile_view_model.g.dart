// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(myProfileStream)
final myProfileStreamProvider = MyProfileStreamProvider._();

final class MyProfileStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserModel?>,
          UserModel?,
          Stream<UserModel?>
        >
    with $FutureModifier<UserModel?>, $StreamProvider<UserModel?> {
  MyProfileStreamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myProfileStreamProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myProfileStreamHash();

  @$internal
  @override
  $StreamProviderElement<UserModel?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<UserModel?> create(Ref ref) {
    return myProfileStream(ref);
  }
}

String _$myProfileStreamHash() => r'b26245ce43da81496da034a5df421c6495575885';

@ProviderFor(profileViewModel)
final profileViewModelProvider = ProfileViewModelProvider._();

final class ProfileViewModelProvider
    extends
        $FunctionalProvider<
          ProfileViewModel,
          ProfileViewModel,
          ProfileViewModel
        >
    with $Provider<ProfileViewModel> {
  ProfileViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileViewModelHash();

  @$internal
  @override
  $ProviderElement<ProfileViewModel> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ProfileViewModel create(Ref ref) {
    return profileViewModel(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileViewModel value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileViewModel>(value),
    );
  }
}

String _$profileViewModelHash() => r'ec77d3cb168f2a0e25cf181000080e49bebebb92';
