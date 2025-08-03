# Go Parser 基础教程

## 概述

Go 的 `go/parser` 包是 Go 标准库中用于解析 Go 源代码的强大工具。它能够将 Go 代码解析为抽象语法树（AST），让我们可以程序化地分析和操作 Go 代码。

## 基本概念

### 1. AST (Abstract Syntax Tree)
AST 是源代码的树状表示，每个节点代表代码中的一个结构：
- **Package**: 包声明
- **Import**: 导入语句
- **Type**: 类型声明
- **Function**: 函数声明
- **Statement**: 语句
- **Expression**: 表达式

### 2. Token
Token 是代码的最小语法单位：
- 关键字：`package`, `import`, `func`, `type` 等
- 标识符：变量名、函数名等
- 字面量：字符串、数字等
- 操作符：`+`, `-`, `=`, `==` 等

### 3. FileSet
FileSet 管理多个文件的位置信息，用于错误报告和调试。

## 基础使用方法

### 1. 基本解析

```go
package main

import (
    "fmt"
    "go/parser"
    "go/token"
)

func main() {
    // 创建文件集
    fset := token.NewFileSet()
    
    // 解析文件
    node, err := parser.ParseFile(fset, "example.go", nil, parser.ParseComments)
    if err != nil {
        panic(err)
    }
    
    fmt.Printf("Package: %s\n", node.Name.Name)
}
```

### 2. 遍历 AST

```go
import "go/ast"

// 使用 ast.Inspect 遍历所有节点
ast.Inspect(node, func(n ast.Node) bool {
    switch x := n.(type) {
    case *ast.FuncDecl:
        fmt.Printf("Function: %s\n", x.Name.Name)
    case *ast.TypeSpec:
        fmt.Printf("Type: %s\n", x.Name.Name)
    }
    return true // 继续遍历
})
```

### 3. 解析注释

```go
// 解析包含注释的代码
node, err := parser.ParseFile(fset, "file.go", nil, parser.ParseComments)

// 访问注释
for _, commentGroup := range node.Comments {
    for _, comment := range commentGroup.List {
        fmt.Printf("Comment: %s\n", comment.Text)
    }
}
```

## 常用节点类型

### 1. 包声明
```go
type Package struct {
    Name string // 包名
}
```

### 2. 导入声明
```go
type ImportSpec struct {
    Name *Ident // 别名（可选）
    Path *BasicLit // 导入路径
}
```

### 3. 类型声明
```go
type TypeSpec struct {
    Name *Ident // 类型名
    Type Expr   // 类型定义
    Doc  *CommentGroup // 文档注释
}
```

### 4. 函数声明
```go
type FuncDecl struct {
    Recv *FieldList // 接收者（方法）
    Name *Ident     // 函数名
    Type *FuncType  // 函数类型
    Body *BlockStmt // 函数体
    Doc  *CommentGroup // 文档注释
}
```

### 5. 结构体类型
```go
type StructType struct {
    Fields *FieldList // 字段列表
}
```

## 实际应用示例

### 1. 查找所有函数

```go
func findFunctions(node *ast.File) []string {
    var functions []string
    
    ast.Inspect(node, func(n ast.Node) bool {
        if funcDecl, ok := n.(*ast.FuncDecl); ok {
            functions = append(functions, funcDecl.Name.Name)
        }
        return true
    })
    
    return functions
}
```

### 2. 查找所有类型

```go
func findTypes(node *ast.File) []string {
    var types []string
    
    ast.Inspect(node, func(n ast.Node) bool {
        if typeSpec, ok := n.(*ast.TypeSpec); ok {
            types = append(types, typeSpec.Name.Name)
        }
        return true
    })
    
    return types
}
```

### 3. 解析结构体字段

```go
func parseStructFields(structType *ast.StructType) []string {
    var fields []string
    
    if structType.Fields != nil {
        for _, field := range structType.Fields.List {
            for _, name := range field.Names {
                fields = append(fields, name.Name)
            }
        }
    }
    
    return fields
}
```

### 4. 查找特定注释

