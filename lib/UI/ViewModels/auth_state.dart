import '../../data/models/user_model.dart';

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final UserModel? userModel;
  final bool isAuthenticated;

  // Phone OTP Auth state
  final String? verificationId;
  final int? resendToken;
  final String? phoneNumber;
  final int resendCountdown;
  final bool isOtpSent;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.userModel,
    this.isAuthenticated = false,
    this.verificationId,
    this.resendToken,
    this.phoneNumber,
    this.resendCountdown = 0,
    this.isOtpSent = false,
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
    String? verificationId,
    int? resendToken,
    String? phoneNumber,
    int? resendCountdown,
    bool? isOtpSent,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      userModel: userModel ?? this.userModel,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      resendCountdown: resendCountdown ?? this.resendCountdown,
      isOtpSent: isOtpSent ?? this.isOtpSent,
    );
  }
}
