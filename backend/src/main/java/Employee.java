public class Employee {

    private String name;
    private String email;
    private String designation;

    public Employee() {
        // Required for JSON deserialization.
    }

    public Employee(
            String name,
            String email,
            String designation
    ) {
        this.name = name;
        this.email = email;
        this.designation = designation;
    }

    public String getName() {
        return name;
    }

    public String getEmail() {
        return email;
    }

    public String getDesignation() {
        return designation;
    }
}
