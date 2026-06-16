import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class ErrorHandler {
  // Global messenger key prevents context-loss crashes when routing midway through network errors
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  static void handle(dynamic error) {
    String errorMessage = "An unexpected system anomaly occurred.";
    String errorCode = "UNKNOWN_ERROR";

    if (error is DioException) {
      if (error.response != null && error.response?.data is Map) {
        final data = error.response!.data as Map<String, dynamic>;
        errorMessage = data['error'] ?? data['message'] ?? errorMessage;
        errorCode = data['code'] ?? "HTTP_${error.response?.statusCode}";
      } else {
        switch (error.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
            errorMessage = "Server connectivity timeout. Please check your network.";
            errorCode = "TIMEOUT_ERROR";
            break;
          case DioExceptionType.connectionError:
            errorMessage = "Unable to establish network handshake with servers.";
            errorCode = "CONNECTION_LOST";
            break;
          default:
            errorMessage = error.message ?? errorMessage;
        }
      }
    } else if (error is Exception) {
      errorMessage = error.toString();
    }

    showSnackBar(errorMessage, isError: true, code: errorCode);
  }

  static void showSnackBar(String message, {bool isError = true, String? code}) {
    final state = messengerKey.currentState;
    if (state == null) return;

    state.hideCurrentSnackBar();
    state.showSnackBar(
      SnackBar(
        backgroundColor: isError ? const Color(0xFF1A0A0A) : const Color(0xFF0D0D0D),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isError ? Colors.redAccent.withOpacity(0.5) : const Color(0xFF00FFCC).withOpacity(0.3),
            width: 1.0,
          ),
        ),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: isError ? Colors.redAccent : const Color(0xFF00FFCC),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w400),
                  ),
                  if (code != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      "CODE: $code",
                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, letterSpacing: 0.5),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}