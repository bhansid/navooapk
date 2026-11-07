package com.navoo.app;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;

public class WelcomeActivity extends Activity {
    @Override protected void onCreate(Bundle s) {
        super.onCreate(s);
        ImageScreen screen = new ImageScreen(this, R.drawable.screen_welcome);
        screen.place(Ui.hotspot(this, v -> login()), 60, 1555, 793, 1650, 0);   // "Start with Goal Buddy"
        screen.place(Ui.hotspot(this, v -> login()), 60, 1670, 793, 1763, 0);   // "I already have an account"
        setContentView(screen);
        Ui.bars(this, screen.getTopTint(), screen.getBackgroundTint());
    }

    private void login() {
        startActivity(new Intent(this, LoginActivity.class));
        overridePendingTransition(android.R.anim.slide_in_left, android.R.anim.fade_out);
    }
}
