import 'dart:io';
import 'package:dio/dio.dart';
import '../../models/history_item.dart';
import '../../models/product_enrichment.dart';
import '../../models/product_review.dart';
import '../../models/search_filter.dart';
import '../../models/search_result.dart';

/// Base URL strategy:
///   - Physical device via USB   → http://localhost:5000  (adb reverse tcp:5000 tcp:5000) ← active
///   - Android emulator          → http://10.0.2.2:5000   (emulator alias for host)
///   - Azure VM (prod)           → http://20.235.241.126  (Docker port 80 → Node :3000)
// const String _deviceBase      = 'http://localhost:5000';   // USB + adb reverse  ← active
// const String _emulatorBase = 'http://10.0.2.2:5000';   // Android emulator (local)
const String _azureBase    = 'http://20.244.10.53:5000';  // Azure VM (production)

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  late final Dio _dio = _buildDio();

  Dio _buildDio() {
    final baseUrl = _resolveBaseUrl();

    final options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    final dio = Dio(options);

    // ── Logging interceptor (dev only) ─────────────────────────────────────
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // ignore: avoid_print
          print('[API] ▶  ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          // ignore: avoid_print
          print(
            '[API] ✅  ${response.statusCode} ${response.requestOptions.path}',
          );
          handler.next(response);
        },
        onError: (DioException e, handler) {
          // ignore: avoid_print
          print('[API] ❌  ${e.type} – ${e.message}');
          handler.next(e);
        },
      ),
    );

    return dio;
  }

  /// To switch environments uncomment the matching constant above and update this line.
  String _resolveBaseUrl() => _azureBase;

  // ── Health ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> checkHealth() async {
    final res = await _dio.get('/api/v1/health');
    return res.data as Map<String, dynamic>;
  }

  // ── Multimodal Search ───────────────────────────────────────────────────

  /// [imagePath]  – local file path to the captured image (nullable)
  /// [audioPath]  – local file path to the voice recording (nullable)
  /// [query]      – optional plain-text override / supplement
  /// [transcript] – pre-transcribed voice text
  /// [sessionId]  – anonymous session token for history persistence
  Future<Map<String, dynamic>> multimodalSearch({
    String? imagePath,
    String? audioPath,
    String? query,
    String? transcript,
    String? sessionId,
  }) async {
    final formData = FormData();

    if (imagePath != null) {
      formData.files.add(
        MapEntry(
          'image',
          await MultipartFile.fromFile(
            imagePath,
            filename: File(imagePath).uri.pathSegments.last,
          ),
        ),
      );
    }

    if (audioPath != null) {
      formData.files.add(
        MapEntry(
          'audio',
          await MultipartFile.fromFile(
            audioPath,
            filename: File(audioPath).uri.pathSegments.last,
          ),
        ),
      );
    }

    if (query      != null && query.isNotEmpty)      formData.fields.add(MapEntry('query',      query));
    if (transcript != null && transcript.isNotEmpty) formData.fields.add(MapEntry('transcript', transcript));
    if (sessionId  != null && sessionId.isNotEmpty)  formData.fields.add(MapEntry('sessionId',  sessionId));

    final res = await _dio.post(
      '/api/v1/search',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        receiveTimeout: const Duration(seconds: 60), // Gemini can take up to 15s
      ),
    );
    return res.data as Map<String, dynamic>;
  }

  /// Typed wrapper — returns a [SearchResult] model directly.
  Future<SearchResult> search({
    String? imagePath,
    String? audioPath,
    String? query,
    String? transcript,
    String? sessionId,
  }) async {
    final raw = await multimodalSearch(
      imagePath:  imagePath,
      audioPath:  audioPath,
      query:      query,
      transcript: transcript,
      sessionId:  sessionId,
    );
    return SearchResult.fromJson(raw);
  }

  // ── Analyze (step 1 of the 2-step search flow) ───────────────────────────

  /// Send image / audio inputs to the analyze endpoint.
  /// Returns AI-detected tags + smart search filters.
  /// Does NOT call Serper (no product list).
  Future<AnalyzeResult> analyzeSearch({
    String? imagePath,
    String? audioPath,
    String? query,
    String? transcript,
  }) async {
    final formData = FormData();

    if (imagePath != null) {
      formData.files.add(MapEntry(
        'image',
        await MultipartFile.fromFile(
          imagePath,
          filename: File(imagePath).uri.pathSegments.last,
        ),
      ));
    }
    if (audioPath != null) {
      formData.files.add(MapEntry(
        'audio',
        await MultipartFile.fromFile(
          audioPath,
          filename: File(audioPath).uri.pathSegments.last,
        ),
      ));
    }
    if (query      != null && query.isNotEmpty)      formData.fields.add(MapEntry('query',      query));
    if (transcript != null && transcript.isNotEmpty) formData.fields.add(MapEntry('transcript', transcript));

    final res = await _dio.post(
      '/api/v1/analyze',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    return AnalyzeResult.fromJson(res.data as Map<String, dynamic>);
  }

  /// Inject or remove the Bearer token used for authenticated requests.
  void setAuthToken(String? token) {
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  /// Exchange a Google ID token for a Go4 JWT + user profile.
  Future<Map<String, dynamic>> signInWithGoogle(String idToken) async {
    final res = await _dio.post(
      '/api/v1/auth/google',
      data: {'idToken': idToken},
    );
    return res.data as Map<String, dynamic>;
  }

  // ── History ─────────────────────────────────────────────────────────────────

  /// Fetch the signed-in user's search history (up to 50 items).
  Future<List<HistoryItem>> getHistory() async {
    final res = await _dio.get(
      '/api/v1/history',
      options: Options(receiveTimeout: const Duration(seconds: 60)),
    );
    return (res.data as List<dynamic>)
        .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Places ──────────────────────────────────────────────────────────────────

  /// Find nearby stores relevant to a product.
  ///
  /// Backend resolves [category] + [productName] into the correct Google Places
  /// type (e.g. `electronics_store`) and searches via Nearby Search API with
  /// `rankby=distance` — returning only real stores of that type, closest first.
  ///
  /// Returns a list of place maps:
  ///   { placeId, name, address, lat, lng, rating, openNow, types }
  Future<List<Map<String, dynamic>>> getNearbyPlaces({
    required String category,
    required String productName,
    double? lat,
    double? lng,
  }) async {
    final params = <String, dynamic>{
      'category':    category,
      'productName': productName,
    };
    if (lat != null) params['lat'] = lat;
    if (lng != null) params['lng'] = lng;

    final res = await _dio.get('/api/v1/places/nearby', queryParameters: params);
    final data = res.data as Map<String, dynamic>;
    return (data['places'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// Fetch opening hours, phone, website for a single place.
  ///
  /// Returns: { openNow, weekdayText, phone, website, mapsUrl }
  Future<Map<String, dynamic>> getPlaceDetails(String placeId) async {
    final res = await _dio.get(
      '/api/v1/places/details',
      queryParameters: {'placeId': placeId},
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Product Enrichment ──────────────────────────────────────────────────────

  /// Use Gemini to generate specs, description, and features for a product.
  ///
  /// [title]    – product title (required)
  /// [category] – product category from Gemini image analysis
  /// [source]   – store/retailer name
  /// [price]    – price string
  Future<ProductEnrichment> enrichProduct({
    required String title,
    String? category,
    String? source,
    String? price,
  }) async {
    final res = await _dio.post(
      '/api/v1/product/enrich',
      data: {
        'title': title,
        if (category != null) 'category': category,
        if (source != null) 'source': source,
        if (price != null) 'price': price,
      },
      options: Options(receiveTimeout: const Duration(seconds: 30)),
    );
    return ProductEnrichment.fromJson(res.data as Map<String, dynamic>);
  }

  /// Collect web review snippets and run Gemini analysis for a product.
  ///
  /// [title]    – product title (required)
  /// [category] – product category from Gemini image analysis
  Future<ProductReviewResult> getProductReviews({
    required String title,
    String? category,
  }) async {
    final res = await _dio.post(
      '/api/v1/product/reviews',
      data: {
        'title': title,
        if (category != null) 'category': category,
      },
      options: Options(
        receiveTimeout: const Duration(seconds: 45), // Serper + Gemini can be slow
      ),
    );
    return ProductReviewResult.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Recommendations ─────────────────────────────────────────────────────────

  /// Fetch personalised product recommendations + learned preference profile.
  ///
  /// Requires a valid JWT (from [setAuthToken]).
  /// Response: { preferences, recommendations: [Product], query, message? }
  Future<Map<String, dynamic>> getRecommendations() async {
    final res = await _dio.get(
      '/api/v1/recommendations',
      options: Options(receiveTimeout: const Duration(seconds: 45)),
    );
    return res.data as Map<String, dynamic>;
  }

  /// Fetch just the user's raw preference summary (no product fetch).
  Future<Map<String, dynamic>> getPreferences() async {
    final res = await _dio.get('/api/v1/recommendations/preferences');
    return res.data as Map<String, dynamic>;
  }
}
