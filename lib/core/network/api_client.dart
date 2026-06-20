import 'package:dio/dio.dart';

import '../models/api_exception.dart';

class ApiClient {
  ApiClient({required String baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 25),
            headers: {'Accept': 'application/json'},
          ),
        );

  final Dio _dio;

  Future<Map<String, dynamic>> getJson(String path, {String? token, Map<String, dynamic>? query}) {
    return _request('GET', path, token: token, query: query);
  }

  Future<Map<String, dynamic>> postJson(String path, {String? token, Map<String, dynamic>? data}) {
    return _request('POST', path, token: token, data: data);
  }

  Future<Map<String, dynamic>> patchJson(String path, {String? token, Map<String, dynamic>? data}) {
    return _request('PATCH', path, token: token, data: data);
  }

  Future<Map<String, dynamic>> deleteJson(String path, {String? token, Map<String, dynamic>? data}) {
    return _request('DELETE', path, token: token, data: data);
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    String? token,
    Map<String, dynamic>? fields,
    Map<String, String>? files,
    Map<String, List<String>>? multiFiles,
  }) async {
    final form = FormData();
    (fields ?? {}).forEach((key, value) {
      if (value != null) form.fields.add(MapEntry(key, value.toString()));
    });
    for (final entry in (files ?? {}).entries) {
      form.files.add(MapEntry(entry.key, await MultipartFile.fromFile(entry.value, filename: entry.value.split(RegExp(r'[\\/]')).last)));
    }
    for (final entry in (multiFiles ?? {}).entries) {
      for (final filePath in entry.value) {
        form.files.add(MapEntry(entry.key, await MultipartFile.fromFile(filePath, filename: filePath.split(RegExp(r'[\\/]')).last)));
      }
    }
    return _request('POST', path, token: token, data: form);
  }

  Future<Map<String, dynamic>> _request(String method, String path, {String? token, dynamic data, Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method, headers: token == null || token.isEmpty ? null : {'Authorization': 'Bearer $token'}),
      );
      final body = response.data;
      if (body is Map<String, dynamic>) return body;
      return {'data': body};
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;
      String message = 'Something went wrong. Please try again.';
      if (data is Map && data['message'] != null) message = data['message'].toString();
      throw ApiException(message, statusCode: statusCode);
    }
  }
}
