package com.navoo.app;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;

public class SplashActivity extends Activity {
    private final Handler handler = new Handler(Looper.getMainLooper());
    private boolean done;

    @Override protected void onCreate(Bundle s) {
        super.onCreate(s);
        ImageScreen screen = new ImageScreen(this, R.drawable.screen_splash);
        screen.place(Ui.hotspot(this, v -> next()), 36, 1646, 817, 1737, 0);   // "Get started"
        setContentView(screen);
        Ui.bars(this, screen.getTopTint(), screen.getBackgroundTint());
        handler.postDelayed(this::next, 3000);   // auto-advance after 3 s
    }

    private void next() {
        if (done) return;
        done = true;
        startActivity(new Intent(this, WelcomeActivity.class));
        overridePendingTransition(android.R.anim.fade_in, android.R.anim.fade_out);
        finish();
    }

    @Override protected void onDestroy() { handler.removeCallbacksAndMessages(null); super.onDestroy(); }
}
