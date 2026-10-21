#import "ChiaKeySecureInputWatch.h"

static void Check(BOOL condition, NSString *message) {
  if (!condition) {
    NSLog(@"FAIL: %@", message);
    exit(1);
  }
}

static NSString *const kLoginwindowPath =
    @"/System/Library/CoreServices/loginwindow.app/Contents/MacOS/loginwindow";

static ChiaKeySecureInputSession Session(pid_t holder, BOOL locked,
                                         BOOL onConsole) {
  ChiaKeySecureInputSession session = {holder, locked, onConsole};
  return session;
}

static void TestSessionDictionaryParsing(void) {
  ChiaKeySecureInputSession empty =
      ChiaKeySecureInputSessionFromDictionary([NSDictionary dictionary]);
  Check(empty.holderPID == 0, @"no secure input key means nobody holds it");
  Check(!empty.screenLocked, @"no lock key means unlocked");
  Check(!empty.onConsole, @"no console key means not on console");

  NSDictionary *held = [NSDictionary
      dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:1633],
                                   @"kCGSSessionSecureInputPID",
                                   [NSNumber numberWithBool:YES],
                                   @"kCGSSessionOnConsoleKey", nil];
  ChiaKeySecureInputSession parsed =
      ChiaKeySecureInputSessionFromDictionary(held);
  Check(parsed.holderPID == 1633, @"the holder pid is read");
  Check(parsed.onConsole, @"the console flag is read");

  NSArray *lockKeys = [NSArray arrayWithObjects:@"CGSSessionScreenIsLocked",
                                                @"kCGSSessionScreenIsLocked",
                                                nil];
  for (NSString *key in lockKeys) {
    NSDictionary *locked = [NSDictionary
        dictionaryWithObject:[NSNumber numberWithBool:YES]
                      forKey:key];
    Check(ChiaKeySecureInputSessionFromDictionary(locked).screenLocked,
          [NSString stringWithFormat:@"%@ marks the screen locked", key]);
  }

  NSDictionary *junk = [NSDictionary
      dictionaryWithObject:@"1633"
                    forKey:@"kCGSSessionSecureInputPID"];
  Check(ChiaKeySecureInputSessionFromDictionary(junk).holderPID == 0,
        @"a non-number pid is ignored");
}

static void TestStuckDetection(void) {
  Check(ChiaKeySecureInputIsStuck(Session(1633, NO, YES), kLoginwindowPath),
        @"loginwindow holding it in an unlocked session is stuck");
  Check(!ChiaKeySecureInputIsStuck(Session(1633, YES, YES), kLoginwindowPath),
        @"loginwindow holding it behind the lock screen is expected");
  Check(!ChiaKeySecureInputIsStuck(Session(1633, NO, NO), kLoginwindowPath),
        @"a session switched away from the console is not ours to judge");
  Check(!ChiaKeySecureInputIsStuck(Session(0, NO, YES), nil),
        @"nobody holding it is not stuck");
  Check(!ChiaKeySecureInputIsStuck(
            Session(5290, NO, YES),
            @"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"),
        @"an app's password field is the app's business, not a stuck session");
  Check(!ChiaKeySecureInputIsStuck(Session(1633, NO, YES), nil),
        @"an unreadable holder path is not assumed to be loginwindow");
}

static void TestWarningShowsOnlyAfterTwoLooks(void) {
  ChiaKeySecureInputWatchPhase phase = ChiaKeySecureInputWatchIdle;
  Check(ChiaKeySecureInputWatchAdvance(&phase, YES) ==
            ChiaKeySecureInputWatchScheduleConfirm,
        @"the first stuck look only schedules a confirmation");
  Check(ChiaKeySecureInputWatchAdvance(&phase, YES) ==
            ChiaKeySecureInputWatchShowWarning,
        @"the confirming look shows the warning");
  Check(ChiaKeySecureInputWatchAdvance(&phase, YES) ==
            ChiaKeySecureInputWatchNone,
        @"the warning shows once per stuck episode");

  ChiaKeySecureInputWatchRestart(&phase);
  Check(phase == ChiaKeySecureInputWatchWarned,
        @"an unlock does not re-arm a warning the user already saw");
  Check(ChiaKeySecureInputWatchAdvance(&phase, YES) ==
            ChiaKeySecureInputWatchNone,
        @"so the next unlock does not nag again");

  Check(ChiaKeySecureInputWatchAdvance(&phase, NO) ==
            ChiaKeySecureInputWatchHideWarning,
        @"the hold clearing takes the warning down");
  Check(phase == ChiaKeySecureInputWatchIdle,
        @"and starts a fresh episode");
}

static void TestTransientHoldNeverWarns(void) {
  ChiaKeySecureInputWatchPhase phase = ChiaKeySecureInputWatchIdle;
  ChiaKeySecureInputWatchAdvance(&phase, YES);
  Check(ChiaKeySecureInputWatchAdvance(&phase, NO) ==
            ChiaKeySecureInputWatchNone,
        @"a hold gone by the confirming look raises nothing");
  Check(phase == ChiaKeySecureInputWatchIdle, @"and leaves no suspicion");

  ChiaKeySecureInputWatchAdvance(&phase, YES);
  ChiaKeySecureInputWatchRestart(&phase);
  Check(phase == ChiaKeySecureInputWatchIdle,
        @"a lock between the two looks discards the suspicion");
  Check(ChiaKeySecureInputWatchAdvance(&phase, YES) ==
            ChiaKeySecureInputWatchScheduleConfirm,
        @"so the session after it needs its own two looks");
}

static void TestLogoutResult(void) {
  Check(ChiaKeyLogoutRequestSucceeded(0, @""), @"status 0 is success");
  Check(ChiaKeyLogoutRequestSucceeded(
            1, @"execution error: User canceled. (-128)\n"),
        @"cancelling the system dialog is not a failure");
  Check(!ChiaKeyLogoutRequestSucceeded(
            1, @"execution error: Not authorized to send Apple events to "
               @"loginwindow. (-1743)\n"),
        @"a refused Apple Event is a failure");
  Check(!ChiaKeyLogoutRequestSucceeded(1, nil), @"no output is a failure");
}

int main(void) {
  @autoreleasepool {
    TestSessionDictionaryParsing();
    TestStuckDetection();
    TestWarningShowsOnlyAfterTwoLooks();
    TestTransientHoldNeverWarns();
    TestLogoutResult();
    NSLog(@"secure input watch: all checks passed");
  }
  return 0;
}
