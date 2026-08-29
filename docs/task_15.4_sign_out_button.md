# Task 15.4: Add Sign-Out Button to App Bar

## Overview

This task implements a sign-out button in the Notes List Screen app bar, allowing users to log out of the application. The implementation includes a confirmation dialog, proper error handling, and navigation back to the login screen.

## Implementation Details

### Changes Made

#### 1. NotesListScreen (`lib/screens/notes_list_screen.dart`)

**Added PopupMenuButton to App Bar:**
- Added a `PopupMenuButton` with a vertical ellipsis icon (`Icons.more_vert`)
- Menu contains a "Sign out" option with logout icon
- Positioned after the sync indicator in the app bar actions

**Added Sign-Out Handler Method:**
- `_handleSignOut()` method handles the complete sign-out flow
- Shows confirmation dialog before signing out
- Displays loading indicator during sign-out process
- Calls `AuthService.signOut()` which clears credentials and local notes
- Navigates to login screen after successful sign-out
- Shows error snackbar if sign-out fails

**Updated Documentation:**
- Updated class documentation to include Requirement 2.6
- Added comprehensive method documentation for `_handleSignOut()`

### Features Implemented

1. **Confirmation Dialog:**
   - Warns user that all local notes will be cleared
   - Provides "Cancel" and "Sign out" buttons
   - Prevents accidental sign-outs

2. **Loading Indicator:**
   - Shows "Signing out..." snackbar during the process
   - Provides visual feedback to the user

3. **Error Handling:**
   - Catches exceptions during sign-out
   - Displays descriptive error messages
   - Allows user to retry if needed

4. **Navigation:**
   - Automatically navigates to login screen after successful sign-out
   - Uses `pushReplacementNamed` to prevent back navigation

### Testing

#### Widget Tests Added (`test/widget/notes_list_screen_test.dart`)

**MockAuthService Updates:**
- Added `signOutCallCount` to track sign-out calls
- Added `signOutException` to simulate errors
- Implemented `signOut()` method that clears current user

**Test Cases:**
1. **displays sign-out button in app bar menu** - Verifies PopupMenuButton exists
2. **tapping menu button shows sign-out option** - Verifies menu items appear
3. **tapping sign-out shows confirmation dialog** - Verifies dialog with warning message
4. **canceling sign-out dialog does not sign out** - Verifies cancel functionality
5. **confirming sign-out calls AuthService.signOut()** - Verifies service integration
6. **successful sign-out navigates to login screen** - Verifies navigation
7. **sign-out shows loading indicator** - Verifies loading state
8. **sign-out error shows error snackbar** - Verifies error handling

All tests pass successfully.

## Requirements Validated

### Requirement 2.6: Sign Out and Clear Data
- ✅ User can sign out via app bar menu
- ✅ Sign-out calls `AuthService.signOut()`
- ✅ Credentials are cleared (handled by AuthService)
- ✅ Local notes are cleared (handled by AuthService)
- ✅ User is navigated to login screen
- ✅ Confirmation dialog prevents accidental sign-outs
- ✅ Error handling for sign-out failures

## User Experience

1. User taps the vertical ellipsis icon in the app bar
2. Menu appears with "Sign out" option
3. User taps "Sign out"
4. Confirmation dialog appears with warning about clearing local notes
5. User can cancel or confirm
6. If confirmed:
   - Loading indicator shows "Signing out..."
   - AuthService clears credentials and local notes
   - User is navigated to login screen
7. If error occurs:
   - Error snackbar displays with descriptive message
   - User remains on notes list screen

## Code Quality

- ✅ Follows existing code patterns in the project
- ✅ Comprehensive documentation and comments
- ✅ Proper error handling with user-friendly messages
- ✅ Context-mounted checks to prevent memory leaks
- ✅ Async/await best practices
- ✅ Widget tests for all functionality
- ✅ No diagnostic issues

## Integration

The sign-out button integrates seamlessly with:
- **AuthService**: Calls `signOut()` method which handles credential and data clearing
- **Navigation**: Uses existing route structure (`/login`)
- **UI**: Matches existing app bar design with sync indicator
- **Error Handling**: Consistent with other error handling in the app

## Future Enhancements

Potential improvements for future tasks:
- Add option to sync before signing out
- Add "Sign out from all devices" option
- Add sign-out confirmation via email
- Add option to export notes before signing out
