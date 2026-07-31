import com.google.gson.Gson;
import com.google.gson.JsonSyntaxException;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.Map;
import java.util.concurrent.Executors;

public class App {

    private static final Gson GSON = new Gson();

    private static final String DB_HOST =
            System.getenv().getOrDefault("DB_HOST", "database");

    private static final String DB_PORT =
            System.getenv().getOrDefault("DB_PORT", "3306");

    private static final String DB_NAME =
            System.getenv().getOrDefault("DB_NAME", "mydb");

    private static final String DB_USER =
            System.getenv().getOrDefault("DB_USER", "appuser");

    private static final String DB_PASSWORD =
            System.getenv().getOrDefault("DB_PASSWORD", "apppassword");

    private static final String DB_OPTIONS =
            System.getenv().getOrDefault(
                    "DB_OPTIONS",
                    "?allowPublicKeyRetrieval=true&useSSL=false"
            );

    private static final String DB_URL = String.format(
            "jdbc:mysql://%s:%s/%s%s",
            DB_HOST,
            DB_PORT,
            DB_NAME,
            DB_OPTIONS
    );

    public static void main(String[] args) throws Exception {

        Class.forName("com.mysql.cj.jdbc.Driver");

        waitForDatabase();
        initializeDatabase();

        HttpServer server = HttpServer.create(
                new InetSocketAddress(8080),
                0
        );

        server.createContext(
                "/api/health",
                App::handleHealthRequest
        );

        server.createContext(
                "/api/employees",
                App::handleEmployeeRequest
        );

        server.setExecutor(
                Executors.newFixedThreadPool(10)
        );

        server.start();

        System.out.println(
                "Backend running on port 8080"
        );
    }

    private static Connection getConnection() throws SQLException {

        return DriverManager.getConnection(
                DB_URL,
                DB_USER,
                DB_PASSWORD
        );
    }

    private static void waitForDatabase() throws Exception {

        int maximumAttempts = 20;

        for (int attempt = 1; attempt <= maximumAttempts; attempt++) {

            try (Connection ignored = getConnection()) {

                System.out.println(
                        "Successfully connected to MySQL"
                );

                return;

            } catch (SQLException exception) {

                System.out.printf(
                        "MySQL is not ready. Attempt %d/%d%n",
                        attempt,
                        maximumAttempts
                );

                if (attempt == maximumAttempts) {
                    throw exception;
                }

                Thread.sleep(5000);
            }
        }
    }

    private static void initializeDatabase() throws SQLException {

        String createTable = """
                CREATE TABLE IF NOT EXISTS employees (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(100) NOT NULL,
                    email VARCHAR(100) NOT NULL,
                    designation VARCHAR(100) NOT NULL
                )
                """;

        try (
                Connection connection = getConnection();
                Statement statement = connection.createStatement()
        ) {

            statement.execute(createTable);
        }

        System.out.println(
                "Employees table is ready"
        );
    }

    private static void handleHealthRequest(
            HttpExchange exchange
    ) throws IOException {

        if (!"GET".equalsIgnoreCase(exchange.getRequestMethod())) {

            exchange.getResponseHeaders().set(
                    "Allow",
                    "GET"
            );

            sendJsonResponse(
                    exchange,
                    405,
                    Map.of("message", "Method not allowed")
            );

            return;
        }

        try (Connection connection = getConnection()) {

            boolean databaseAvailable = connection.isValid(2);

            if (!databaseAvailable) {

                sendJsonResponse(
                        exchange,
                        503,
                        Map.of(
                                "status", "unhealthy",
                                "database", "unavailable"
                        )
                );

                return;
            }

            sendJsonResponse(
                    exchange,
                    200,
                    Map.of(
                            "status", "healthy",
                            "database", "connected"
                    )
            );

        } catch (SQLException exception) {

            sendJsonResponse(
                    exchange,
                    503,
                    Map.of(
                            "status", "unhealthy",
                            "database", "unavailable"
                    )
            );
        }
    }

    private static void handleEmployeeRequest(
            HttpExchange exchange
    ) throws IOException {

        if (!"POST".equalsIgnoreCase(exchange.getRequestMethod())) {

            exchange.getResponseHeaders().set(
                    "Allow",
                    "POST"
            );

            sendJsonResponse(
                    exchange,
                    405,
                    Map.of("message", "Method not allowed")
            );

            return;
        }

        try {

            String requestBody = new String(
                    exchange.getRequestBody().readAllBytes(),
                    StandardCharsets.UTF_8
            );

            Employee employee = GSON.fromJson(
                    requestBody,
                    Employee.class
            );

            validateEmployee(employee);

            String insertEmployee = """
                    INSERT INTO employees(name, email, designation)
                    VALUES (?, ?, ?)
                    """;

            try (
                    Connection connection = getConnection();
                    PreparedStatement statement =
                            connection.prepareStatement(insertEmployee)
            ) {

                statement.setString(1, employee.name);
                statement.setString(2, employee.email);
                statement.setString(3, employee.designation);

                statement.executeUpdate();
            }

            sendJsonResponse(
                    exchange,
                    201,
                    Map.of(
                            "message",
                            "Employee saved successfully"
                    )
            );

        } catch (
                JsonSyntaxException |
                IllegalArgumentException exception
        ) {

            sendJsonResponse(
                    exchange,
                    400,
                    Map.of(
                            "message",
                            exception.getMessage()
                    )
            );

        } catch (SQLException exception) {

            exception.printStackTrace();

            sendJsonResponse(
                    exchange,
                    500,
                    Map.of(
                            "message",
                            "Unable to save employee"
                    )
            );
        }
    }

    private static void validateEmployee(Employee employee) {

        if (employee == null) {
            throw new IllegalArgumentException(
                    "Request body is required"
            );
        }

        if (isBlank(employee.name)) {
            throw new IllegalArgumentException(
                    "Name is required"
            );
        }

        if (isBlank(employee.email)) {
            throw new IllegalArgumentException(
                    "Email is required"
            );
        }

        if (isBlank(employee.designation)) {
            throw new IllegalArgumentException(
                    "Designation is required"
            );
        }
    }

    private static boolean isBlank(String value) {

        return value == null || value.isBlank();
    }

    private static void sendJsonResponse(
            HttpExchange exchange,
            int statusCode,
            Object responseBody
    ) throws IOException {

        byte[] responseBytes = GSON
                .toJson(responseBody)
                .getBytes(StandardCharsets.UTF_8);

        exchange.getResponseHeaders().set(
                "Content-Type",
                "application/json; charset=UTF-8"
        );

        exchange.sendResponseHeaders(
                statusCode,
                responseBytes.length
        );

        try (
                OutputStream outputStream =
                        exchange.getResponseBody()
        ) {

            outputStream.write(responseBytes);
        }
    }

    private static class Employee {

        private String name;
        private String email;
        private String designation;
    }
}
