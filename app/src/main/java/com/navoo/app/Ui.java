package com.navoo.app;

import android.app.Activity;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.RippleDrawable;
import android.content.res.ColorStateList;
import android.os.Build;
import android.view.View;
import android.view.Window;

final class Ui {
    /** Transparent tappable area with a soft ripple, used over buttons drawn in the design image. */
    static View hotspot(Activity a, View.OnClickListener l) {
        View v = new View(a);
        v.setBackground(new RippleDrawable(ColorStateList.valueOf(0x22000000), null, new ColorDrawable(Color.WHITE)));
        v.setClickable(true);
        v.setOnClickListener(l);
        return v;
    }

    static void bars(Activity a, int top, int bottom) {
        Window w = a.getWindow();
        w.setStatusBarColor(top);
        w.setNavigationBarColor(bottom);
        int flags = 0;
        if (Build.VERSION.SDK_INT >= 23) flags |= View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
        if (Build.VERSION.SDK_INT >= 26) flags |= View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
        w.getDecorView().setSystemUiVisibility(flags);
    }
}
