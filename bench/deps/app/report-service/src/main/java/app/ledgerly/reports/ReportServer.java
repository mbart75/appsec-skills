package app.ledgerly.reports;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

/** Monthly revenue reports for the Ledgerly dashboard. Reached through the web app's /reports proxy. */
public final class ReportServer {
    private static final Logger LOG = LogManager.getLogger(ReportServer.class);

    public static void main(String[] args) throws IOException {
        int port = Integer.parseInt(System.getenv().getOrDefault("PORT", "8081"));
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        server.createContext("/reports/monthly", ReportServer::monthly);
        server.start();
        LOG.info("Report service listening on {}", port);
    }

    private static void monthly(HttpExchange exchange) throws IOException {
        String month = exchange.getRequestURI().getQuery();
        String client = exchange.getRequestHeaders().getFirst("User-Agent");
        LOG.info("Monthly report for {} requested by {}", month, client);

        byte[] body = ("{\"month\":\"" + sanitizeMonth(month) + "\",\"total\":0}").getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json");
        exchange.sendResponseHeaders(200, body.length);
        try (OutputStream out = exchange.getResponseBody()) {
            out.write(body);
        }
    }

    private static String sanitizeMonth(String query) {
        if (query != null && query.matches("month=\\d{4}-\\d{2}")) {
            return query.substring("month=".length());
        }
        return "";
    }
}
