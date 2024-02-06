import 'package:example/app/app.bottomsheets.dart';
import 'package:example/app/app.dialogs.dart';
import 'package:example/app/app.locator.dart';
import 'package:example/app/app.router.dart';
import 'package:example/ui/common/app_strings.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_firebase_auth/stacked_firebase_auth.dart';
import 'package:stacked_services/stacked_services.dart';

class HomeViewModel extends BaseViewModel {
  final _dialogService = locator<DialogService>();
  final _bottomSheetService = locator<BottomSheetService>();
  final _authenticationService = locator<FirebaseAuthenticationService>();
  final _navigationService = locator<NavigationService>();
  String? authError;

  void showDialog() {
    _dialogService.showCustomDialog(
      variant: DialogType.infoAlert,
      title: 'Stacked Rocks!',
      description: 'Give stacked INFINITE stars on Github',
    );
  }

  void showBottomSheet() {
    _bottomSheetService.showCustomSheet(
      variant: BottomSheetType.notice,
      title: ksHomeBottomSheetTitle,
      description: ksHomeBottomSheetDescription,
    );
  }

  Future signInWithFacebook() async {
    clearErrorMessage();
    final authResponse = await _authenticationService.signInWithFacebook();

    if (!authResponse.hasError) {
      return await _navigationService.replaceWithSecuredAreaView();
    }

    authError = authResponse.errorMessage;
    rebuildUi();
  }

  Future signInWithGoogle() async {
    clearErrorMessage();
    final authResponse = await _authenticationService.signInWithGoogle();

    if (!authResponse.hasError) {
      return await _navigationService.replaceWithSecuredAreaView();
    }

    authError = authResponse.errorMessage;
    rebuildUi();
  }

  Future signInWithApple() async {
    clearErrorMessage();
    final authResponse = await _authenticationService.signInWithApple(
      appleRedirectUri:
          "https://{your-firebase-project-id}.firebaseapp.com/__/auth/handler",
      appleClientId: "{your-apple-service-id}",
    );

    if (!authResponse.hasError) {
      return await _navigationService.replaceWithSecuredAreaView();
    }

    authError = authResponse.errorMessage;
    rebuildUi();
  }

  void clearErrorMessage() {
    authError = null;
    rebuildUi();
  }
}
