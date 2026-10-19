# Ledgerly

Small invoicing tool: a web app (`web/`, Node.js) and a report service (`report-service/`, Java) that the web app calls for monthly reports.

- `web/`: `npm ci && npm start` (port 3000)
- `report-service/`: `mvn package && java -jar target/report-service-1.4.0.jar` (port 8081, reachable only from the web app)
