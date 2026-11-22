package com.silverlight.dndadventurers;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.os.Build;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.DigestOutputStream;
import java.security.MessageDigest;

final class GitHubUpdates {
    private static final String RELEASE =
            "https://github.com/cosmerearchives-creator/dnd-adventurers/releases/latest/download/";
    private static final int MAX_METADATA_BYTES = 4096;
    private static final int MAX_APK_BYTES = 100 * 1024 * 1024;

    private GitHubUpdates() {}

    static File downloadIfNewer(Context context) throws Exception {
        JSONObject release;
        try (ByteArrayOutputStream metadata = new ByteArrayOutputStream()) {
            if (!download(RELEASE + "update.json", metadata, MAX_METADATA_BYTES, true)) {
                return null;
            }
            release = new JSONObject(new String(metadata.toByteArray(), StandardCharsets.UTF_8));
        }

        int versionCode = release.getInt("versionCode");
        if (versionCode <= BuildConfig.VERSION_CODE) {
            return null;
        }

        String checksum = release.getString("sha256");
        if (!checksum.matches("[a-f0-9]{64}")) {
            throw new IOException("Invalid release checksum");
        }

        File directory = new File(context.getCacheDir(), "updates");
        if (!directory.isDirectory() && !directory.mkdirs() && !directory.isDirectory()) {
            throw new IOException("Could not create update directory");
        }

        File apk = new File(directory, "adventurers-" + checksum + ".apk");
        if (apk.isFile() && hasChecksum(apk, checksum)) {
            verifyPackage(context, apk, versionCode);
            return apk;
        }

        File partial = File.createTempFile("download-", ".tmp", directory);
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            try (DigestOutputStream output = new DigestOutputStream(new FileOutputStream(partial), digest)) {
                download(RELEASE + "dnd-adventurers.apk", output, MAX_APK_BYTES, false);
            }
            if (!checksum.equals(toHex(digest.digest()))) {
                throw new IOException("APK checksum did not match the release");
            }
            verifyPackage(context, partial, versionCode);
            if (!partial.renameTo(apk) && !(apk.isFile() && hasChecksum(apk, checksum))) {
                throw new IOException("Could not save verified update");
            }
            return apk;
        } finally {
            partial.delete();
        }
    }

    private static boolean download(String address, java.io.OutputStream output, int limit,
                                    boolean allowMissing) throws IOException {
        HttpURLConnection connection = (HttpURLConnection) new URL(address).openConnection();
        connection.setConnectTimeout(10000);
        connection.setReadTimeout(15000);
        try {
            int status = connection.getResponseCode();
            if (allowMissing && status == HttpURLConnection.HTTP_NOT_FOUND) {
                return false;
            }
            if (status != HttpURLConnection.HTTP_OK) {
                throw new IOException("GitHub returned HTTP " + status);
            }
            try (InputStream input = connection.getInputStream()) {
                byte[] buffer = new byte[8192];
                int total = 0;
                int count;
                while ((count = input.read(buffer)) != -1) {
                    total += count;
                    if (total > limit || Thread.currentThread().isInterrupted()) {
                        throw new IOException("Download stopped before completion");
                    }
                    output.write(buffer, 0, count);
                }
            }
            return true;
        } finally {
            connection.disconnect();
        }
    }

    private static boolean hasChecksum(File file, String expected) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (InputStream input = new java.io.FileInputStream(file)) {
            byte[] buffer = new byte[8192];
            int count;
            while ((count = input.read(buffer)) != -1) {
                digest.update(buffer, 0, count);
            }
        }
        return expected.equals(toHex(digest.digest()));
    }

    private static String toHex(byte[] bytes) {
        StringBuilder hex = new StringBuilder(bytes.length * 2);
        for (byte value : bytes) {
            hex.append(Character.forDigit((value >>> 4) & 15, 16));
            hex.append(Character.forDigit(value & 15, 16));
        }
        return hex.toString();
    }

    @SuppressWarnings("deprecation")
    private static void verifyPackage(Context context, File apk, int expectedVersion) throws IOException {
        PackageInfo info = context.getPackageManager().getPackageArchiveInfo(apk.getAbsolutePath(), 0);
        if (info == null || !context.getPackageName().equals(info.packageName)) {
            throw new IOException("APK belongs to a different app");
        }
        long version = Build.VERSION.SDK_INT >= 28 ? info.getLongVersionCode() : info.versionCode;
        if (version != expectedVersion) {
            throw new IOException("APK version did not match the release");
        }
        // Android's installer enforces the installed app's signing identity.
    }
}
