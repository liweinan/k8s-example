package main

import (
	"fmt"
	"log"
)

// FeatureGateName 定义功能门控的名称类型
type FeatureGateName string

const (
	// FeatureGateMyNewFeature 新功能的 FeatureGate
	FeatureGateMyNewFeature FeatureGateName = "MyNewFeature"
	// FeatureGateAdvancedLogging 高级日志功能的 FeatureGate
	FeatureGateAdvancedLogging FeatureGateName = "AdvancedLogging"
	// FeatureGateCaching 缓存功能的 FeatureGate
	FeatureGateCaching FeatureGateName = "Caching"
)

// FeatureGate 简单的 FeatureGate 接口
type FeatureGate interface {
	Enabled(key FeatureGateName) bool
}

// featureGate 实现
type featureGate struct {
	enabled map[FeatureGateName]bool
}

// NewFeatureGate 创建新的 FeatureGate
func NewFeatureGate(enabled []FeatureGateName) FeatureGate {
	enabledMap := make(map[FeatureGateName]bool)
	for _, name := range enabled {
		enabledMap[name] = true
	}
	return &featureGate{enabled: enabledMap}
}

// Enabled 检查功能是否启用
func (fg *featureGate) Enabled(key FeatureGateName) bool {
	return fg.enabled[key]
}

// ============================================
// 业务逻辑：使用 FeatureGate 控制功能
// ============================================

// processRequest 处理请求，根据 FeatureGate 决定使用新功能还是旧功能
func processRequest(fg FeatureGate, data string) {
	if fg.Enabled(FeatureGateMyNewFeature) {
		// 新功能：使用新的处理方式
		processWithNewFeature(data)
	} else {
		// 旧功能：使用传统处理方式
		processWithLegacyFeature(data)
	}
}

// processWithNewFeature 新功能的实现
func processWithNewFeature(data string) {
	fmt.Printf("[新功能] 处理数据: %s\n", data)
	fmt.Println("  - 使用优化的算法")
	fmt.Println("  - 支持更多特性")
}

// processWithLegacyFeature 旧功能的实现
func processWithLegacyFeature(data string) {
	fmt.Printf("[旧功能] 处理数据: %s\n", data)
	fmt.Println("  - 使用传统算法")
}

// processRequestWithMultipleGates 处理请求，根据多个 FeatureGate 决定功能组合
func processRequestWithMultipleGates(fg FeatureGate, data string) {
	fmt.Printf("处理数据: %s\n", data)

	// 检查各个功能是否启用
	hasNewFeature := fg.Enabled(FeatureGateMyNewFeature)
	hasAdvancedLogging := fg.Enabled(FeatureGateAdvancedLogging)
	hasCaching := fg.Enabled(FeatureGateCaching)

	fmt.Printf("  - MyNewFeature: %v\n", hasNewFeature)
	fmt.Printf("  - AdvancedLogging: %v\n", hasAdvancedLogging)
	fmt.Printf("  - Caching: %v\n", hasCaching)

	// 根据功能组合执行不同的处理逻辑
	if hasNewFeature {
		processWithNewFeature(data)
	} else {
		processWithLegacyFeature(data)
	}

	if hasAdvancedLogging {
		fmt.Println("  - 启用高级日志记录")
	}

	if hasCaching {
		fmt.Println("  - 启用缓存机制")
	}
}

// ============================================
// 主程序演示
// ============================================

func main() {
	log.Println("=== FeatureGate 示例 ===\n")

	// 场景 1: FeatureGate 未启用
	fmt.Println("场景 1: FeatureGate 未启用")
	fgDisabled := NewFeatureGate([]FeatureGateName{}) // 空列表，功能未启用
	processRequest(fgDisabled, "test-data-1")
	fmt.Println()

	// 场景 2: FeatureGate 已启用
	fmt.Println("场景 2: FeatureGate 已启用")
	fgEnabled := NewFeatureGate([]FeatureGateName{FeatureGateMyNewFeature})
	processRequest(fgEnabled, "test-data-2")
	fmt.Println()

	// 场景 3: 多个 FeatureGate
	fmt.Println("场景 3: 多个 FeatureGate")
	fgMultiple := NewFeatureGate([]FeatureGateName{
		FeatureGateMyNewFeature,
		FeatureGateAdvancedLogging,
		FeatureGateCaching,
	})
	processRequestWithMultipleGates(fgMultiple, "test-data-3")
	fmt.Println()
}
