# 贴贴便利贴 (QuickNote)

macOS 菜单栏快捷复制工具。按 `⌥V` 弹出浮窗，点任意一条便利贴，内容立即复制到剪贴板，切回目标窗口按 `⌘V` 即可粘贴。

## 功能

- **一键复制**：点击卡片即复制；多行内容支持逐行复制，也可一键复制全部
- **分类管理**：自定义分类与颜色，分类可增删改，删除分类时条目自动移至首个分类
- **搜索**：按标题或内容实时过滤
- **全局快捷键**：`⌥V` 随时呼出/隐藏（被占用时会有提示）
- **钉住窗口**：钉住后复制不自动隐藏，适合连续复制多条
- **开机自启**：菜单栏右键可开关
- **本地存储**：数据只存 `~/Library/Application Support/QuickNote/snippets.json`，不联网、不上传

## 构建

```bash
./build.sh            # 装到 ~/Applications/QuickNote.app
./build.sh /自定义路径/QuickNote.app
```

需要 macOS 13+、Apple Silicon。

## 技术

Swift + SwiftUI + AppKit，纯标准库，无第三方依赖。全局热键走 Carbon `RegisterEventHotKey`（无需辅助功能权限）。
