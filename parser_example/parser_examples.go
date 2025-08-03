package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"log"
	"strings"
)

// 示例 1: 基本解析
func basicParsing() {
	fmt.Println("=== 基本解析示例 ===")

	fset := token.NewFileSet()
	node, err := parser.ParseFile(fset, "../metadata-parser/api/v1/types.go", nil, parser.ParseComments)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("包名: %s\n", node.Name.Name)
	fmt.Printf("导入数量: %d\n", len(node.Imports))
	fmt.Printf("声明数量: %d\n", len(node.Decls))
	fmt.Println()
}

// 示例 2: 查找所有类型
func findTypes() {
	fmt.Println("=== 查找所有类型 ===")

	fset := token.NewFileSet()
	node, err := parser.ParseFile(fset, "../metadata-parser/api/v1/types.go", nil, parser.ParseComments)
	if err != nil {
		log.Fatal(err)
	}

	var types []string
	ast.Inspect(node, func(n ast.Node) bool {
		if typeSpec, ok := n.(*ast.TypeSpec); ok {
			types = append(types, typeSpec.Name.Name)
		}
		return true
	})

	fmt.Printf("找到的类型: %v\n", types)
	fmt.Println()
}

// 示例 3: 查找所有函数
func findFunctions() {
	fmt.Println("=== 查找所有函数 ===")

	fset := token.NewFileSet()
	node, err := parser.ParseFile(fset, "../metadata-parser/api/v1/types.go", nil, parser.ParseComments)
	if err != nil {
		log.Fatal(err)
	}

	var functions []string
	ast.Inspect(node, func(n ast.Node) bool {
		if funcDecl, ok := n.(*ast.FuncDecl); ok {
			functions = append(functions, funcDecl.Name.Name)
		}
		return true
	})

	fmt.Printf("找到的函数: %v\n", functions)
	fmt.Println()
}

// 示例 4: 解析结构体字段
func parseStructFields() {
	fmt.Println("=== 解析结构体字段 ===")

	fset := token.NewFileSet()
	node, err := parser.ParseFile(fset, "../metadata-parser/api/v1/types.go", nil, parser.ParseComments)
	if err != nil {
		log.Fatal(err)
	}

	ast.Inspect(node, func(n ast.Node) bool {
		if typeSpec, ok := n.(*ast.TypeSpec); ok {
			if structType, ok := typeSpec.Type.(*ast.StructType); ok {
				fmt.Printf("结构体: %s\n", typeSpec.Name.Name)

				if structType.Fields != nil {
					fmt.Printf("  字段数量: %d\n", len(structType.Fields.List))
					for i, field := range structType.Fields.List {
						if len(field.Names) > 0 {
							fmt.Printf("    字段 %d: %s\n", i+1, field.Names[0].Name)
						}
					}
				}
				fmt.Println()
			}
		}
		return true
	})
}

// 示例 5: 查找 kubebuilder 标记
func findKubebuilderMarkers() {
	fmt.Println("=== 查找 kubebuilder 标记 ===")

	fset := token.NewFileSet()
	node, err := parser.ParseFile(fset, "../metadata-parser/api/v1/types.go", nil, parser.ParseComments)
	if err != nil {
		log.Fatal(err)
	}

	var markers []string
	for _, commentGroup := range node.Comments {
		for _, comment := range commentGroup.List {
			if strings.HasPrefix(comment.Text, "// +") {
				marker := strings.TrimSpace(strings.TrimPrefix(comment.Text, "// +"))
				markers = append(markers, marker)
			}
		}
	}

	fmt.Printf("找到的 kubebuilder 标记: %v\n", markers)
	fmt.Println()
}

// 示例 6: 位置信息
func showPositionInfo() {
	fmt.Println("=== 位置信息示例 ===")

	fset := token.NewFileSet()
	node, err := parser.ParseFile(fset, "../metadata-parser/api/v1/types.go", nil, parser.ParseComments)
	if err != nil {
		log.Fatal(err)
	}

	ast.Inspect(node, func(n ast.Node) bool {
		if typeSpec, ok := n.(*ast.TypeSpec); ok {
			pos := fset.Position(typeSpec.Pos())
			fmt.Printf("类型 '%s' 位于: 第 %d 行, 第 %d 列\n",
				typeSpec.Name.Name, pos.Line, pos.Column)
		}
		return true
	})
	fmt.Println()
}

