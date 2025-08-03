# Metadata Parser

一个用于解析 Go 文件中 kubebuilder 标记的工具。

## 功能

这个工具可以解析 Go 源代码文件中的 kubebuilder 标记，包括：

- **结构体级别的标记**：如 `+kubebuilder:object:root=true`
- **字段级别的标记**：如 `+required`、`+optional` 等

## 使用方法

### 基本用法
```bash
# 解析默认文件 (api/v1/types.go)
go run main.go

# 解析指定文件
go run main.go path/to/your/file.go
```

### 输出示例

```
🔍 Parsing kubebuilder metadata from file: api/v1/types.go

📊 Found 3 struct(s) with kubebuilder metadata:

🏗️  Struct: Guestbook
   📋 Struct-level markers (2):
      • kubebuilder:object:root=true
      • kubebuilder:subresource:status
   🔧 Field-level markers (2 fields, 2 with markers):
      Field: Spec
         • required
      Field: Status
         • optional
   --------------------------------------------------
🏗️  Struct: GuestbookSpec
   📋 Struct-level markers: (none)
   🔧 Field-level markers (1 fields, 0 with markers):
   --------------------------------------------------
🏗️  Struct: GuestbookStatus
   📋 Struct-level markers: (none)
   🔧 Field-level markers: (no fields)

✅ Parsing completed successfully!
```

## 支持的标记类型

### 结构体级别标记
- `+kubebuilder:object:root=true` - 标记为根对象
- `+kubebuilder:subresource:status` - 启用状态子资源
- `+kubebuilder:resource:scope=Cluster` - 设置资源作用域
- `+kubebuilder:printcolumn:name=Age,type=date,JSONPath=.metadata.creationTimestamp` - 定义打印列

### 字段级别标记
- `+required` - 标记字段为必需
- `+optional` - 标记字段为可选
- `+kubebuilder:validation:Required` - 验证标记
- `+kubebuilder:validation:Optional` - 可选验证
- `+kubebuilder:default=value` - 设置默认值
- `+kubebuilder:validation:MinLength=1` - 最小长度验证
- `+kubebuilder:validation:Maximum=10` - 最大长度验证
- `+listType=set` - 列表类型设置
- `+listMapKey=type` - 列表映射键

## 工作原理

1. **解析 Go AST**：使用 Go 的 `go/parser` 包解析源代码文件
2. **收集标记**：扫描所有注释，找到以 `// +` 开头的 kubebuilder 标记
3. **关联标记**：根据标记在代码中的位置，将其关联到相应的结构体或字段
4. **格式化输出**：以清晰易读的格式显示解析结果

## 项目结构

```
metadata-parser/
├── main.go              # 主程序
├── go.mod               # Go 模块文件
├── go.sum               # 依赖校验和
├── README.md            # 项目文档
└── api/
    └── v1/
        ├── types.go      # 示例类型定义
        └── test_types.go # 测试类型定义
```

## 学习资源

### Go Parser 基础教程
如果你想了解这个项目是如何使用 Go parser 的，请查看 [parser_example](../parser_example) 项目。这个项目包含：

- **完整的教程文档**：`README.md` - Go Parser 基础教程
- **实际代码示例**：`parser_examples.go` - 10个不同的解析示例
- **基本概念**：AST、Token、FileSet 等
- **基础使用方法**：文件解析、AST 遍历、注释处理
- **常用节点类型**：包声明、导入、类型、函数等
- **实际应用示例**：查找函数、类型、字段等
- **位置信息处理**：获取和关联位置信息
- **错误处理**：解析错误和验证
- **性能优化**：重用 FileSet、选择性遍历
- **常见陷阱**：空指针检查、类型断言等

## 依赖

- Go 1.24.2+
- `k8s.io/apimachinery` (用于示例类型定义)

## 扩展功能

这个工具可以很容易地扩展来支持：

- **多文件解析**：解析整个目录或多个文件
- **JSON/YAML 输出**：生成结构化的输出格式
- **标记验证**：验证 kubebuilder 标记的正确性
- **文档生成**：基于标记生成 API 文档
- **代码生成**：基于标记生成相关的 Kubernetes 资源

## 示例文件

项目包含两个示例文件：

1. **`api/v1/types.go`** - 基本的 kubebuilder 标记示例
2. **`api/v1/test_types.go`** - 更复杂的标记示例（包含验证、默认值等）

## 故障排除

### 常见问题

1. **文件路径错误**：确保指定的文件路径正确
2. **Go 语法错误**：确保 Go 文件语法正确
3. **标记格式错误**：确保 kubebuilder 标记格式正确（以 `// +` 开头）

### 调试

如果解析结果不符合预期，可以：

1. 检查文件中的注释格式
2. 确认标记与结构体/字段的位置关系
3. 验证 Go 语法是否正确 