// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_bootstrap.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Khởi chạy các luồng thông báo của app (watch 1 lần ở root widget):
///  1. Lưu FCM token vào Firestore (`users/{uid}.fcm_token`) khi đăng nhập / token đổi.
///  2. Hiện local notification khi có match mới hoặc tin nhắn mới.

@ProviderFor(notificationBootstrap)
final notificationBootstrapProvider = NotificationBootstrapProvider._();

/// Khởi chạy các luồng thông báo của app (watch 1 lần ở root widget):
///  1. Lưu FCM token vào Firestore (`users/{uid}.fcm_token`) khi đăng nhập / token đổi.
///  2. Hiện local notification khi có match mới hoặc tin nhắn mới.

final class NotificationBootstrapProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Khởi chạy các luồng thông báo của app (watch 1 lần ở root widget):
  ///  1. Lưu FCM token vào Firestore (`users/{uid}.fcm_token`) khi đăng nhập / token đổi.
  ///  2. Hiện local notification khi có match mới hoặc tin nhắn mới.
  NotificationBootstrapProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationBootstrapProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationBootstrapHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return notificationBootstrap(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$notificationBootstrapHash() =>
    r'88dd10c9b66f0d8f5a22767132ae845f3230abc4';
