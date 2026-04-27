//
// Generated file. Do not edit.
// This file is generated from template in file `flutter_tools/lib/src/flutter_plugins.dart`.
//

// @dart = 3.3

import 'dart:io'; // flutter_ignore: dart_io_import.
import 'package:flutter_blue_plus_android/flutter_blue_plus_android.dart' as flutter_blue_plus_android;
import 'package:path_provider_android/path_provider_android.dart' as path_provider_android;
import 'package:shared_preferences_android/shared_preferences_android.dart' as shared_preferences_android;
import 'package:webview_flutter_android/webview_flutter_android.dart' as webview_flutter_android;
import 'package:flutter_blue_plus_darwin/flutter_blue_plus_darwin.dart' as flutter_blue_plus_darwin;
import 'package:path_provider_foundation/path_provider_foundation.dart' as path_provider_foundation;
import 'package:shared_preferences_foundation/shared_preferences_foundation.dart' as shared_preferences_foundation;
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart' as webview_flutter_wkwebview;
import 'package:flutter_blue_plus_darwin/flutter_blue_plus_darwin.dart' as flutter_blue_plus_darwin;
import 'package:path_provider_foundation/path_provider_foundation.dart' as path_provider_foundation;
import 'package:shared_preferences_foundation/shared_preferences_foundation.dart' as shared_preferences_foundation;
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart' as webview_flutter_wkwebview;

@pragma('vm:entry-point')
class _PluginRegistrant {

  @pragma('vm:entry-point')
  static void register() {
    if (Platform.isAndroid) {
      try {
        flutter_blue_plus_android.FlutterBluePlusAndroid.registerWith();
      } catch (err) {
        print(
          '`flutter_blue_plus_android` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        path_provider_android.PathProviderAndroid.registerWith();
      } catch (err) {
        print(
          '`path_provider_android` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        shared_preferences_android.SharedPreferencesAndroid.registerWith();
      } catch (err) {
        print(
          '`shared_preferences_android` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        webview_flutter_android.AndroidWebViewPlatform.registerWith();
      } catch (err) {
        print(
          '`webview_flutter_android` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isIOS) {
      try {
        flutter_blue_plus_darwin.FlutterBluePlusDarwin.registerWith();
      } catch (err) {
        print(
          '`flutter_blue_plus_darwin` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        path_provider_foundation.PathProviderFoundation.registerWith();
      } catch (err) {
        print(
          '`path_provider_foundation` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        shared_preferences_foundation.SharedPreferencesFoundation.registerWith();
      } catch (err) {
        print(
          '`shared_preferences_foundation` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        webview_flutter_wkwebview.WebKitWebViewPlatform.registerWith();
      } catch (err) {
        print(
          '`webview_flutter_wkwebview` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isLinux) {
    } else if (Platform.isMacOS) {
      try {
        flutter_blue_plus_darwin.FlutterBluePlusDarwin.registerWith();
      } catch (err) {
        print(
          '`flutter_blue_plus_darwin` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        path_provider_foundation.PathProviderFoundation.registerWith();
      } catch (err) {
        print(
          '`path_provider_foundation` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        shared_preferences_foundation.SharedPreferencesFoundation.registerWith();
      } catch (err) {
        print(
          '`shared_preferences_foundation` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        webview_flutter_wkwebview.WebKitWebViewPlatform.registerWith();
      } catch (err) {
        print(
          '`webview_flutter_wkwebview` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isWindows) {
    }
  }
}
