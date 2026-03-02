import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:on_chain_bridge/platform_interface.dart';
import 'package:on_chain_wallet/app/core.dart';
import 'package:on_chain_wallet/crypto/doriancoin/doriancoin.dart';
import 'package:on_chain_wallet/future/future.dart';
import 'package:on_chain_wallet/future/router/page_router.dart';
import 'package:on_chain_wallet/future/state_managment/state_managment.dart';

void main() async {
  await _runApplication();
}

class APPHTTPConfig extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> _configDesktop(APPSetting setting) async {
  if (!PlatformInterface.appPlatform.isDesktop) return;
  await PlatformInterface.instance.desktop.init();
  await PlatformInterface.instance.desktop.waitUntilReadyToShow();
  // final path =
  //     await PlatformUtils.writeAssetToSupport(assetPath: APPConst.logoPath);
  // Logg.log("oh ${path}");
  // await PlatformInterface.instance.desktop.setIcon(path);

  await PlatformInterface.instance.desktop.setMaximumSize(const WidgetSize(
      width: APPConst.desktopAppWidth, height: APPConst.desktopAppHeight));
  if (setting.size?.devicePixelRatio != null) {
    final size = setting.size!;
    await PlatformInterface.instance.desktop
        .setBounds(pixelRatio: size.devicePixelRatio!, bounds: size);
  }
}

Future<APPSetting> _readSetting() async {
  final config = await PlatformInterface.instance.init(APPConst.applicationId);
  final query =
      await PlatformInterface.instance.readDb(APPDatabaseConst.appSettingQuery);
  return APPSetting.deserialize(config, bytes: query?.data);
}

Future<void> _runApplication() async {
  HttpOverrides.global = APPHTTPConfig();
  WidgetsFlutterBinding.ensureInitialized();
  DoriancoinNetwork.register();
  final setting = await _readSetting();
  await _configDesktop(setting);
  ThemeController.fromAppSetting(setting);
  runApp(StateRepository(child: MyBTC(setting: setting)));
}

class MyBTC extends StatelessWidget {
  const MyBTC({super.key, required this.setting});
  final APPSetting setting;

  @override
  Widget build(BuildContext context) {
    return StateBuilder<WalletProvider>(
      controller: () => WalletProvider(
          appSetting: setting,
          observer: StateRepository.walletObserver(context),
          navigatorKey: StateRepository.navigatorKey(context)),
      removable: false,
      stateId: StateConst.main,
      repositoryId: StateConst.main,
      builder: (m) {
        return MaterialApp(
            scaffoldMessengerKey: StateRepository.messengerKey(context),
            title: APPConst.name,
            scrollBehavior: AppScrollBehavior(PlatformInterface.appPlatform),
            builder: (context, child) {
              double? maxWidth;
              if (PlatformInterface.appPlatform.isDesktop) {
                maxWidth = APPConst.desktopAppWidth;
              }
              ThemeController.updatePrimary(context.theme);
              return MediaQuery(
                  data: context.mediaQuery
                      .copyWith(textScaler: const TextScaler.linear(1.0)),
                  child: Listener(
                    onPointerMove: (e) => m.onAppHover(),
                    onPointerDown: (e) => m.onAppHover(),
                    child: maxWidth == null
                        ? child!
                        : ConstraintsBoxView(maxWidth: maxWidth, child: child!),
                  ));
            },
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate
            ],
            theme: ThemeController.appTheme,
            darkTheme: ThemeController.appTheme,
            locale: ThemeController.materialLocale,
            onGenerateRoute: PageRouter.onGenerateRoute,
            initialRoute: PageRouter.home,
            navigatorObservers: [StateRepository.walletObserver(context)],
            showSemanticsDebugger: false,
            debugShowCheckedModeBanner: false,
            color: ThemeController.appTheme.colorScheme.primary,
            navigatorKey: StateRepository.navigatorKey(context));
      },
    );
  }
}
