// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(matchesStream)
final matchesStreamProvider = MatchesStreamProvider._();

final class MatchesStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MatchModel>>,
          List<MatchModel>,
          Stream<List<MatchModel>>
        >
    with $FutureModifier<List<MatchModel>>, $StreamProvider<List<MatchModel>> {
  MatchesStreamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'matchesStreamProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$matchesStreamHash();

  @$internal
  @override
  $StreamProviderElement<List<MatchModel>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MatchModel>> create(Ref ref) {
    return matchesStream(ref);
  }
}

String _$matchesStreamHash() => r'700088c0aa2ac4ae1c000ff29812a3d90a0fa8a0';

@ProviderFor(messagesStream)
final messagesStreamProvider = MessagesStreamFamily._();

final class MessagesStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MessageModel>>,
          List<MessageModel>,
          Stream<List<MessageModel>>
        >
    with
        $FutureModifier<List<MessageModel>>,
        $StreamProvider<List<MessageModel>> {
  MessagesStreamProvider._({
    required MessagesStreamFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'messagesStreamProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$messagesStreamHash();

  @override
  String toString() {
    return r'messagesStreamProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<MessageModel>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MessageModel>> create(Ref ref) {
    final argument = this.argument as String;
    return messagesStream(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MessagesStreamProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$messagesStreamHash() => r'986f5f54444044c268ae99c185390de22da543cc';

final class MessagesStreamFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<MessageModel>>, String> {
  MessagesStreamFamily._()
    : super(
        retry: null,
        name: r'messagesStreamProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MessagesStreamProvider call(String matchId) =>
      MessagesStreamProvider._(argument: matchId, from: this);

  @override
  String toString() => r'messagesStreamProvider';
}

@ProviderFor(chatViewModel)
final chatViewModelProvider = ChatViewModelProvider._();

final class ChatViewModelProvider
    extends $FunctionalProvider<ChatViewModel, ChatViewModel, ChatViewModel>
    with $Provider<ChatViewModel> {
  ChatViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatViewModelHash();

  @$internal
  @override
  $ProviderElement<ChatViewModel> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ChatViewModel create(Ref ref) {
    return chatViewModel(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatViewModel value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatViewModel>(value),
    );
  }
}

String _$chatViewModelHash() => r'ce0f66a8052eb7c19c7f3a6329462636c0d3eb6a';
