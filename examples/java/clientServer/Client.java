import java.io.IOException;
import java.io.OutputStream;
import java.net.Socket;

public class Client {
    public static void main(String[] args) throws IOException {
        String name = args.length > 0 ? args[0] : "world";
        try (Socket conn = new Socket("127.0.0.1", 50051)) {
            OutputStream out = conn.getOutputStream();
            out.write(name.getBytes());
            conn.shutdownOutput();

            byte[] buf = new byte[256];
            int n = conn.getInputStream().read(buf);
            if (n > 0) {
                System.out.println("Greeter received: " + new String(buf, 0, n));
            }
        }
    }
}
