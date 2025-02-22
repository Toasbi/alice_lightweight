import 'package:alice_lightweight/core/alice_utils.dart';
import 'package:alice_lightweight/model/alice_http_call.dart';
import 'package:alice_lightweight/model/alice_http_error.dart';
import 'package:alice_lightweight/model/alice_http_response.dart';
import 'package:alice_lightweight/ui/page/alice_calls_list_screen.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class AliceCore {
  /// Should inspector use dark theme
  final bool darkTheme;

  /// Rx subject which contains all intercepted http calls
  final BehaviorSubject<List<AliceHttpCall>> callsSubject = BehaviorSubject.seeded([]);

  ///Max number of calls that are stored in memory. When count is reached, FIFO
  ///method queue will be used to remove elements.
  final int maxCallsCount;

  ///Directionality of app. If null then directionality of context will be used.
  final TextDirection? directionality;

  ///Flag used to show/hide share button
  final bool? showShareButton;

  GlobalKey<NavigatorState>? navigatorKey;
  Brightness _brightness = Brightness.light;
  bool _isInspectorOpened = false;

  /// Creates alice core instance
  AliceCore(
    this.navigatorKey, {
    required this.darkTheme,
    required this.maxCallsCount,
    this.directionality,
    this.showShareButton,
  }) {
    _brightness = darkTheme ? Brightness.dark : Brightness.light;
  }

  /// Dispose subjects and subscriptions
  void dispose() {
    callsSubject.close();
  }

  /// Get currently used brightness
  Brightness get brightness => _brightness;

  /// Opens Http calls inspector. This will navigate user to the new fullscreen
  /// page where all listened http calls can be viewed.
  void navigateToCallListScreen() {
    final context = getContext();
    if (context == null) {
      AliceUtils.log(
        "Cant start Alice HTTP Inspector. Please add NavigatorKey to your application",
      );
      return;
    }
    if (!_isInspectorOpened) {
      _isInspectorOpened = true;
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (context) => AliceCallsListScreen(this),
        ),
      ).then((onValue) => _isInspectorOpened = false);
    }
  }

  /// Get context from navigator key. Used to open inspector route.
  BuildContext? getContext() => navigatorKey?.currentState?.overlay?.context;

  /// Add alice http call to calls subject
  void addCall(AliceHttpCall call) {
    final callsCount = callsSubject.value.length;
    if (callsCount >= maxCallsCount) {
      final originalCalls = callsSubject.value;
      final calls = List<AliceHttpCall>.from(originalCalls);
      calls.sort(
        (call1, call2) => call1.createdTime.compareTo(call2.createdTime),
      );
      final indexToReplace = originalCalls.indexOf(calls.first);
      originalCalls[indexToReplace] = call;

      callsSubject.add(originalCalls);
    } else {
      callsSubject.add([...callsSubject.value, call]);
    }
  }

  /// Add error to existing alice http call
  void addError(AliceHttpError error, int requestId) {
    final AliceHttpCall? selectedCall = _selectCall(requestId);

    if (selectedCall == null) {
      AliceUtils.log("Selected call is null");
      return;
    }

    selectedCall.error = error;
    callsSubject.add([...callsSubject.value]);
  }

  /// Add response to existing alice http call
  void addResponse(AliceHttpResponse response, int requestId) {
    final AliceHttpCall? selectedCall = _selectCall(requestId);

    if (selectedCall == null) {
      AliceUtils.log("Selected call is null");
      return;
    }
    selectedCall.loading = false;
    selectedCall.response = response;
    selectedCall.duration = response.time.millisecondsSinceEpoch -
        selectedCall.request!.time.millisecondsSinceEpoch;

    callsSubject.add([...callsSubject.value]);
  }

  /// Add alice http call to calls subject
  void addHttpCall(AliceHttpCall aliceHttpCall) {
    assert(aliceHttpCall.request != null, "Http call request can't be null");
    assert(aliceHttpCall.response != null, "Http call response can't be null");
    callsSubject.add([...callsSubject.value, aliceHttpCall]);
  }

  /// Remove all calls from calls subject
  void removeCalls() {
    callsSubject.add([]);
  }

  AliceHttpCall? _selectCall(int requestId) =>
      callsSubject.value.firstWhereOrNull((call) => call.id == requestId);
}
