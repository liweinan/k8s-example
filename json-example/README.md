# Go JSON Marshalling and Unmarshalling Example

This project provides a clear, commented example of how to handle JSON serialization (marshalling) and deserialization (unmarshalling) in Go.

## Key Concepts Demonstrated

*   **Struct to JSON (Marshalling)**: Converting a Go struct into a JSON string.
*   **JSON to Struct (Unmarshalling)**: Parsing a JSON string into a Go struct.
*   **Struct Tags**: Using `json` struct tags to control the output:
    *   `json:"fieldName"`: Customizes the name of the JSON key.
    *   `json:"-"`: Omits a field from the JSON output entirely.
    *   `json:",omitempty"`: Excludes a field from the output if it holds a zero-value (e.g., empty string, 0, false).
    *   `json:",inline"`: Promotes the fields of an embedded struct to the top level of the parent JSON object.
*   **Nested Structs**: How to handle both standard nested objects and inlined (flattened) objects.
*   **Unit Testing**: Basic tests for the marshalling and unmarshalling logic using Go's built-in `testing` package.

## How to Run

### Prerequisites

*   Go (version 1.18 or later)

### Run the Main Program

To run the main example which demonstrates marshalling and unmarshalling, execute the following command:

```bash
go run main.go
```

You will see output showing the generated JSON and the struct populated from a JSON string.

### Run the Tests

To verify that the logic is working correctly, run the unit tests:

```bash
go test -v
```

You should see output indicating that all tests have passed.
