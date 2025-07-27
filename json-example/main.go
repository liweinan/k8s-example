package main

import (
	"encoding/json"
	"fmt"
	"time"
)

// Metadata contains common metadata fields that we want to inline into the parent struct's JSON representation.
// This is similar to metav1.TypeMeta in the Kubernetes example.
type Metadata struct {
	// The `json:",inline"` tag on an embedded struct causes its fields to be treated as fields of the parent struct.
	// This is useful for promoting common fields to the top level of the JSON object.
	ID                int       `json:"id"`
	CreationTimestamp time.Time `json:"creationTimestamp"`
}

// Profile represents a standard nested object.
// It will appear as a JSON object under the "profile" key.
type Profile struct {
	Website  string `json:"website,omitempty"`
	Location string `json:"location,omitempty"`
}

// User is the main struct for our example.
// It demonstrates embedding structs for both inlining and standard nesting.
type User struct {
	// INLINE EXAMPLE: By embedding Metadata with the `json:",inline"` tag, its fields (ID, CreationTimestamp)
	// are "promoted" to the top level of the User JSON object.
	Metadata `json:",inline"`

	// Username is a regular field of the User struct.
	Username string `json:"username"`

	// IsActive demonstrates a boolean with a custom JSON key name.
	IsActive bool `json:"isActive"`

	// NON-INLINE (NESTED) EXAMPLE: Profile is a standard nested struct.
	// It will be represented as a nested JSON object under the "profile" key.
	Profile Profile `json:"profile"`

	// Tags demonstrates a slice of strings.
	Tags []string `json:"tags"`

	// Password is a field that we don't want to include in the JSON output.
	// The `json:"-"` tag ensures it's always omitted.
	Password string `json:"-"`
}

func main() {
	// --- 1. Marshalling (Go struct to JSON string) ---
	fmt.Println("--- Marshalling Example ---")

	// Create an instance of the User struct with some data.
	userToMarshal := User{
		Metadata: Metadata{
			ID:                123,
			CreationTimestamp: time.Now(),
		},
		Username: "johndoe",
		IsActive: true,
		Profile: Profile{
			Website:  "https://example.com",
			Location: "New York",
		},
		Tags:     []string{"go", "json", "example"},
		Password: "a-very-secret-password", // This field will be ignored
	}

	// Marshal the struct into a nicely formatted JSON byte slice.
	// json.MarshalIndent adds indentation for readability.
	jsonData, err := json.MarshalIndent(userToMarshal, "", "  ")
	if err != nil {
		fmt.Println("Error marshalling JSON:", err)
		return
	}

	// Print the resulting JSON string.
	// Notice how "id" and "creationTimestamp" are at the top level due to `inline`.
	// "profile" is a nested object.
	// "Password" is not present.
	fmt.Println(string(jsonData))
	fmt.Println()

	// --- 2. Unmarshalling (JSON string to Go struct) ---
	fmt.Println("--- Unmarshalling Example ---")

	// A raw JSON string that we want to parse.
	jsonString := `{
	  "id": 456,
	  "creationTimestamp": "2023-10-27T10:00:00Z",
	  "username": "janedoe",
	  "isActive": false,
	  "profile": {
		"location": "London"
	  },
	  "tags": ["developer", "testing"]
	}`

	// Create an empty User struct to hold the parsed data.
	var unmarshalledUser User

	// Unmarshal the JSON string (as a byte slice) into the struct.
	err = json.Unmarshal([]byte(jsonString), &unmarshalledUser)
	if err != nil {
		fmt.Println("Error unmarshalling JSON:", err)
		return
	}

	// Print the resulting struct to verify the data was parsed correctly.
	// The `%+v` format verb prints the struct with field names.
	fmt.Printf("Unmarshalled struct: %+v\n", unmarshalledUser)
	fmt.Printf("Username: %s, Location: %s\n", unmarshalledUser.Username, unmarshalledUser.Profile.Location)
}