```go
func findKubebuilderMarkers(node *ast.File) []string {
    var markers []string
    
    for _, commentGroup := range node.Comments {
        for _, comment := range commentGroup.List {
            if strings.HasPrefix(comment.Text, "// +") {
                marker := strings.TrimSpace(strings.TrimPrefix(comment.Text, "// +"))
                markers = append(markers, marker)
            }
        }
    }
    
    return markers
}
```

## 位置信息

### 1. 获取位置
```go
fset := token.NewFileSet()
node, _ := parser.ParseFile(fset, "file.go", nil, parser.ParseComments)

// 获取节点位置
pos := fset.Position(node.Pos())
fmt.Printf("File: %s, Line: %d, Column: %d\n", 
    pos.Filename, pos.Line, pos.Column)
```

### 2. 位置关联
```go
// 将注释与最近的声明关联
func associateComments(node *ast.File, fset *token.FileSet) {
    markerPositions := make(map[int][]string)
    
    // 收集所有标记的位置
    for _, commentGroup := range node.Comments {
        for _, comment := range commentGroup.List {
            if strings.HasPrefix(comment.Text, "// +") {
                pos := fset.Position(comment.Pos()).Line
                marker := strings.TrimSpace(strings.TrimPrefix(comment.Text, "// +"))
                markerPositions[pos] = append(markerPositions[pos], marker)
            }
        }
    }
    
    // 关联标记与声明
    ast.Inspect(node, func(n ast.Node) bool {
        if typeSpec, ok := n.(*ast.TypeSpec); ok {
            structPos := fset.Position(typeSpec.Pos()).Line
            for line, markers := range markerPositions {
                if line >= structPos-3 && line < structPos {
                    fmt.Printf("Struct %s has markers: %v\n", 
                        typeSpec.Name.Name, markers)
                }
            }
        }
        return true
    })
}
```

## 错误处理

### 1. 解析错误
```go
node, err := parser.ParseFile(fset, "file.go", nil, parser.ParseComments)
if err != nil {
    if parseErr, ok := err.(scanner.ErrorList); ok {
        for _, e := range parseErr {
            fmt.Printf("Error at %s: %s\n", e.Pos, e.Msg)
        }
    } else {
        fmt.Printf("Parse error: %v\n", err)
    }
    return
}
```

### 2. 验证 AST
```go
func validateAST(node *ast.File) error {
    var errors []string
    
    ast.Inspect(node, func(n ast.Node) bool {
        // 检查未解析的节点
        if n != nil && reflect.ValueOf(n).IsNil() {
            errors = append(errors, "Found nil node")
        }
        return true
    })
    
    if len(errors) > 0 {
        return fmt.Errorf("AST validation failed: %v", errors)
    }
    return nil
}
```

## 性能优化

### 1. 重用 FileSet
```go
fset := token.NewFileSet()

// 解析多个文件时重用同一个 FileSet
for _, filename := range files {
    node, err := parser.ParseFile(fset, filename, nil, parser.ParseComments)
    // 处理节点...
}
```

### 2. 选择性遍历
```go
ast.Inspect(node, func(n ast.Node) bool {
    // 只处理特定类型的节点
    switch n.(type) {
    case *ast.FuncDecl, *ast.TypeSpec:
        // 处理这些节点
        return true
    default:
        // 跳过其他节点
        return false
    }
})
```

## 常见陷阱

### 1. 空指针检查
```go
// 总是检查字段是否为 nil
if structType.Fields != nil {
    for _, field := range structType.Fields.List {
        // 处理字段...
    }
}
```

### 2. 类型断言
```go
// 使用类型断言检查节点类型
if typeSpec, ok := n.(*ast.TypeSpec); ok {
    // 处理类型声明
} else if funcDecl, ok := n.(*ast.FuncDecl); ok {
    // 处理函数声明
}
```

### 3. 位置信息
```go
// 注意位置信息可能为空
if node.Pos().IsValid() {
    pos := fset.Position(node.Pos())
    fmt.Printf("Position: %s\n", pos)
}
```

## 总结

Go parser 是一个强大的工具，可以用于：
- 代码分析
- 代码生成
- 代码重构
- 静态分析
- 文档生成

通过理解 AST 结构和掌握基本的遍历方法，你可以构建各种有用的代码处理工具。 