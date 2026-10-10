package io.github.johnnydeey.tvremote;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import dadb.AdbKeyPair;
import dadb.AdbShellResponse;
import dadb.Dadb;

import java.io.File;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

// Talks to the decoder over ADB (port 5555) directly from the phone, so no bridge or Termux is needed.
@CapacitorPlugin(name = "Adb")
public class AdbPlugin extends Plugin {

    // one command at a time, off the main thread
    private final ExecutorService pool = Executors.newSingleThreadExecutor();
    private Dadb dadb = null;
    private String host = null;
    private int port = 5555;
    private AdbKeyPair keyPair = null;

    // this phone's own ADB key, created once and kept in the app's private storage
    private AdbKeyPair keys() throws Exception {
        if (keyPair != null) return keyPair;
        File dir = getContext().getFilesDir();
        File priv = new File(dir, "adbkey");
        File pub = new File(dir, "adbkey.pub");
        if (!priv.exists() || !pub.exists()) {
            AdbKeyPair.Companion.generate(priv, pub);
        }
        keyPair = AdbKeyPair.Companion.read(priv, pub);
        return keyPair;
    }

    private void closeQuietly() {
        try { if (dadb != null) dadb.close(); } catch (Exception ignored) {}
        dadb = null;
    }

    private void openConnection() throws Exception {
        closeQuietly();
        dadb = Dadb.Companion.create(host, port, keys());
    }

    @PluginMethod
    public void connect(final PluginCall call) {
        final String h = call.getString("host");
        final int p = call.getInt("port", 5555);
        if (h == null || h.isEmpty()) { call.reject("host is required"); return; }
        pool.execute(new Runnable() {
            @Override public void run() {
                try {
                    host = h;
                    port = p;
                    openConnection();
                    // the first time, the decoder asks on its screen to allow this device
                    AdbShellResponse r = dadb.shell("echo ok");
                    JSObject ret = new JSObject();
                    ret.put("connected", r.getExitCode() == 0);
                    call.resolve(ret);
                } catch (Exception e) {
                    closeQuietly();
                    call.reject("connect failed: " + e.getMessage());
                }
            }
        });
    }

    @PluginMethod
    public void shell(final PluginCall call) {
        final String cmd = call.getString("command");
        if (cmd == null) { call.reject("command is required"); return; }
        pool.execute(new Runnable() {
            @Override public void run() {
                try {
                    if (host == null) { call.reject("not connected"); return; }
                    AdbShellResponse r;
                    try {
                        if (dadb == null) openConnection();
                        r = dadb.shell(cmd);
                    } catch (Exception first) {
                        // the connection may have dropped: reconnect once and retry
                        openConnection();
                        r = dadb.shell(cmd);
                    }
                    JSObject ret = new JSObject();
                    ret.put("output", r.getOutput());
                    ret.put("exitCode", r.getExitCode());
                    call.resolve(ret);
                } catch (Exception e) {
                    closeQuietly();
                    call.reject("shell failed: " + e.getMessage());
                }
            }
        });
    }

    @PluginMethod
    public void disconnect(PluginCall call) {
        pool.execute(new Runnable() { @Override public void run() { closeQuietly(); } });
        call.resolve();
    }
}