import 'package:bungie_api/models/user_membership_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:little_light/exceptions/exception_handler.dart';
import 'package:little_light/screens/main.screen.dart';
import 'package:little_light/services/auth/auth.service.dart';
import 'package:little_light/services/bungie_api/bungie_api.service.dart';
import 'package:little_light/services/manifest/manifest.service.dart';
import 'package:little_light/services/profile/profile.service.dart';
import 'package:little_light/services/translate/translate.service.dart';
import 'package:little_light/widgets/exceptions/exception_dialog.dart';
import 'package:little_light/widgets/initial_page/download_manifest.widget.dart';
import 'package:little_light/widgets/initial_page/login_widget.dart';
import 'package:little_light/widgets/initial_page/select_language.widget.dart';
import 'package:little_light/widgets/initial_page/select_platform.widget.dart';
import 'package:little_light/widgets/layouts/floating_content_layout.dart';

class InitialScreen extends StatefulWidget {
  final BungieApiService apiService = new BungieApiService();
  final AuthService auth = new AuthService();
  final ManifestService manifest = new ManifestService();
  final ProfileService profile = new ProfileService();
  final TranslateService translate = new TranslateService();
  final bool forceChangeLanguage;
  final bool forceLogin;
  final bool forceSelectMembership;

  InitialScreen(
      {Key key,
      this.forceChangeLanguage = false,
      this.forceLogin = false,
      this.forceSelectMembership = false})
      : super(key: key);

  @override
  InitialScreenState createState() => new InitialScreenState();
}

class InitialScreenState extends FloatingContentState<InitialScreen> {
  bool forceReauth = false;
  @override
  void initState() {
    if(debugDefaultTargetPlatformOverride != TargetPlatform.fuchsia){
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark));
    }
    super.initState();
    checkLanguage();
  }

  Future checkLanguage() async {
    String selectedLanguage = await widget.translate.getLanguage();
    bool hasSelectedLanguage = selectedLanguage != null;
    if (hasSelectedLanguage && !widget.forceChangeLanguage) {
      checkManifest();
    } else {
      showSelectLanguage();
    }
  }

  showSelectLanguage() async {
    List<String> availableLanguages =
        await widget.manifest.getAvailableLanguages();
    SelectLanguageWidget childWidget = SelectLanguageWidget(
      availableLanguages: availableLanguages,
      onChange: (language) {
        changeTitleLanguage(language);
      },
      onSelect: (language) {
        this.checkManifest();
      },
    );
    this.changeContent(childWidget, childWidget.title);
  }

  checkManifest() async {
    bool needsUpdate = await widget.manifest.needsUpdate();
    if (needsUpdate) {
      showDownloadManifest();
    } else {
      checkLogin();
    }
  }

  showDownloadManifest() async {
    String language = await widget.translate.getLanguage();
    DownloadManifestWidget screen = new DownloadManifestWidget(
      selectedLanguage: language,
      onFinish: () {
        checkLogin();
      },
    );
    this.changeContent(screen, screen.title);
  }

  checkLogin() async {
    var authCode = await widget.auth.checkAuthorizationCode();
    if (authCode != null) {
      this.authCode(authCode);
      return;
    }
    SavedToken token = await widget.auth.getToken();
    bool skippedLogin = await widget.auth.getSkippedLogin();
    if ((token == null && !skippedLogin) || widget.forceLogin || forceReauth) {
      showLogin();
    } else {
      checkMembership();
    }
  }

  showLogin() {
    LoginWidget loginWidget = new LoginWidget(
      forceReauth: widget.forceLogin || forceReauth,
      onSkip: () {
        widget.auth.skipLogin();
        goForward();
      },
      onLogin: (code) {
        authCode(code);
      },
    );
    this.changeContent(loginWidget, loginWidget.title);
  }

  authCode(String code) async {
    this.changeContent(null, "");
    try {
      await widget.auth.requestToken(code);
      checkMembership();
    } catch (e, stackTrace) {
      showDialog(
          context: context,
          builder: (context) => ExceptionDialog(
                context,
                e,
                onDismiss: (label) {
                  if (label == "Login") {
                    this.forceReauth = true;
                    showLogin();
                  }
                },
              ));
      ExceptionHandler().handleException(e, stackTrace);
    }
  }

  checkMembership() async {
    bool skipped = await widget.auth.getSkippedLogin();
    if (skipped) {
      return goForward();
    }
    SavedMembership membership = await widget.auth.getMembership();
    if (membership?.selectedMembership == null ||
        widget.forceSelectMembership) {
      return showSelectMembership();
    }
    ExceptionHandler.setSentryUserInfo(
        membership.selectedMembership.membershipId,
        membership.selectedMembership.displayName,
        membership.selectedMembership.membershipType);
    return loadProfile();
  }

  showSelectMembership() async {
    this.changeContent(null, null);
    UserMembershipData membershipData =
        await this.widget.apiService.getMemberships();
    SelectPlatformWidget widget = SelectPlatformWidget(
        membershipData: membershipData,
        onSelect: (int membershipType) async {
          if (membershipType == null) {
            this.forceReauth = true;
            this.showLogin();
            return;
          }
          await this.widget.auth.saveMembership(membershipData, membershipType);
          loadProfile();
        });
    this.changeContent(widget, widget.title);
  }

  loadProfile() async {
    bool skipped = await widget.auth.getSkippedLogin();
    if (skipped) {
      goForward();
      return;
    }
    this.changeContent(null, null);
    await widget.profile.loadFromCache();
    this.goForward();
  }

  goForward() {
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainScreen(),
        ));
  }
}
