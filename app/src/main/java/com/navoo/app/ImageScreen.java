package com.navoo.app;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.RectF;
import android.util.TypedValue;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

/** Draws a design image (fit to screen) and places child views over it using the image's own pixel coordinates. */
public class ImageScreen extends ViewGroup {
    private final Bitmap bitmap;
    private final Paint paint = new Paint(Paint.FILTER_BITMAP_FLAG | Paint.ANTI_ALIAS_FLAG);
    private final RectF dst = new RectF();
    private final int bgColor;
    private float scale = 1f;

    public ImageScreen(Context c, int drawableRes) {
        super(c);
        BitmapFactory.Options o = new BitmapFactory.Options();
        o.inScaled = false;
        bitmap = BitmapFactory.decodeResource(c.getResources(), drawableRes, o);
        bgColor = bitmap.getPixel(bitmap.getWidth() / 2, bitmap.getHeight() - 3);
        setWillNotDraw(false);
    }

    public int getBackgroundTint() { return bgColor; }
    public int getTopTint() { return bitmap.getPixel(5, 5); }

    /** Add a view covering the rectangle (l,t)-(r,b) in source-image pixels. textPx = text size in image pixels (0 = leave). */
    public void place(View v, int l, int t, int r, int b, float textPx) {
        addView(v, new Spot(new float[]{l, t, r, b, textPx}));
    }

    static class Spot extends ViewGroup.LayoutParams {
        final float[] p;
        Spot(float[] p) { super(MATCH_PARENT, MATCH_PARENT); this.p = p; }
    }

    private static float[] spot(View v) {
        ViewGroup.LayoutParams lp = v.getLayoutParams();
        return lp instanceof Spot ? ((Spot) lp).p : null;
    }

    private void computeRect(int w, int h) {
        float bw = bitmap.getWidth(), bh = bitmap.getHeight();
        scale = Math.min(w / bw, h / bh);
        float dw = bw * scale, dh = bh * scale;
        float left = (w - dw) / 2f, top = (h - dh) / 2f;
        dst.set(left, top, left + dw, top + dh);
    }

    @Override protected void onMeasure(int wSpec, int hSpec) {
        int w = MeasureSpec.getSize(wSpec), h = MeasureSpec.getSize(hSpec);
        setMeasuredDimension(w, h);
        computeRect(w, h);
        for (int i = 0; i < getChildCount(); i++) {
            View v = getChildAt(i);
            float[] p = spot(v);
            if (p == null) { v.measure(wSpec, hSpec); continue; }
            if (p[4] > 0 && v instanceof TextView)
                ((TextView) v).setTextSize(TypedValue.COMPLEX_UNIT_PX, p[4] * scale);
            int cw = Math.round((p[2] - p[0]) * scale), ch = Math.round((p[3] - p[1]) * scale);
            v.measure(MeasureSpec.makeMeasureSpec(cw, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(ch, MeasureSpec.EXACTLY));
        }
    }

    @Override protected void onLayout(boolean changed, int l, int t, int r, int b) {
        for (int i = 0; i < getChildCount(); i++) {
            View v = getChildAt(i);
            float[] p = spot(v);
            if (p == null) { v.layout(0, 0, r - l, b - t); continue; }
            int x = Math.round(dst.left + p[0] * scale), y = Math.round(dst.top + p[1] * scale);
            v.layout(x, y, x + v.getMeasuredWidth(), y + v.getMeasuredHeight());
        }
    }

    @Override protected void onDraw(Canvas c) {
        c.drawColor(bgColor);
        // top letterbox uses the image's top colour so the design blends into the status bar area
        if (dst.top > 0) { Paint p = new Paint(); p.setColor(getTopTint()); c.drawRect(0, 0, getWidth(), dst.top, p); }
        c.drawBitmap(bitmap, new Rect(0, 0, bitmap.getWidth(), bitmap.getHeight()), dst, paint);
    }
}
