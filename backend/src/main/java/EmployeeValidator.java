public final class EmployeeValidator {

    private EmployeeValidator() {
        // Prevent creating instances of this utility class.
    }

    public static void validate(Employee employee) {

        if (employee == null) {
            throw new IllegalArgumentException(
                    "Request body is required"
            );
        }

        requireValue(
                employee.getName(),
                "Name is required"
        );

        requireValue(
                employee.getEmail(),
                "Email is required"
        );

        requireValue(
                employee.getDesignation(),
                "Designation is required"
        );

        if (!isValidEmail(employee.getEmail())) {
            throw new IllegalArgumentException(
                    "Email format is invalid"
            );
        }
    }

    private static void requireValue(
            String value,
            String message
    ) {

        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(message);
        }
    }

    private static boolean isValidEmail(String email) {

        return email.matches(
                "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"
        );
    }
}
