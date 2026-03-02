import 'package:on_chain_wallet/app/models/models/image.dart';

class APPConst {
  static const String assetWebviewScript = "assets/webview/script.js";
  static const String logoPath = "assets/image/wallet.png";
  static const String assetWebviewPageScript = "assets/webview/script_page.js";
  static final APPImage logo = APPImage.local("assets/image/wallet.png");
  static final APPImage wc = APPImage.local("assets/image/wc.png");
  static final APPImage telegramLogo = APPImage.local("assets/image/t.png");
  static final APPImage githubLogo = APPImage.local("assets/image/g.png");
  static final APPImage dsv = APPImage.local("assets/image/dsv.png");
  static final APPImage ltc = APPImage.local("assets/image/ltc.png");
  static final APPImage bch = APPImage.local("assets/image/bch.png");
  static final APPImage btc = APPImage.local("assets/image/btc.png");
  static const String name = "Doriancoin Wallet";
  static const String applicationId = "com.mrtnetwork.on_chain_wallet";
  static const String authenticateReason = "Authenticate to proceed";
  static const Duration animationDuraion = Duration(milliseconds: 400);
  static const Duration milliseconds100 = Duration(milliseconds: 100);
  static const Duration milliseconds200 = Duration(milliseconds: 200);
  static const Duration oneSecoundDuration = Duration(seconds: 1);
  static const Duration twoSecoundDuration = Duration(seconds: 2);
  static const Duration tenSecoundDuration = Duration(seconds: 10);
  static const Duration futureTimeout = Duration(seconds: 10);

  static const double double80 = 80;
  static const double double40 = 40;
  static const double double20 = 20;
  static const double iconSize = 24;
  static const double smallIconSize = 12;
  static const double largeIconSize = 80;
  static const double tooltipConstrainedWidth = 300;
  static const double dialogWidth = 650;
  static const double maxViewWidth = 650;
  static const double maxDialogHeight = 600;
  static const double maxTextFieldWidth = 400;
  static const double qrCodeWidth = 300;
  static const int maxNameLength = 20;
  static final RegExp accountNameRegExp = RegExp(r'^[^\n]{0,20}$');
  static final RegExp keyNameRegex = RegExp(r'^[^\n]{0,20}$');
  static final RegExp hex32Bytes = RegExp(r'^(0x)?[0-9a-fA-F]{64}$');
  static final hrpRegex = RegExp(r'^[a-z][a-z0-9]*$');
  static const double circleRadius25 = 25;
  static const double circleRadius12 = 12.5;
  static const double elevation = 2;
  static const double desktopAppWidth = 1200;
  static const double desktopAppHeight = 768;
  static const double naviationRailWidth = 80;
  static const String exampleBase58 = "sEd7FSsSXz9CGy....";
  static const String exampleBase32 = "GD2YLIOLNVQXNA....";
  static const String exampleHex = "0xa3f1df47";

  static const String exampleAuthenticatedHeader = "Authorization";
  static const String exampleAuthenticatedQuery = "api_key";
  static const String exampleDouble = "0.0025";

  static const String exampleAuthenticatedHeaderValue =
      "Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==";
  static const String exampleAuthenticatedQueryValue = "api_key";

  static const String exampleAuthenticatedDigestAuthRealm = "monero-rpc";
  static const String exampleChannelId = "channel-1441";
  static const int defaultDecimalPlaces = 8;

  static const int maximumHeaderValue = 400;

  static const double largeCircleRadius = 60;
  static const double largeCircleRadius120 = 120;

  static const double disabledOpacity = 0.3;
  static const double defaultOpacity = 1;
}
