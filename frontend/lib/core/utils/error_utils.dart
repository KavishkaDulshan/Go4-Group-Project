import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

/// Converts any thrown exception into a short, human-readable message
/// suitable for display in a SnackBar, error box, or error screen.
///
/// Never exposes stack traces, class names, or raw server payloads.
String friendlyError(dynamic error) {
  // ── Dio / HTTP errors ─────────────────────────────────────────────────────
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timed out. Please check your connection and try again.';

      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network.';

      case DioExceptionType.badResponse:
        final code = error.response?.statusCode ?? 0;
        // Prefer the backend's own error message when available
        final data = error.response?.data;
        if (data is Map && data['error'] is String) {
          return data['error'] as String;
        }
        if (code == 400) return 'Invalid request. Please try again.';
        if (code == 401) return 'Session expired. Please sign in again.';
        if (code == 403) return 'You don\'t have permission to do that.';
        if (code == 404) return 'The requested resource was not found.';
        if (code >= 500) {
          return 'Something went wrong on our end. Please try again later.';
        }
        return 'Unexpected error. Please try again.';

      case DioExceptionType.cancel:
        return 'Request was cancelled.';

      default:
        return 'Something went wrong. Please try again.';
    }
  }

  // ── No internet ───────────────────────────────────────────────────────────
  if (error is SocketException) {
    return 'No internet connection. Please check your network.';
  }

  // ── Google Sign-In / Platform errors ─────────────────────────────────────
  if (error is PlatformException) {
    switch (error.code) {
      case 'sign_in_cancelled':
        return 'Sign-in was cancelled.';
      case 'network_error':
        return 'Network error during sign-in. Please try again.';
      case 'sign_in_failed':
        return 'Google sign-in failed. Please try again.';
      default:
        return 'Sign-in error. Please try again.';
    }
  }

  // ── Known app-level exceptions ────────────────────────────────────────────
  if (error is Exception) {
    final msg = error.toString();
    // Strip "Exception: " prefix from manually thrown exceptions
    if (msg.startsWith('Exception: ')) {
      return msg.substring('Exception: '.length);
    }
  }

  return 'Something went wrong. Please try again.';
}
