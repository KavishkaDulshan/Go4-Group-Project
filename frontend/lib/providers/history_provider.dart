import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../models/history_item.dart';
import 'auth_provider.dart';

/// Fetches the signed-in user's search history from the backend.
/// Auto-disposes when the widget tree no longer needs it.
/// Rebuilds automatically whenever auth state changes.
final historyProvider =
    FutureProvider.autoDispose<List<HistoryItem>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isSignedIn) return [];
  return ApiClient.instance.getHistory();
});
