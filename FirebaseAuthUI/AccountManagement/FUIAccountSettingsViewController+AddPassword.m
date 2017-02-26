//
//  Copyright (c) 2017 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FUIAccountSettingsViewController+Internal.h"

#import "FUIAuthStrings.h"
#import "FUIAuth_Internal.h"
#import "FUIStaticContentTableViewController.h"
#import <FirebaseAuth/FirebaseAuth.h>
#import <FirebaseCore/FirebaseCore.h>

@implementation FUIAccountSettingsViewController (AddPassword)

- (void)showAddPasswordDialog {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:@"Verify it's you"
                                          message:@"To add password to your account, you will need to sign in again."
                                   preferredStyle:UIAlertControllerStyleAlert];

  for (id<FIRUserInfo> provider in self.auth.currentUser.providerData) {
    UIAlertAction* action = [UIAlertAction
                                actionWithTitle:provider.providerID
                                style:UIAlertActionStyleDefault
                                handler:^(UIAlertAction * _Nonnull action) {
                                  [self signInWithProviderUI:provider];
                                }];
    [alert addAction:action];
  }
  UIAlertAction* closeButton = [UIAlertAction
                                    actionWithTitle:[FUIAuthStrings cancel]
                                    style:UIAlertActionStyleDefault
                                    handler:nil];
  [alert addAction:closeButton];
  [self presentViewController:alert animated:YES completion:nil];

}

- (void)showAddPasswordWithCredential:(FIRAuthCredential *_Nullable)credential {
  __block FUIStaticContentTableViewCell *passwordCell =
      [FUIStaticContentTableViewCell cellWithTitle:[FUIAuthStrings password]
                                            action:nil
                                              type:FUIStaticContentTableViewCellTypePassword];
  FUIStaticContentTableViewContent *contents =
    [FUIStaticContentTableViewContent contentWithSections:@[
      [FUIStaticContentTableViewSection sectionWithTitle:nil
                                                   cells:@[passwordCell]],
    ]];


  UIViewController *controller =
      [[FUIStaticContentTableViewController alloc] initWithAuthUI:self.authUI
                                                         contents:contents nextTitle:@"Save"
                                                       nextAction:^{
        [self onSavePassword:passwordCell.value withCredential:credential];
      }];
  controller.title = @"Add password";
  [self pushViewController:controller];

}

- (void)signInWithProviderUI:(id<FIRUserInfo>)provider {

  id providerUI;
  for (id<FUIAuthProvider> authProvider in self.authUI.providers) {
    if ([provider.providerID isEqualToString:authProvider.providerID]) {
      providerUI = authProvider;
      break;
    }
  }

  if (!providerUI) {
    // TODO: Show alert or print error
    NSLog(@"Can't find provider for %@", provider.providerID);
    return;
  }

  [self incrementActivity];
  // Sign out first to make sure sign in starts with a clean state.
  [providerUI signOut];
  [providerUI signInWithEmail:self.auth.currentUser.email
     presentingViewController:self
                   completion:^(FIRAuthCredential *_Nullable credential,
                                NSError *_Nullable error) {
                     if (error) {
                       [self decrementActivity];

                       if (error.code == FUIAuthErrorCodeUserCancelledSignIn) {
                         // User cancelled sign in, Do nothing.
                         return;
                       }

// TODO: Shoul we do anything here?
//                       [self.navigationController dismissViewControllerAnimated:YES completion:^{
//                         [self.authUI invokeResultCallbackWithUser:nil error:error];
//                       }];
                       return;
                     }


                     FIRAuth *secondAuth = [self createFIRAuth];
                     [secondAuth signInWithCredential:credential
                                          completion:^(FIRUser *_Nullable user, NSError *_Nullable error) {
                                            if (error && error.code == FIRAuthErrorCodeEmailAlreadyInUse) {
                                            // TODO: Shoul we do anything here? It's not possible
//                                              NSString *email = error.userInfo[kErrorUserInfoEmailKey];
//                                              [self handleAccountLinkingForEmail:email newCredential:credential];
                                              return;
                                            }
                                            [self decrementActivity];
                                            if ([user.email isEqualToString:self.auth.currentUser.email]) {
                                              [self showAddPasswordWithCredential:credential];
                                            } else {
                                              [self showAlertWithMessage:@"Emails don't match"];
                                            }
                                            // TODO: delete second FIRAuuth
//                                            [secondAuth deleteApp:nil];
                                          }];
                   }];
}

- (FIRAuth *)createFIRAuth {
  // TODO: Use constant for app name
  NSString *secondAppName = @"as_second_fir_app";
  FIRApp *app = [FIRApp appNamed:secondAppName];
  if (!app) {
    [FIRApp configureWithName:secondAppName options:[FIRApp defaultApp].options];
    app = [FIRApp appNamed:secondAppName];
  }
  return [FIRAuth authWithApp:app];
}


- (void)onSavePassword:(NSString *)passwrod withCredential:(FIRAuthCredential *_Nullable)credential {
  if (!passwrod.length) {
    [self showAlertWithMessage:@"Short passwords are easy to guess"];
  } else {
    NSLog(@"%s %@", __FUNCTION__, passwrod);
    [self linkAccount:passwrod withCredential:credential];

  }
}

- (void)linkAccount:(NSString *)password withCredential:(FIRAuthCredential *_Nullable)credential {
  [self incrementActivity];
//  [self.auth.currentUser updatePassword:password completion:^(NSError * _Nullable error) {
//    [self decrementActivity];
//    NSLog(@"updatePassword error %@", error);
//  }];

//  [self.auth signInWithEmail:self.auth.currentUser.email
//                    password:password
//                  completion:^(FIRUser *_Nullable user, NSError *_Nullable error) {
//                    if (error) {
//                      [self decrementActivity];
//
//                      [self showAlertWithMessage:[FUIAuthStrings wrongPasswordError]];
//                      return;
//                    }
//
//                    [user linkWithCredential:credential completion:^(FIRUser * _Nullable user,
//                                                                         NSError * _Nullable error) {
//                      [self decrementActivity];
//
//                      // Ignore any error (shouldn't happen) and treat the user as successfully signed in.
//                      [self.navigationController dismissViewControllerAnimated:YES completion:^{
//                        [self.authUI invokeResultCallbackWithUser:user error:nil];
//                      }];
//                    }];
//                  }];
//

  [self.auth createUserWithEmail:self.auth.currentUser.email
                        password:password
                      completion:^(FIRUser *_Nullable user, NSError *_Nullable error) {
    if (error) {
      [self decrementActivity];

      [self finishSignUpWithUser:nil error:error];
      return;
    }

    [user linkWithCredential:credential completion:^(FIRUser * _Nullable user,
                                                         NSError * _Nullable error) {
      [self decrementActivity];

      // Ignore any error (shouldn't happen) and treat the user as successfully signed in.
//      [self.navigationController dismissViewControllerAnimated:YES completion:^{
//        [self.authUI invokeResultCallbackWithUser:user error:nil];
//      }];
      if (error) {
        [self finishSignUpWithUser:nil error:error];
        return;
      }
      [self finishSignUpWithUser:user error:nil];

    }];


//    FIRUserProfileChangeRequest *request = [user profileChangeRequest];
//    request.displayName = username;
//    [request commitChangesWithCompletion:^(NSError *_Nullable error) {
//      [self decrementActivity];
//
//      if (error) {
//        [self finishSignUpWithUser:nil error:error];
//        return;
//      }
//      [self finishSignUpWithUser:user error:nil];
//    }];
  }];

}


@end