import java.io.IOException;
import java.net.ServerSocket;
import java.net.Socket;

public class ServerTest {

    static void check(boolean cond, String msg) {
        if (!cond) {
            System.err.println("FAIL: " + msg);
            System.exit(1);
        }
    }

    static void testMakeReply() {
        check("Hello World".equals(ServerLib.makeReply("World")), "makeReply(World)");
        check("Hello Bazel".equals(ServerLib.makeReply("Bazel")), "makeReply(Bazel)");
        check("Hello ".equals(ServerLib.makeReply("")),           "makeReply('')");
    }

    static void testHandleClient() throws Exception {
        try (ServerSocket ss = new ServerSocket(0)) {
            int port = ss.getLocalPort();

            Thread t = new Thread(() -> {
                try {
                    ServerLib.handleClient(ss.accept());
                } catch (IOException e) {
                    throw new RuntimeException(e);
                }
            });
            t.start();

            try (Socket conn = new Socket("127.0.0.1", port)) {
                conn.getOutputStream().write("World".getBytes());
                conn.shutdownOutput();

                byte[] buf = new byte[256];
                int n = conn.getInputStream().read(buf);
                check(n > 0, "received reply");
                String reply = new String(buf, 0, n);
                check("Hello World".equals(reply), "handleClient reply: got '" + reply + "'");
            }
            t.join(2000);
        }
    }

    public static void main(String[] args) throws Exception {
        testMakeReply();
        testHandleClient();
        System.out.println("All tests passed.");
    }
}
