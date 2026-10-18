package com.gathin.tvhome;

import android.accessibilityservice.AccessibilityService;
import android.content.ComponentName;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.view.KeyEvent;
import android.view.accessibility.AccessibilityEvent;

/**
 * Fire OS only: the Home button is hard-wired to Amazon's launcher and there is no default-home
 * setting, so this service watches for Amazon's home screen coming to the front and opens ours instead.
 * Enable over adb:
 *   settings put secure enabled_accessibility_services com.gathin.tvhome/.HomeRedirectService
 *   settings put secure accessibility_enabled 1
 * Fire TV Settings lives inside Amazon's launcher, so that screen is left alone after the Settings pill
 * until Back leaves it. Home itself shows Amazon's home for ~5 s first: Android blocks other apps from
 * starting activities for 5 s after a Home press, and Fire OS never passes Home to accessibility services.
 */
public class HomeRedirectService extends AccessibilityService {
    private static final String STOCK_HOME = "com.amazon.tv.launcher";

    /** Set by MainActivity right before it opens Fire TV Settings (shown inside the stock launcher). */
    static volatile long settingsOpenedAt;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private boolean stockHomeInFront;
    private boolean inStockSettings;

    @Override
    public void onAccessibilityEvent(AccessibilityEvent e) {
        if (e.getEventType() != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED || e.getPackageName() == null) return;
        String pkg = e.getPackageName().toString();
        String cls = e.getClassName() == null ? "" : e.getClassName().toString();
        // Dialogs, popups and overlays fire this event too; only full activities change what is in front.
        if (!isActivity(pkg, cls)) return;
        if (pkg.equals(STOCK_HOME) && cls.contains("HomeActivity")) {
            stockHomeInFront = true;
            if (SystemClock.uptimeMillis() - settingsOpenedAt < 5000) inStockSettings = true;
            if (!inStockSettings) openOurHome();
        } else {
            stockHomeInFront = false;
            // Settings sub-pages live in com.amazon.tv.settings.*; anything else means Settings was left.
            if (!pkg.equals(STOCK_HOME) && !pkg.startsWith("com.amazon.tv.settings")) inStockSettings = false;
        }
    }

    @Override
    protected boolean onKeyEvent(KeyEvent event) {
        // Fire OS consumes Home before accessibility services see it, so only Back is useful here:
        // Back on the Fire TV Settings grid would land on Amazon's home, so return to ours instead.
        if (event.getKeyCode() == KeyEvent.KEYCODE_BACK && event.getAction() == KeyEvent.ACTION_UP
                && inStockSettings && stockHomeInFront) {
            inStockSettings = false;
            settingsOpenedAt = 0;
            handler.postDelayed(this::openOurHome, 300);
        }
        return false;   // never swallow keys
    }

    private boolean isActivity(String pkg, String cls) {
        if (cls.isEmpty()) return false;
        try {
            getPackageManager().getActivityInfo(new ComponentName(pkg, cls), 0);
            return true;
        } catch (PackageManager.NameNotFoundException ex) {
            return false;
        }
    }

    private void openOurHome() {
        stockHomeInFront = false;
        startActivity(new Intent(this, MainActivity.class)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED));
    }

    @Override
    public void onInterrupt() {
    }
}
