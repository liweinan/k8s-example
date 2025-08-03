package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"log"
	"os"
	"strings"
)

type StructInfo struct {
	Name    string
	Markers []string
	Fields  []FieldInfo
}

type FieldInfo struct {
	Name    string
	Markers []string
}

func main() {
	// Default file path
	filePath := "api/v1/types.go"

	// Check if a file path is provided as command line argument
	if len(os.Args) > 1 {
		filePath = os.Args[1]
	}

	// Create a new token set
	fset := token.NewFileSet()

	// Parse the file
	node, err := parser.ParseFile(fset, filePath, nil, parser.ParseComments)
	if err != nil {
		log.Fatalf("Failed to parse file %s: %v", filePath, err)
	}

	fmt.Printf("🔍 Parsing kubebuilder metadata from file: %s\n\n", filePath)

	var structs []StructInfo

	// First pass: collect all kubebuilder markers and their positions
	markerPositions := make(map[int][]string)
	for _, commentGroup := range node.Comments {
		for _, comment := range commentGroup.List {
			text := comment.Text
			if strings.HasPrefix(text, "// +") {
				markerText := strings.TrimSpace(strings.TrimPrefix(text, "// +"))
				pos := fset.Position(comment.Pos()).Line
				markerPositions[pos] = append(markerPositions[pos], markerText)
			}
		}
	}

	// Second pass: find type declarations and associate markers
	ast.Inspect(node, func(n ast.Node) bool {
		// We are only interested in type declarations
		typeSpec, ok := n.(*ast.TypeSpec)
		if !ok {
			return true
		}

		// We are only interested in struct types
		_, ok = typeSpec.Type.(*ast.StructType)
		if !ok {
			return true
		}

		structInfo := StructInfo{
			Name:    typeSpec.Name.Name,
			Markers: []string{},
			Fields:  []FieldInfo{},
		}

		// Find markers associated with this struct
		structPos := fset.Position(typeSpec.Pos()).Line
		for line, markers := range markerPositions {
			// Check if markers are within 3 lines before the struct declaration
			if line >= structPos-3 && line < structPos {
				structInfo.Markers = append(structInfo.Markers, markers...)
			}
		}

		// Process fields
		if structType, ok := typeSpec.Type.(*ast.StructType); ok && structType.Fields != nil {
			for _, field := range structType.Fields.List {
				if len(field.Names) > 0 {
					fieldInfo := FieldInfo{
						Name:    field.Names[0].Name,
						Markers: []string{},
					}

					// Find markers associated with this field
					fieldPos := fset.Position(field.Pos()).Line
					for line, markers := range markerPositions {
						// Check if markers are within 2 lines before the field declaration
						if line >= fieldPos-2 && line < fieldPos {
							fieldInfo.Markers = append(fieldInfo.Markers, markers...)
						}
					}

					structInfo.Fields = append(structInfo.Fields, fieldInfo)
				}
			}
		}

		structs = append(structs, structInfo)
		return true
	})

	// Display results
	fmt.Printf("📊 Found %d struct(s) with kubebuilder metadata:\n\n", len(structs))

	for i, structInfo := range structs {
		fmt.Printf("🏗️  Struct: %s\n", structInfo.Name)

		if len(structInfo.Markers) > 0 {
			fmt.Printf("   📋 Struct-level markers (%d):\n", len(structInfo.Markers))
			for _, marker := range structInfo.Markers {
				fmt.Printf("      • %s\n", marker)
			}
		} else {
			fmt.Printf("   📋 Struct-level markers: (none)\n")
		}

		fieldsWithMarkers := 0
		for _, field := range structInfo.Fields {
			if len(field.Markers) > 0 {
				fieldsWithMarkers++
			}
		}

		if len(structInfo.Fields) > 0 {
			fmt.Printf("   🔧 Field-level markers (%d fields, %d with markers):\n", len(structInfo.Fields), fieldsWithMarkers)
			for _, field := range structInfo.Fields {
				if len(field.Markers) > 0 {
					fmt.Printf("      Field: %s\n", field.Name)
					for _, marker := range field.Markers {
						fmt.Printf("         • %s\n", marker)
					}
				}
			}
		} else {
			fmt.Printf("   🔧 Field-level markers: (no fields)\n")
		}

		if i < len(structs)-1 {
			fmt.Println("   " + strings.Repeat("-", 50))
		}
	}

	fmt.Printf("\n✅ Parsing completed successfully!\n")
}
