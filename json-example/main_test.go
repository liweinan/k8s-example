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
			ID:                123,
			CreationTimestamp: fixedTime,
		},
		Username: "testuser",
		IsActive: true,
		Profile: Profile{
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
	// This avoids issues with key ordering in the JSON string.
	var resultMap map[string]interface{}
	if err := json.Unmarshal(jsonData, &resultMap); err != nil {
		t.Fatalf("Failed to unmarshal result map: %v", err)
	}

	// Verify top-level fields from the inlined struct
	if id := resultMap["id"].(float64); id != 123 {
		t.Errorf("Expected id to be 123, got %v", id)
	}
	if ts := resultMap["creationTimestamp"].(string); ts != "2023-01-01T12:00:00Z" {
		t.Errorf("Expected creationTimestamp to be '2023-01-01T12:00:00Z', got '%s'", ts)
	}

	// Verify other fields
	if username := resultMap["username"].(string); username != "testuser" {
		t.Errorf("Expected username to be 'testuser', got '%s'", username)
	}

	// Verify that the password field is not present
	if _, exists := resultMap["password"]; exists {
		t.Error("Expected password field to be omitted, but it exists")
	}

	// Verify the nested profile object
	profileMap := resultMap["profile"].(map[string]interface{})
	if website := profileMap["website"].(string); website != "https://test.com" {
		t.Errorf("Expected profile website to be 'https://test.com', got '%s'", website)
	}
}

// TestUnmarshalling verifies that a JSON string is correctly unmarshalled into the User struct.
func TestUnmarshalling(t *testing.T) {
	jsonString := `{
	  "id": 999,
	  "creationTimestamp": "2024-01-01T00:00:00Z",
	  "username": "testunmarshal",
	  "isActive": true,
	  "profile": {
		"location": "Test City"
	  },
	  "tags": ["a", "b"]
	}`

	var user User
	err := json.Unmarshal([]byte(jsonString), &user)
	if err != nil {
		t.Fatalf("Failed to unmarshal JSON: %v", err)
	}

	// Expected struct after unmarshalling
	expectedTime, _ := time.Parse(time.RFC3339, "2024-01-01T00:00:00Z")
	expectedUser := User{
		Metadata: Metadata{
			ID:                999,
			CreationTimestamp: expectedTime,
		},
		Username: "testunmarshal",
		IsActive: true,
		Profile: Profile{
			Location: "Test City",
		},
		Tags: []string{"a", "b"},
	}

	// Use reflect.DeepEqual for a comprehensive comparison of the structs.
	if !reflect.DeepEqual(user, expectedUser) {
		t.Errorf("Unmarshalled user does not match expected.\nGot:    %+v\nExpect: %+v", user, expectedUser)
	}
}
