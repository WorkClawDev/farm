# 开发工作流规范

## 每次提交前必须执行的流程

```
1. 改代码
2. 运行 bash scripts/check.sh  ← 必须通过
3. 通过后 → git commit
4. 失败 → 看错误 → 修掉 → 回到第2步
```

## 编译检查脚本

路径：`scripts/check.sh`

检查内容：
- ✅ 脚本/编译错误（SCRIPT ERROR、Compile Error）
- ✅ 运行时错误（ERROR、FATAL）
- ✅ 18个核心系统初始化状态

用法：
```bash
bash scripts/check.sh
```

输出示例：
```
✅ GameManager
✅ TimeManager
...
✅ ItemDatabase (121 items)
✅ 所有检查通过 (18/18)
```

## Godot 环境

- 版本：4.6.1
- 路径：`/home/admin/tools/bin/godot`
- 项目路径：`/home/admin/gameboy-workspace/pastoral-tales`

无头检查（无画面）：
```bash
/home/admin/tools/bin/godot --headless --quit --path .
```

## 分支管理

- 主分支：`main`
- 每次 commit 前必须通过 check.sh
- 不要在未通过检查时提交代码

## 问题追踪

所有待修复问题记录在：`docs/todo.md`
