package com.silverlight.dndadventurers;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.graphics.Color;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.core.content.FileProvider;
import androidx.webkit.WebViewAssetLoader;

import java.io.File;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class MainActivity extends Activity {
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private TextView status;
    private Button checkButton;
    private File pendingUpdate;
    private WebView game;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(createHomeScreen());
        checkForUpdate();
    }

    @Override
    protected void onDestroy() {
        if (game != null) {
            game.destroy();
        }
        executor.shutdownNow();
        super.onDestroy();
    }

    private void checkForUpdate() {
        checkButton.setEnabled(false);
        status.setText(R.string.checking_for_update);
        executor.execute(() -> {
            try {
                File update = GitHubUpdates.downloadIfNewer(this);
                runOnUiThread(() -> {
                    if (isDestroyed() || isFinishing()) return;
                    pendingUpdate = update;
                    checkButton.setEnabled(true);
                    checkButton.setText(update == null ? R.string.check_for_update : R.string.install_update);
                    status.setText(update == null ? R.string.up_to_date : R.string.update_ready);
                });
            } catch (Exception error) {
                android.util.Log.w("DnDAdventurers", "GitHub update check failed", error);
                runOnUiThread(() -> {
                    if (!isDestroyed() && !isFinishing()) {
                        checkButton.setEnabled(true);
                        status.setText(R.string.update_unavailable);
                    }
                });
            }
        });
    }

    private void handleUpdateButton() {
        if (pendingUpdate == null) {
            checkForUpdate();
            return;
        }
        Intent install = new Intent(Intent.ACTION_VIEW);
        install.setDataAndType(FileProvider.getUriForFile(this,
                getPackageName() + ".updates", pendingUpdate), "application/vnd.android.package-archive");
        install.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        try {
            startActivity(install);
        } catch (ActivityNotFoundException | SecurityException error) {
            status.setText(R.string.update_failed);
        }
    }

    private View createHomeScreen() {
        LinearLayout home = new LinearLayout(this);
        home.setOrientation(LinearLayout.VERTICAL);
        home.setGravity(Gravity.CENTER);
        home.setBackgroundColor(Color.rgb(33, 24, 43));
        home.setPadding(dp(20), dp(20), dp(20), dp(20));

        TextView title = createText(30, Color.rgb(251, 238, 213));
        title.setText("DnD Adventurers");
        home.addView(title);

        TextView version = createText(16, Color.rgb(218, 201, 222));
        version.setText(getString(R.string.installed_version, BuildConfig.VERSION_NAME));
        home.addView(version);

        Button play = new Button(this);
        play.setText("PLAY WILDERNESS");
        play.setOnClickListener(view -> launchGame());
        LinearLayout.LayoutParams playLayout = new LinearLayout.LayoutParams(-2, -2);
        playLayout.topMargin = dp(24);
        home.addView(play, playLayout);

        checkButton = new Button(this);
        checkButton.setText(R.string.check_for_update);
        checkButton.setOnClickListener(view -> handleUpdateButton());
        home.addView(checkButton);

        status = createText(14, Color.rgb(218, 201, 222));
        status.setAccessibilityLiveRegion(View.ACCESSIBILITY_LIVE_REGION_POLITE);
        home.addView(status);
        return home;
    }

    private void launchGame() {
        FrameLayout container = new FrameLayout(this);
        game = new WebView(this);
        WebSettings settings = game.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setMediaPlaybackRequiresUserGesture(false);
        game.setWebChromeClient(new WebChromeClient());
        WebViewAssetLoader loader = new WebViewAssetLoader.Builder()
                .addPathHandler("/assets/", new WebViewAssetLoader.AssetsPathHandler(this))
                .build();
        game.setWebViewClient(new WebViewClient() {
            @Override
            public android.webkit.WebResourceResponse shouldInterceptRequest(
                    WebView view, android.webkit.WebResourceRequest request) {
                return loader.shouldInterceptRequest(request.getUrl());
            }
        });
        container.addView(game, new FrameLayout.LayoutParams(-1, -1));
        Button back = new Button(this);
        back.setText("MENU");
        FrameLayout.LayoutParams backParams = new FrameLayout.LayoutParams(dp(94), dp(48), Gravity.TOP | Gravity.RIGHT);
        container.addView(back, backParams);
        back.setOnClickListener(view -> {
            game.destroy();
            game = null;
            setContentView(createHomeScreen());
            checkForUpdate();
        });
        setContentView(container);
        game.loadUrl("https://appassets.androidplatform.net/assets/game/index.html");
    }

    private TextView createText(int size, int color) {
        TextView text = new TextView(this);
        text.setGravity(Gravity.CENTER);
        text.setTextSize(size);
        text.setTextColor(color);
        return text;
    }

    private int dp(int value) {
        return Math.round(getResources().getDisplayMetrics().density * value);
    }
}
