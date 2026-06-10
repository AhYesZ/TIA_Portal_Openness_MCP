# TIA Portal MCP — 开发者迁入指南

换到新电脑后，按这份清单操作即可恢复开发环境。

## 1. 克隆仓库

```bash
git clone https://github.com/bulaofen0036-coder/TIA_Portal_Openness_MCP.git
cd TIA_Portal_Openness_MCP
```

建议放在 `D:\Agent_KnowledgeBaseAndToolBox\ToolBox\TIA_Portal_MCP\`（与旧电脑一致，减少路径问题）。

## 2. 环境检查

```bash
# .NET SDK（需 8.0+）
dotnet --list-sdks

# .NET Framework 4.8 引用程序集
ls "C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.8\"

# TIA Portal V21 安装路径（默认：C:\Program Files\Siemens\Automation\Portal V21）
ls "C:\Program Files\Siemens\Automation\Portal V21\PublicAPI\V21\net48\"

# Windows 组 "Siemens TIA Openness"（确保当前用户已加入）
whoami /groups | findstr Openness
```

## 3. 编译

```bash
cd tools\tiaportal-mcp\src\TiaMcpServer

# 恢复 NuGet 包
dotnet restore TiaMcpServer.csproj

# 编译 V21 版本
dotnet build TiaMcpServer.csproj -c Release \
  -p:TiaPortalLocation="D:\Program Files\Siemens\Automation\Portal V21"

# 输出：bin\Release\net48\TiaMcpServer.exe
```

**如果 TIA 装在 C 盘**：
```bash
dotnet build TiaMcpServer.csproj -c Release \
  -p:TiaPortalLocation="C:\Program Files\Siemens\Automation\Portal V21"
```

**如果还装了 V20**（可选）：
```bash
dotnet build TiaMcpServer.V20.csproj -c Release \
  -p:TiaPortalLocation="D:\Program Files\Siemens\Automation\Portal V20"
```

## 4. 在 Hermes 中配置 MCP

编辑 Hermes 的 MCP 配置（`~/.hermes/config.yaml`），指向新编译的 exe：

```yaml
mcp_servers:
  tiaportal:
    command: "D:\\Agent_KnowledgeBaseAndToolBox\\ToolBox\\TIA_Portal_MCP\\tools\\tiaportal-mcp\\src\\TiaMcpServer\\bin\\Release\\net48\\TiaMcpServer.exe"
    args: []
```

然后重启 Hermes，调用 `Bootstrap` 验证。

## 5. 给 Agent 加载项目知识

在 Hermes 对话中输入：
> "请加载 skill: tia-mcp-dev 和 skill: tia-portal-mcp"

第一个 skill 包含完整的架构、开发流程、工具模板。第二个 skill 是操作 TIA 项目的使用手册。

## 6. 日常开发

```
修改代码 → dotnet build → 替换 exe → Hermes 中测试 → git commit → git push
```

## 项目快速参考

| 需求 | 文件 |
|------|------|
| 加新 MCP 工具 | `ModelContextProtocol/McpServer.cs` + `Siemens/Portal.cs` |
| 加 S7/OPC UA 工具 | `ModelContextProtocol/McpServer.Runtime.cs` + `Runtime/*.cs` |
| 改响应格式 | `ModelContextProtocol/Responses.cs` |
| 改版本兼容 | `Siemens/Capability.cs` |
| 改 CLI | `Cli/CliCommands.cs` |

## 外部依赖

- **Sharp7** — S7 协议库（NuGet: Sharp7 1.1.84）
- **Workstation.UaClient** — OPC UA 客户端（NuGet: 3.2.3）
- **ModelContextProtocol** — MCP 框架（NuGet: 0.3.0-preview.4）
- **Siemens.Collaboration.Net.\*** — 西门子 Openness 封装（NuGet，西门子私有源）
