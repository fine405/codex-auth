.PHONY: build run dev clean bundle zig

PROJECT_ROOT := $(shell cd .. && pwd)
APP_NAME := Codex Auth
APP_BUNDLE := $(APP_NAME).app
ZIG_BINARY := $(PROJECT_ROOT)/zig-out/bin/codex-auth

# 开发模式：直接 swift run
dev:
	swift run

# 构建 Zig CLI 二进制（可选，需要兼容的 Zig 版本）
zig:
	@echo "==> 构建 Zig CLI..."
	cd $(PROJECT_ROOT) && zig build -Doptimize=ReleaseSafe
	@echo "==> Zig CLI 构建完成: $(ZIG_BINARY)"

# 构建 Swift 可执行文件
swift:
	swift build -c release

# 创建 .app Bundle（不含 Zig CLI）
bundle: swift
	@echo "==> 创建 $(APP_BUNDLE)..."
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp .build/release/CodexAuthApp "$(APP_BUNDLE)/Contents/MacOS/"
	cp Info.plist "$(APP_BUNDLE)/Contents/"
	@if [ -f "$(ZIG_BINARY)" ]; then \
		cp "$(ZIG_BINARY)" "$(APP_BUNDLE)/Contents/Resources/"; \
		echo "==> 已内嵌 codex-auth CLI"; \
	else \
		echo "==> 提示: Zig CLI 未内嵌（可选，运行 make zig 构建）"; \
	fi
	@echo "==> Ad-hoc 签名..."
	codesign --force --deep --sign - "$(APP_BUNDLE)"
	@echo "==> $(APP_BUNDLE) 构建完成 ✓"

# 默认构建 = 仅 Swift（菜单栏应用独立工作，不依赖 Zig CLI）
build: bundle

# 完整构建（Zig + Swift + Bundle）
build-full: zig bundle

# 运行 .app
run: bundle
	open "$(APP_BUNDLE)"

# 清理
clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)" .build
