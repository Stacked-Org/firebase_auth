import 'package:example/app/app.locator.dart';
import 'package:example/app/app.router.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_firebase_auth/stacked_firebase_auth.dart';
import 'package:stacked_services/stacked_services.dart';

class SecuredAreaViewModel extends BaseViewModel {
  final _authenticationService = locator<FirebaseAuthenticationService>();
  final _navigationService = locator<NavigationService>();

  bool get isAuthenticated => _authenticationService.hasUser;
  String get userName =>
      _authenticationService.currentUser?.displayName ?? 'No user name';

  Future logout() async {
    await _authenticationService.logout();
    await _navigationService.replaceWithStartupView();
  }
}
