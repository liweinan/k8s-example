# Go JSON Marshalling and Unmarshalling Example

This project provides a clear, commented example of how to handle JSON serialization (marshalling) and deserialization (unmarshalling) in Go.

## Key Concepts Demonstrated

*   **Struct to JSON (Marshalling)**: Converting a Go struct into a JSON string.
*   **JSON to Struct (Unmarshalling)**: Parsing a JSON string into a Go struct.
*   **Struct Tags**: Using `json` struct tags to control the output.
*   **Inline vs. Nested Structs**:
    *   **Inline (Flattened)**: The `Metadata` struct is embedded with a `json:",inline"` tag. This promotes its fields (`id`, `creationTimestamp`) to the top level of the parent JSON object, which is a common pattern in Kubernetes APIs.
    *   **Nested (Non-inline)**: The `Profile` struct is included as a regular field. This results in a standard nested JSON object under the `profile` key.
*   **Other Tag Examples**:
    *   `json:"fieldName"`: Customizes the name of a JSON key.
    *   `json:",omitempty"`: Excludes a field from the output if it holds a zero-value.
    *   `json:"-"`: Omits a field from the JSON output entirely.
*   **Unit Testing**: Basic tests for the marshalling and unmarshalling logic using Go's built-in `testing` package.

## Field Precedence and Overriding

This example also demonstrates how Go's `encoding/json` package handles name collisions between fields in an outer struct and an inlined inner struct.

**The Rule**: The field from the **outer-most struct wins**.

In `main.go`, both `User` and the inlined `Metadata` have a field that maps to the `"id"` JSON key. When marshalling, the value from `User.ID` is used for the top-level `"id"`, overriding the value from `Metadata.ID`. When unmarshalling, the top-level `"id"` from the JSON is placed into the `User.ID` field.

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
