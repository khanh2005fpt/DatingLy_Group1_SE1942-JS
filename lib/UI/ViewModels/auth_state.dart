import '../../data/models/user_model.dart';

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final UserModel? userModel;
  final bool isAuthenticated;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.userModel,
    this.isAuthenticated = false,
  });

  bool get onboardingCompleted =>
      userModel?.onboardingCompleted == true ||
      (userModel != null && userModel!.fullName.trim().isNotEmpty);

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    UserModel? userModel,
    bool? isAuthenticated,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      userModel: userModel ?? this.userModel,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}
