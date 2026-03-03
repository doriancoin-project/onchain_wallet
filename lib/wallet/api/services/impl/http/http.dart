import 'dart:async';

import 'package:blockchain_utils/service/service.dart';
import 'package:blockchain_utils/utils/atomic/atomic.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/app/http/isolate/models/message.dart';
import 'package:on_chain_wallet/wallet/api/provider/core/provider.dart';
import 'package:on_chain_wallet/wallet/api/services/core/base_service.dart';
import 'package:on_chain_wallet/wallet/api/services/core/tracker.dart';
import 'package:on_chain_wallet/wallet/api/services/models/models.dart';

abstract class HTTPService<P extends APIProvider>
    with HttpImpl
    implements NetworkServiceProtocol<P> {
  HTTPService({this.timeout = const Duration(seconds: 30)});

  @override
  APPIsolate get isolate;
  @override
  ServiceProtocol get protocol => ServiceProtocol.http;
  @override
  final APIServiceTracker tracker = APIServiceTracker();
  final Duration timeout;

  final _lock = SafeAtomicLock();

  Future<HTTPCallerResponse> _callSynchronized<T>(
    Future<HTTPCallerResponse> Function() t, {
    List<int> allowStatus = const [200],
  }) async {
    if (requestTimeout == null) {
      return _onException<T>(t, allowStatus: allowStatus);
    }
    await _lock.run(() async {
      await Future.delayed(requestTimeout!);
    });
    return _onException<T>(t, allowStatus: allowStatus);
  }

  Future<BaseServiceResponse<T>> _callSynchronizedService<T>(
    Future<HTTPCallerResponse> Function() t, {
    List<int> allowStatus = const [200],
  }) async {
    if (requestTimeout == null) {
      return _onServiceException<T>(t, allowStatus: allowStatus);
    }
    await _lock.run(() async {
      await Future.delayed(requestTimeout!);
    });
    return _onServiceException<T>(t, allowStatus: allowStatus);
  }

  Duration? get requestTimeout => null;

  Uri _toUri(String uri) {
    return Uri.parse(uri);
  }

  @override
  void close() {}
  @override
  void dispose() {}
  Future<HTTPCallerResponse> providerPOST<T>(String url, Object? params,
      {List<int> allowStatus = const [200],
      Duration? timeout,
      Map<String, String>? headers,
      HTTPResponseType? responseType}) async {
    HTTPCallerResponse? response;
    try {
      final toUri = _toUri(url);
      final Map<String, String> requestHeaders = {
        'Content-Type': 'application/json',
        ...headers ?? {}
      };
      response = await _callSynchronized<T>(
        () async {
          return await serviceCaller.call(
              url: toUri,
              timeout: timeout ?? this.timeout,
              body: params,
              headers: requestHeaders,
              responseType: _detectTemplateType<T>(responseType: responseType),
              type: HTTPRequestType.post,
              isolate: isolate,
              authenticated: provider.auth);
        },
        allowStatus: allowStatus,
      );
      return response;
    } on ApiProviderException catch (e) {
      tracker.addRequest(
          ApiRequest(uri: url, error: e, identifier: provider.identifier));
      rethrow;
    } finally {
      if (response != null) {
        tracker.addRequest(ApiRequest(
          identifier: provider.identifier,
          uri: url,
        ));
      }
    }
  }

  Future<HTTPCallerResponse> providerGET<T>(String url,
      {List<int> allowStatus = const [200],
      Duration? timeout,
      Map<String, String>? headers,
      HTTPResponseType? responseType}) async {
    HTTPCallerResponse? response;

    try {
      final toUri = _toUri(url);

      final Map<String, String> requestHeaders = headers ?? {};
      response = await _callSynchronized<T>(() async {
        return await serviceCaller.call(
            url: toUri,
            timeout: timeout ?? this.timeout,
            headers: requestHeaders,
            responseType: _detectTemplateType<T>(responseType: responseType),
            type: HTTPRequestType.get,
            isolate: isolate,
            authenticated: provider.auth);
      }, allowStatus: allowStatus);
      return response;
    } on ApiProviderException catch (e) {
      tracker.addRequest(
          ApiRequest(uri: url, error: e, identifier: provider.identifier));
      rethrow;
    } finally {
      if (response != null) {
        tracker
            .addRequest(ApiRequest(uri: url, identifier: provider.identifier));
      }
    }
  }

  Future<BaseServiceResponse<T>> serviceRequest<T>(
      BaseServiceRequestParams request,
      {List<int> allowStatus = const [200],
      Uri? uri,
      Duration? timeout,
      HTTPResponseType? responseType,
      P? currentProvider}) async {
    BaseServiceResponse<T>? response;
    final toUri = uri ?? request.toUri(provider.callUrl);
    final ProviderAuthenticated? authenticated =
        currentProvider?.auth ?? provider.auth;
    try {
      final Map<String, String> headers = {
        if (request.type == RequestServiceType.post)
          'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...request.headers
      };
      final type = _detectTemplateType<T>(responseType: responseType);
      response = await _callSynchronizedService<T>(() async {
        return switch (request.type) {
          RequestServiceType.get => await serviceCaller.call(
              url: toUri,
              timeout: timeout ?? this.timeout,
              headers: headers,
              responseType: type,
              type: HTTPRequestType.get,
              isolate: isolate,
              authenticated: authenticated),
          RequestServiceType.post => await serviceCaller.call(
              url: toUri,
              timeout: timeout ?? this.timeout,
              headers: headers,
              responseType: type,
              body: request.body(),
              type: HTTPRequestType.post,
              isolate: isolate,
              authenticated: authenticated)
        };
      }, allowStatus: allowStatus);
      return response;
    } on ApiProviderException catch (e) {
      tracker.addRequest(ApiRequest(
          uri: toUri.toString(),
          error: e,
          identifier: currentProvider?.identifier ?? provider.identifier));
      rethrow;
    } finally {
      if (response != null) {
        tracker.addRequest(ApiRequest(
            uri: toUri.toString(),
            identifier: currentProvider?.identifier ?? provider.identifier));
      }
    }
  }

  Future<BaseServiceResponse<T>> _onServiceException<T>(
    Future<HTTPCallerResponse> Function() t, {
    List<int> allowStatus = const [200],
  }) async {
    try {
      final response = await t();
      if (allowStatus.isNotEmpty &&
          !allowStatus.contains(response.statusCode)) {
        appLogger.error(
            runtime: runtimeType,
            functionName: "_onServiceException",
            msg:
                "Failed ${response.statusCode}: ${response.error() ?? response.result}");
        throw ApiProviderException.fromException(
            statusCode: response.statusCode,
            message: response.error() ?? response.result);
      }
      return readServiceResponse<T>(response);
    } catch (e) {
      throw ApiProviderException.fromException(message: e);
    }
  }

  Future<HTTPCallerResponse> _onException<T>(
      Future<HTTPCallerResponse> Function() t,
      {List<int> allowStatus = const [200]}) async {
    try {
      final response = await t();
      if (allowStatus.isNotEmpty &&
          !allowStatus.contains(response.statusCode)) {
        throw ApiProviderException.fromException(
            statusCode: response.statusCode,
            message: response.error() ?? response.result);
      }
      return _readResponse<T>(response);
    } catch (e) {
      throw ApiProviderException.fromException(message: e);
    }
  }

  HTTPResponseType _detectTemplateType<T>({HTTPResponseType? responseType}) {
    if (responseType != null) return responseType;
    if (dynamic is T) return HTTPResponseType.json;
    if (<dynamic>[] is T) return HTTPResponseType.json;
    if (<String, dynamic>{} is T) {
      return HTTPResponseType.map;
    }
    if (<Map<String, dynamic>>[] is T) return HTTPResponseType.listOfMap;
    if (<int>[] is T) return HTTPResponseType.binary;
    switch (T) {
      case const (String):
        return HTTPResponseType.string;
      default:
        return HTTPResponseType.json;
    }
  }

  BaseServiceResponse<T> readServiceResponse<T>(HTTPCallerResponse response) {
    try {
      if (response.isSuccess) {
        return ServiceSuccessRespose(
            response: response.bodyAs<T>(), statusCode: response.statusCode);
      }
      return ServiceErrorResponse(
          error: response.bodyAs<String?>(), statusCode: response.statusCode);
    } catch (_) {
      throw ApiProviderExceptionConst.invalidRequestType;
    }
  }

  HTTPCallerResponse _readResponse<T>(HTTPCallerResponse response) {
    try {
      return HTTPCallerResponse(
          result: response.bodyAs<T>(),
          statusCode: response.statusCode,
          responseType: response.responseType);
    } catch (_) {
      throw ApiProviderExceptionConst.invalidRequestType;
    }
  }
}
