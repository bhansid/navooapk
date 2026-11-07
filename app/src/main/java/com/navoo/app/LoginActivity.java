package com.navoo.app;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ProgressBar;
import android.widget.Toast;

public class LoginActivity extends Activity {
    private EditText email, password;
    private boolean showPassword;
    private View loading;

    @Override protected void onCreate(Bundle s) {
        super.onCreate(s);
        ImageScreen screen = new ImageScreen(this, R.drawable.screen_login);

        email = field("Email");
        email.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS);
        email.setImeOptions(EditorInfo.IME_ACTION_NEXT);
        screen.place(email, 182, 640, 780, 732, 30);

        password = field("Password");
        password.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        password.setImeOptions(EditorInfo.IME_ACTION_DONE);
        password.setOnEditorActionListener((v, id, e) -> { submit(); return true; });
        screen.place(password, 182, 786, 690, 878, 30);

        screen.place(Ui.hotspot(this, v -> togglePassword()), 695, 795, 770, 870, 0);   // eye icon
        screen.place(Ui.hotspot(this, v -> finish()), 40, 60, 115, 135, 0);           // back arrow
        screen.place(Ui.hotspot(this, v -> toast("Password reset is not available yet")), 560, 915, 795, 960, 0);
        screen.place(Ui.hotspot(this, v -> submit()), 66, 1015, 788, 1122, 0);        // Log in
        screen.place(Ui.hotspot(this, v -> pending()), 64, 1263, 790, 1372, 0);       // Apple
        screen.place(Ui.hotspot(this, v -> pending()), 64, 1397, 790, 1507, 0);       // Google
        screen.place(Ui.hotspot(this, v -> toast("Sign-ups are invite only during development")), 440, 1595, 705, 1650, 0);

        FrameLayout root = new FrameLayout(this);
        root.addView(screen);
        loading = buildLoading();
        root.addView(loading);
        setContentView(root);
        Ui.bars(this, screen.getTopTint(), screen.getBackgroundTint());
    }

    private EditText field(String hint) {
        EditText e = new EditText(this);
        e.setHint(hint);
        e.setHintTextColor(0xFF7A8899);
        e.setTextColor(0xFF0F2742);
        e.setBackground(null);
        e.setSingleLine(true);
        e.setPadding(0, 0, 0, 0);
        e.setGravity(Gravity.CENTER_VERTICAL);
        e.setTypeface(Typeface.create("sans-serif", Typeface.NORMAL));
        return e;
    }

    private void togglePassword() {
        showPassword = !showPassword;
        int sel = password.getSelectionEnd();
        password.setInputType(InputType.TYPE_CLASS_TEXT | (showPassword
                ? InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD : InputType.TYPE_TEXT_VARIATION_PASSWORD));
        password.setSelection(Math.max(0, sel));
    }

    private void submit() {
        if (email.getText().toString().trim().isEmpty()) { email.setError("Enter your email"); email.requestFocus(); return; }
        if (password.getText().toString().isEmpty()) { password.setError("Enter your password"); password.requestFocus(); return; }
        // Any email + password is accepted; every account is held for approval.
        pending();
    }

    private void pending() {
        InputMethodManager imm = (InputMethodManager) getSystemService(INPUT_METHOD_SERVICE);
        imm.hideSoftInputFromWindow(password.getWindowToken(), 0);
        loading.setVisibility(View.VISIBLE);
        new Handler(Looper.getMainLooper()).postDelayed(() -> {
            loading.setVisibility(View.GONE);
            startActivity(new Intent(this, PendingActivity.class));
            overridePendingTransition(android.R.anim.fade_in, android.R.anim.fade_out);
        }, 1200);
    }

    private View buildLoading() {
        FrameLayout f = new FrameLayout(this);
        f.setBackgroundColor(0x99FFFFFF);
        f.setClickable(true);
        ProgressBar p = new ProgressBar(this);
        f.addView(p, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER));
        f.setVisibility(View.GONE);
        return f;
    }

    private void toast(String m) { Toast.makeText(this, m, Toast.LENGTH_SHORT).show(); }
}
