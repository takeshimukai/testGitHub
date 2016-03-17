/*///////////////////////////////////////////////////////////////////
 GNU PUBLIC LICENSE - The copying permission statement
 --------------------------------------------------------------------
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 ///////////////////////////////////////////////////////////////////*/

//
//  OtherViewController.m
//  DataMobile
//
//  Created by DataMobile on 13-04-11.
//  Copyright (c) 2013 MML-Concordia. All rights reserved.
//
// Modified by MUKAI Takeshi in 2015-10

#import "OtherViewController.h"
#import "AlertViewManager.h"

@interface OtherViewController ()

@end

@implementation OtherViewController

@synthesize alertManager;
@synthesize scrollView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (IBAction)backButtonAction:(UIBarButtonItem *)sender {
    [[self presentingViewController]dismissViewControllerAnimated:YES
                                                       completion:NULL];
}

- (IBAction)sendFeedBackButtonTouchUpInside:(id)sender
{
    if([MFMailComposeViewController canSendMail])
    {
        // Creating new Mail
        MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
        mc.mailComposeDelegate = self;
        [mc setToRecipients:[[NSArray alloc] initWithObjects:@"zedpatterson@gmail.com", nil]];  // from Concordia ver
        [mc setSubject:NSLocalizedString(@"OTHER_MAIL_FEEDBACK_TITLE", @"")];
        
        // Present mail view controller on screen
        [self presentViewController:mc animated:YES completion:NULL];
    }
    else
    {
        [[alertManager createOkAlert:NSLocalizedString(@"OTHER_MAIL_ACCOUNT_ERR_MSG_TITLE", @"")
                         withMessage:NSLocalizedString(@"OTHER_MAIL_FEEDBACK_ERR_MSG_BODY", @"")
                              setTag:0] show];
    }
}

- (IBAction)emailButtonTouchUpInside:(id)sender
{
    if([MFMailComposeViewController canSendMail])
    {
        // Creating new Mail
        MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
        mc.mailComposeDelegate = self;
        [mc setSubject:NSLocalizedString(@"OTHER_MAIL_FORM_ACCOUNT_MSG_TITLE", @"")];
        [mc setMessageBody:NSLocalizedString(@"OTHER_MAIL_FORM_ACCOUNT_MSG_BODY", @"") isHTML:NO];
        
        NSString *consentFormPath = [[NSBundle mainBundle] pathForResource:@"Consent_Form"
                                                                    ofType:@"pdf"];  // from Concordia ver
        NSData* consentFormData = [[NSData alloc] initWithContentsOfFile:consentFormPath];
        [mc addAttachmentData:consentFormData
                     mimeType:@"application/pdf"
                     fileName:@"Consent_Form.pdf"];
        
        // Present mail view controller on screen
        [self presentViewController:mc animated:YES completion:NULL];
    }
    else
    {
        [[alertManager createOkAlert:NSLocalizedString(@"OTHER_MAIL_ACCOUNT_ERR_MSG_TITLE", @"")
                         withMessage:NSLocalizedString(@"OTHER_MAIL_FORM_ACCOUNT_ERR_MSG_BODY", @"")
                              setTag:0] show];
    }
}

// Modified by MUKAI Takeshi in 2015-10
- (IBAction)sendAccessDataButtonTouchUpInside:(id)sender
{
    if([MFMailComposeViewController canSendMail])
    {
        // Creating new Mail
        MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
        mc.mailComposeDelegate = self;
        [mc setToRecipients:[[NSArray alloc] initWithObjects:@"zachary.patterson@concordia.ca", nil]];
        [mc setSubject:NSLocalizedString(@"OTHER_MAIL_ACCESS_DATA_TITLE", @"")];
        
        // Present mail view controller on screen
        [self presentViewController:mc animated:YES completion:NULL];
    }
    else
    {
        [[alertManager createOkAlert:NSLocalizedString(@"OTHER_MAIL_ACCOUNT_ERR_MSG_TITLE", @"")
                         withMessage:NSLocalizedString(@"OTHER_MAIL_ACCESS_DATA_ERR_MSG_BODY", @"")
                              setTag:0] show];
    }
}


#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    switch (result)
    {
        case MFMailComposeResultCancelled:
            NSLog(@"Mail cancelled");
            break;
        case MFMailComposeResultSaved:
            NSLog(@"Mail saved");
            break;
        case MFMailComposeResultSent:
            break;
            
        case MFMailComposeResultFailed:
            NSLog(@"Mail sent failure: %@", [error localizedDescription]);
            break;
        default:
            break;
    }
    
    // Close the Mail Interface
    [self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // For being alerted when the user uses "No"
    alertManager = [[AlertViewManager alloc] init];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
