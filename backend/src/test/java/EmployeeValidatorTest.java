import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class EmployeeValidatorTest {

    @Test
    void shouldAcceptValidEmployee() {

        Employee employee = new Employee(
                "Mustafa",
                "mustafa@example.com",
                "DevOps Engineer"
        );

        assertDoesNotThrow(
                () -> EmployeeValidator.validate(employee)
        );
    }

    @Test
    void shouldRejectMissingRequestBody() {

        IllegalArgumentException exception =
                assertThrows(
                        IllegalArgumentException.class,
                        () -> EmployeeValidator.validate(null)
                );

        assertEquals(
                "Request body is required",
                exception.getMessage()
        );
    }

    @Test
    void shouldRejectBlankName() {

        Employee employee = new Employee(
                "",
                "mustafa@example.com",
                "DevOps Engineer"
        );

        IllegalArgumentException exception =
                assertThrows(
                        IllegalArgumentException.class,
                        () -> EmployeeValidator.validate(employee)
                );

        assertEquals(
                "Name is required",
                exception.getMessage()
        );
    }

    @Test
    void shouldRejectBlankEmail() {

        Employee employee = new Employee(
                "Mustafa",
                "",
                "DevOps Engineer"
        );

        IllegalArgumentException exception =
                assertThrows(
                        IllegalArgumentException.class,
                        () -> EmployeeValidator.validate(employee)
                );

        assertEquals(
                "Email is required",
                exception.getMessage()
        );
    }

    @Test
    void shouldRejectInvalidEmail() {

        Employee employee = new Employee(
                "Mustafa",
                "invalid-email",
                "DevOps Engineer"
        );

        IllegalArgumentException exception =
                assertThrows(
                        IllegalArgumentException.class,
                        () -> EmployeeValidator.validate(employee)
                );

        assertEquals(
                "Email format is invalid",
                exception.getMessage()
        );
    }

    @Test
    void shouldRejectBlankDesignation() {

        Employee employee = new Employee(
                "Mustafa",
                "mustafa@example.com",
                ""
        );

        IllegalArgumentException exception =
                assertThrows(
                        IllegalArgumentException.class,
                        () -> EmployeeValidator.validate(employee)
                );

        assertEquals(
                "Designation is required",
                exception.getMessage()
        );
    }
}
