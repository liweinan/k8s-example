package main

import (
	"encoding/json"
	"reflect"
	"testing"
	"time"
)

// TestMarshalling verifies that the User struct is marshalled into the expected JSON format.
func TestMarshalling(t *testing.T) {
	// We use a fixed timestamp for a predictable JSON output.
	fixedTime := time.Date(2023, 1, 1, 12, 0, 0, 0, time.UTC)

	user := User{
		Metadata: Metadata{
			ID:                123, // This will be overridden
			CreationTimestamp: fixedTime,
		},
		ID:       999, // This is the overriding field
		Username: "testuser",
		IsActive: true,
		Profile: Profile{
			ID:      456,
			Website: "https://test.com",
		},
		Tags:     []string{"test", "go"},
		Password: "secret-password",
	}

	// Marshal the user struct to JSON
	jsonData, err := json.Marshal(user)
	if err != nil {
		t.Fatalf("Failed to marshal user: %v", err)
	}

	// We unmarshal the result into a map to check the fields.
	// This is a robust way to test the JSON structure without depending on key order.
	var resultMap map[string]interface{}
	if err := json.Unmarshal(jsonData, &resultMap); err != nil {
		t.Fatalf("Failed to unmarshal result map: %v", err)
	}

	// --- VERIFY FIELD OVERRIDE ---
	// Check that the top-level 'id' is from User.ID (999), not Metadata.ID (123).
	if id, ok := resultMap["id"].(float64); !ok || id != 999 {
		t.Errorf("Expected top-level 'id' to be 999 due to override, got %v", resultMap["id"])
	}
	if ts, ok := resultMap["creationTimestamp"].(string); !ok || ts != "2023-01-01T12:00:00Z" {
		t.Errorf("Expected top-level 'creationTimestamp' to be '2023-01-01T12:00:00Z', got '%s'", ts)
	}

	// --- VERIFY OTHER FIELDS ---
	if username := resultMap["username"].(string); username != "testuser" {
		t.Errorf("Expected username to be 'testuser', got '%s'", username)
	}

	// Verify that the password field is not present due to `json:"-"`
	if _, exists := resultMap["password"]; exists {
		t.Error("Expected password field to be omitted, but it exists")
	}

	// --- VERIFY NON-INLINE (NESTED) BEHAVIOR ---
	// Check that the Profile struct is a nested object with its own ID.
	profileMap, ok := resultMap["profile"].(map[string]interface{})
	if !ok {
		t.Fatalf("Expected 'profile' to be a nested object")
	}
	if id, ok := profileMap["id"].(float64); !ok || id != 456 {
		t.Errorf("Expected profile id to be 456, got %v", profileMap["id"])
	}
	if website, ok := profileMap["website"].(string); !ok || website != "https://test.com" {
		t.Errorf("Expected profile website to be 'https://test.com', got '%s'", profileMap["website"])
	}
}

// TestUnmarshalling verifies that a JSON string is correctly unmarshalled into the User struct.
func TestUnmarshalling(t *testing.T) {
	jsonString := `{
	  "id": 888,
	  "creationTimestamp": "2024-01-01T00:00:00Z",
	  "username": "testunmarshal",
	  "isActive": true,
	  "profile": {
		"id": 777,
		"location": "Test City"
	  },
	  "tags": ["a", "b"]
	}`

	// The JSON string has "id" and "creationTimestamp" at the top level.
	// The unmarshaller should correctly place them into the embedded `User.Metadata` struct
	// because of the `json:",inline"` tag.
	var user User
	err := json.Unmarshal([]byte(jsonString), &user)
	if err != nil {
		t.Fatalf("Failed to unmarshal JSON: %v", err)
	}

	// Expected struct after unmarshalling
	expectedTime, _ := time.Parse(time.RFC3339, "2024-01-01T00:00:00Z")
	expectedUser := User{
		// The top-level "id" from the JSON goes into the outer User.ID field.
		// The inlined Metadata.ID is left as its zero value.
		Metadata: Metadata{
			ID:                0,
			CreationTimestamp: expectedTime,
		},
		ID:       888,
		Username: "testunmarshal",
		IsActive: true,
		Profile: Profile{
			ID:       777,
			Location: "Test City",
		},
		Tags: []string{"a", "b"},
	}

	// Use reflect.DeepEqual for a comprehensive comparison of the structs.
	if !reflect.DeepEqual(user, expectedUser) {
		t.Errorf("Unmarshalled user does not match expected.\nGot:    %+v\nExpect: %+v", user, expectedUser)
	}
}
