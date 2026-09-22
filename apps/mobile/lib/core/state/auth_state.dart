import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

enum UserRole {
  visitor,
  creator,
}

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] == 'creator' ? UserRole.creator : UserRole.visitor,
    );
  }
}

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController() : super(const AuthState());

  /// Simulates authentication startup check
  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);
    await Future.delayed(const Duration(milliseconds: 300));
    // Default to unauthenticated for clean first launch experience
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    
    // Quick validation
    if (email.trim().isEmpty || !email.contains('@')) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Please provide a valid email address.',
      );
      return false;
    }

    if (password.length < 6) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Password must be at least 6 characters long.',
      );
      return false;
    }

    // Simulate backend handshake
    await Future.delayed(const Duration(milliseconds: 400));

    // Demo / test credentials validation: simulate failure for invalid@test.com
    if (email.toLowerCase().contains('fail')) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Invalid credentials. Please verify your email and password.',
      );
      return false;
    }

    // Success
    final role = email.toLowerCase().contains('creator') || email.toLowerCase().contains('nishant')
        ? UserRole.creator
        : UserRole.visitor;

    final user = AppUser(
      id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
      name: email.split('@').first.toUpperCase(),
      email: email.trim(),
      role: role,
    );

    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: user,
      clearError: true,
    );
    return true;
  }

  /// Register new user
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    if (name.trim().isEmpty) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Full name is required.',
      );
      return false;
    }

    if (email.trim().isEmpty || !email.contains('@')) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Please enter a valid email address.',
      );
      return false;
    }

    if (password.length < 6) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Password must be at least 6 characters.',
      );
      return false;
    }

    await Future.delayed(const Duration(milliseconds: 400));

    final user = AppUser(
      id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      email: email.trim(),
      role: role,
    );

    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: user,
      clearError: true,
    );
    return true;
  }

  /// Logout current user
  void logout() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Clear any error message
  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController();
});
