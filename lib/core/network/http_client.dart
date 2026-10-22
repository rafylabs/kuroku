import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

class KurokuHttpClient {
  static final KurokuHttpClient instance = KurokuHttpClient._internal();
  late final Dio dio;
  late final CookieJar cookieJar;

  KurokuHttpClient._internal() {
    cookieJar = CookieJar();
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9,id;q=0.8',
        },
      ),
    );

    dio.interceptors.add(CookieManager(cookieJar));
  }

  Future<Response<T>> get<T>(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    ResponseType responseType = ResponseType.json,
  }) async {
    return await dio.get<T>(
      url,
      queryParameters: queryParameters,
      options: Options(
        headers: headers,
        responseType: responseType,
      ),
    );
  }

  Future<Response<T>> post<T>(
    String url, {
    dynamic data,
    Map<String, String>? headers,
    ResponseType responseType = ResponseType.json,
  }) async {
    return await dio.post<T>(
      url,
      data: data,
      options: Options(
        headers: headers,
        responseType: responseType,
      ),
    );
  }
}
