import java.io.IOException;
import java.io.InputStream;
import java.net.ServerSocket;
import java.net.Socket;

public class ServerLib {

    public static String makeReply(String name) {
        return "Hello " + name;
    }

    public static void handleClient(Socket conn) throws IOException {
        try (conn) {
            InputStream in = conn.getInputStream();
            byte[] buf = new byte[256];
            int total = 0, n;
            while ((n = in.read(buf, total, buf.length - total)) > 0) {
                total += n;
            }
            if (total > 0) {
                String reply = makeReply(new String(buf, 0, total));
                conn.getOutputStream().write(reply.getBytes());
            }
        }
    }

    public static void runServer(int port) throws IOException {
        try (ServerSocket ss = new ServerSocket(port)) {
            System.out.println("Server listening on port " + port);
            while (true) {
                handleClient(ss.accept());
            }
        }
    }
}