// 示例 7: 注释关联
func associateComments() {
	fmt.Println("=== 注释关联示例 ===")

	fset := token.NewFileSet()
	node, err := parser.ParseFile(fset, "../metadata-parser/api/v1/types.go", nil, parser.ParseComments)
	if err != nil {
		log.Fatal(err)
	}

	// 收集标记位置
	markerPositions := make(map[int][]string)
	for _, commentGroup := range node.Comments {
		for _, comment := range commentGroup.List {
			if strings.HasPrefix(comment.Text, "// +") {
				marker := strings.TrimSpace(strings.TrimPrefix(comment.Text, "// +"))
				pos := fset.Position(comment.Pos()).Line
				markerPositions[pos] = append(markerPositions[pos], marker)
			}
		}
	}

	// 关联标记与结构体
	ast.Inspect(node, func(n ast.Node) bool {
		if typeSpec, ok := n.(*ast.TypeSpec); ok {
			structPos := fset.Position(typeSpec.Pos()).Line
			var associatedMarkers []string

			for line, markers := range markerPositions {
				if line >= structPos-3 && line < structPos {
					associatedMarkers = append(associatedMarkers, markers...)
				}
			}

			if len(associatedMarkers) > 0 {
				fmt.Printf("结构体 '%s' 的标记: %v\n",
					typeSpec.Name.Name, associatedMarkers)
			}
		}
		return true
	})
	fmt.Println()
}

// 示例 8: 解析导入语句
func parseImports() {
	fmt.Println("=== 解析导入语句 ===")

	fset := token.NewFileSet()
	node, err := parser.ParseFile(fset, "../metadata-parser/api/v1/types.go", nil, parser.ParseComments)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("导入语句数量: %d\n", len(node.Imports))
	for i, importSpec := range node.Imports {
		if importSpec.Name != nil {
			fmt.Printf("  导入 %d: %s -> %s\n", i+1, importSpec.Name.Name, importSpec.Path.Value)
		} else {
			fmt.Printf("  导入 %d: %s\n", i+1, importSpec.Path.Value)
		}
	}
	fmt.Println()
}

// 示例 9: 查找结构体标签
func findStructTags() {
	fmt.Println("=== 查找结构体标签 ===")

	fset := token.NewFileSet()
	node, err := parser.ParseFile(fset, "../metadata-parser/api/v1/types.go", nil, parser.ParseComments)
	if err != nil {
		log.Fatal(err)
	}

	ast.Inspect(node, func(n ast.Node) bool {
		if typeSpec, ok := n.(*ast.TypeSpec); ok {
			if structType, ok := typeSpec.Type.(*ast.StructType); ok {
				fmt.Printf("结构体: %s\n", typeSpec.Name.Name)

				if structType.Fields != nil {
					for _, field := range structType.Fields.List {
						if len(field.Names) > 0 && field.Tag != nil {
							fmt.Printf("  字段: %s, 标签: %s\n",
								field.Names[0].Name, field.Tag.Value)
						}
					}
				}
				fmt.Println()
			}
		}
		return true
	})
}

// 示例 10: 统计代码信息
func codeStatistics() {
	fmt.Println("=== 代码统计信息 ===")

	fset := token.NewFileSet()
	node, err := parser.ParseFile(fset, "../metadata-parser/api/v1/types.go", nil, parser.ParseComments)
	if err != nil {
		log.Fatal(err)
	}

	var (
		typeCount    int
		structCount  int
		fieldCount   int
		commentCount int
	)

	// 统计类型和结构体
	ast.Inspect(node, func(n ast.Node) bool {
		if typeSpec, ok := n.(*ast.TypeSpec); ok {
			typeCount++
			if _, ok := typeSpec.Type.(*ast.StructType); ok {
				structCount++
			}
		}
		return true
	})

	// 统计字段
	ast.Inspect(node, func(n ast.Node) bool {
		if structType, ok := n.(*ast.StructType); ok {
			if structType.Fields != nil {
				fieldCount += len(structType.Fields.List)
			}
		}
		return true
	})

	// 统计注释
	for _, commentGroup := range node.Comments {
		commentCount += len(commentGroup.List)
	}

	fmt.Printf("类型声明数量: %d\n", typeCount)
	fmt.Printf("结构体数量: %d\n", structCount)
	fmt.Printf("字段数量: %d\n", fieldCount)
	fmt.Printf("注释数量: %d\n", commentCount)
	fmt.Printf("导入数量: %d\n", len(node.Imports))
	fmt.Println()
}

func main() {
	fmt.Println("🔍 Go Parser 基础示例\n")

	basicParsing()
	findTypes()
	findFunctions()
	parseStructFields()
	findKubebuilderMarkers()
	showPositionInfo()
	associateComments()
	parseImports()
	findStructTags()
	codeStatistics()

	fmt.Println("✅ 所有示例执行完成!")
}
