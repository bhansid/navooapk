package com.navoo.app;

import android.app.Activity;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.util.TypedValue;
import android.view.Gravity;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

public class PendingActivity extends Activity {
    private static final int NAVY = 0xFF0F2742, GREY = 0xFF5F6F82, TEAL = 0xFF2B6F92, BG = 0xFFF8F9F9;

    @Override protected void onCreate(Bundle s) {
        super.onCreate(s);
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setGravity(Gravity.CENTER_HORIZONTAL | Gravity.CENTER_VERTICAL);
        col.setBackgroundColor(BG);
        int pad = dp(28);
        col.setPadding(pad, pad, pad, pad);

        ImageView logo = new ImageView(this);
        logo.setImageResource(R.drawable.logo);
        col.addView(logo, new LinearLayout.LayoutParams(dp(72), dp(72)));

        TextView badge = text("●  PENDING APPROVAL", 12, 0xFFB7791F, true);
        badge.setLetterSpacing(0.08f);
        GradientDrawable bb = new GradientDrawable();
        bb.setColor(0xFFFFF4DE); bb.setCornerRadius(dp(20));
        badge.setBackground(bb);
        badge.setPadding(dp(14), dp(6), dp(14), dp(6));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-2, -2);
        lp.topMargin = dp(28);
        col.addView(badge, lp);

        TextView title = text("Almost there", 32, NAVY, true);
        lp = new LinearLayout.LayoutParams(-2, -2); lp.topMargin = dp(18);
        col.addView(title, lp);

        TextView msg = text("Your development user is pending approval.", 18, NAVY, false);
        lp = new LinearLayout.LayoutParams(-1, -2); lp.topMargin = dp(12);
        col.addView(msg, lp);

        TextView sub = text("You'll be able to sign in once the Navoo team approves your account.", 15, GREY, false);
        lp = new LinearLayout.LayoutParams(-1, -2); lp.topMargin = dp(8);
        col.addView(sub, lp);

        TextView btn = text("Back to log in", 18, 0xFFFFFFFF, false);
        GradientDrawable g = new GradientDrawable();
        g.setColor(TEAL); g.setCornerRadius(dp(14));
        btn.setBackground(g);
        btn.setPadding(0, dp(16), 0, dp(16));
        btn.setOnClickListener(v -> finish());
        lp = new LinearLayout.LayoutParams(-1, -2); lp.topMargin = dp(36);
        col.addView(btn, lp);

        setContentView(col);
        Ui.bars(this, BG, BG);
    }

    private TextView text(String t, int sp, int color, boolean bold) {
        TextView v = new TextView(this);
        v.setText(t);
        v.setTextSize(TypedValue.COMPLEX_UNIT_SP, sp);
        v.setTextColor(color);
        v.setGravity(Gravity.CENTER);
        v.setTypeface(Typeface.create("sans-serif", bold ? Typeface.BOLD : Typeface.NORMAL));
        return v;
    }

    private int dp(int v) { return Math.round(v * getResources().getDisplayMetrics().density); }
}
