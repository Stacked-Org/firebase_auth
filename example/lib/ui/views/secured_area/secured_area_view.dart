import 'package:example/ui/common/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'secured_area_viewmodel.dart';

class SecuredAreaView extends StackedView<SecuredAreaViewModel> {
  const SecuredAreaView({super.key});

  @override
  Widget builder(
    BuildContext context,
    SecuredAreaViewModel viewModel,
    Widget? child,
  ) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Container(
        padding: const EdgeInsets.only(left: 25.0, right: 25.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Hello, STACKED!',
                style: TextStyle(
                  fontSize: 35,
                  fontWeight: FontWeight.w900,
                ),
              ),
              verticalSpaceMedium,
              Text(
                'Welcome in the secured zone, ${viewModel.userName}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              verticalSpaceLarge,
              MaterialButton(
                color: Colors.black,
                onPressed: viewModel.logout,
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  SecuredAreaViewModel viewModelBuilder(
    BuildContext context,
  ) =>
      SecuredAreaViewModel();
}
