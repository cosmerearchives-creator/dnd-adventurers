package com.silverlight.dndadventurers;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.graphics.Color;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.core.content.FileProvider;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;

import java.io.File;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class MainActivity extends Activity {
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private TextView status;
    private Button checkButton;
    private File pendingUpdate;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(createHomeScreen());
        checkForUpdate();
    }

    @Override
    protected void onDestroy() {
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
                    if (isDestroyed() || isFinishing()) {
                        return;
                    }

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
        home.setPadding(dp(24), dp(24), dp(24), dp(24));
        ViewCompat.setOnApplyWindowInsetsListener(home, (view, insets) -> {
            Insets safeArea = insets.getInsets(WindowInsetsCompat.Type.systemBars()
                    | WindowInsetsCompat.Type.displayCutout());
            view.setPadding(dp(24) + safeArea.left, dp(24) + safeArea.top,
                    dp(24) + safeArea.right, dp(24) + safeArea.bottom);
            return insets;
        });

        ImageView icon = new ImageView(this);
        icon.setImageResource(R.drawable.adventurers_icon);
        home.addView(icon, new LinearLayout.LayoutParams(dp(88), dp(88)));

        TextView title = createText(32, Color.rgb(251, 238, 213));
        title.setText(R.string.app_name);
        home.addView(title);

        TextView version = createText(16, Color.rgb(218, 201, 222));
        version.setText(getString(R.string.installed_version, BuildConfig.VERSION_NAME));
        home.addView(version);

        checkButton = new Button(this);
        checkButton.setText(R.string.check_for_update);
        checkButton.setOnClickListener(view -> handleUpdateButton());
        LinearLayout.LayoutParams buttonLayout = new LinearLayout.LayoutParams(-2, -2);
        buttonLayout.topMargin = dp(24);
        home.addView(checkButton, buttonLayout);

        status = createText(14, Color.rgb(218, 201, 222));
        status.setAccessibilityLiveRegion(View.ACCESSIBILITY_LIVE_REGION_POLITE);
        home.addView(status);
        return home;
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
