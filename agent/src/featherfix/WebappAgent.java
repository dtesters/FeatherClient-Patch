package featherfix;

import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.io.ByteArrayInputStream;
import java.lang.instrument.ClassFileTransformer;
import java.lang.instrument.Instrumentation;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.ProtectionDomain;

/**
 * FeatherClient-Patch web UI fallback.
 *
 * The in-game Feather menu is a web app loaded from https://mc-webapp.feathermc.com/. If that host
 * is down, the whole menu shows a Cloudflare error. This agent checks at startup and, only if the
 * release host doesn't answer, rewrites that one string constant (as Feather's classes load) to the
 * first mirror that does: Feather's own beta, then dev web app. Nothing else is touched.
 */
public final class WebappAgent {
    static final String RELEASE = "https://mc-webapp.feathermc.com/";
    static final String[] FALLBACKS = {
        "https://beta.mc-webapp.feathermc.com/",
        "https://dev.mc-webapp.feathermc.com/",
    };
    private static final byte[] NEEDLE = RELEASE.getBytes(StandardCharsets.UTF_8);

    public static void premain(String args, Instrumentation inst) {
        String forced = System.getProperty("featherfix.webapp");
        String target = forced != null ? forced : pickTarget();
        if (target == null) {
            log("web UI host is up, nothing to do");
            return;
        }
        log("web UI host is down, using " + target);
        inst.addTransformer(new Rewriter(target));
    }

    static String pickTarget() {
        if (answers(RELEASE)) return null;
        for (String url : FALLBACKS) {
            if (answers(url)) return url;
        }
        return null; // nothing better available; leave it alone
    }

    static boolean answers(String url) {
        try {
            HttpURLConnection c = (HttpURLConnection) new URL(url).openConnection();
            c.setConnectTimeout(4000);
            c.setReadTimeout(4000);
            c.setRequestMethod("GET");
            c.setRequestProperty("User-Agent", "FeatherClient-Patch");
            int code = c.getResponseCode();
            c.disconnect();
            return code >= 200 && code < 400;
        } catch (IOException e) {
            return false;
        }
    }

    static void log(String msg) {
        System.out.println("[FeatherClient-Patch] " + msg);
    }

    static final class Rewriter implements ClassFileTransformer {
        private final String target;

        Rewriter(String target) {
            this.target = target;
        }

        @Override
        public byte[] transform(ClassLoader loader, String name, Class<?> cls, ProtectionDomain pd, byte[] bytes) {
            if (bytes == null || indexOf(bytes, NEEDLE) < 0) return null;
            try {
                byte[] out = rewriteConstant(bytes, RELEASE, target);
                if (out != null) log("rewrote web UI address in " + name);
                return out;
            } catch (Throwable t) {
                log("could not rewrite " + name + ": " + t);
                return null; // never break class loading
            }
        }
    }

    /** Replace a CONSTANT_Utf8 entry equal to {@code from}; returns null if there is none. */
    static byte[] rewriteConstant(byte[] cls, String from, String to) throws IOException {
        DataInputStream in = new DataInputStream(new ByteArrayInputStream(cls));
        ByteArrayOutputStream buf = new ByteArrayOutputStream(cls.length + 64);
        DataOutputStream out = new DataOutputStream(buf);
        out.writeInt(in.readInt());          // magic
        out.writeShort(in.readUnsignedShort()); // minor
        out.writeShort(in.readUnsignedShort()); // major
        int count = in.readUnsignedShort();
        out.writeShort(count);
        boolean changed = false;
        for (int i = 1; i < count; i++) {
            int tag = in.readUnsignedByte();
            out.writeByte(tag);
            switch (tag) {
                case 1: { // Utf8
                    String s = in.readUTF();
                    if (s.equals(from)) {
                        s = to;
                        changed = true;
                    }
                    out.writeUTF(s);
                    break;
                }
                case 3: case 4: // Integer, Float
                    out.writeInt(in.readInt());
                    break;
                case 5: case 6: // Long, Double take two slots
                    out.writeLong(in.readLong());
                    i++;
                    break;
                case 7: case 8: case 16: case 19: case 20: // Class, String, MethodType, Module, Package
                    out.writeShort(in.readUnsignedShort());
                    break;
                case 9: case 10: case 11: case 12: case 17: case 18: // refs, NameAndType, (Invoke)Dynamic
                    out.writeInt(in.readInt());
                    break;
                case 15: // MethodHandle
                    out.writeByte(in.readUnsignedByte());
                    out.writeShort(in.readUnsignedShort());
                    break;
                default:
                    throw new IOException("unknown constant pool tag " + tag);
            }
        }
        if (!changed) return null;
        byte[] rest = new byte[in.available()];
        in.readFully(rest);
        out.write(rest);
        out.flush();
        return buf.toByteArray();
    }

    static int indexOf(byte[] hay, byte[] needle) {
        outer:
        for (int i = 0; i <= hay.length - needle.length; i++) {
            for (int j = 0; j < needle.length; j++) {
                if (hay[i + j] != needle[j]) continue outer;
            }
            return i;
        }
        return -1;
    }
}
