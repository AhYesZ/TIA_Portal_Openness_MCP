using ModelContextProtocol.Server;
using System;
using System.IO;
using System.Linq;
using System.Reflection;
using TiaMcpServer.ModelContextProtocol;

namespace TiaMcpServer.Test
{
    [TestClass]
    [DoNotParallelize]
    public class TestHmiUnifiedThemeLayout
    {
        [TestMethod]
        public void Test_UnifiedHmiThemeAndLayout_BuildDesignJsonOffline()
        {
            var theme = McpServer.BuildUnifiedHmiThemeDesignJson(@"{
  ""name"": ""PlantClean"",
  ""palette"": {
    ""Page"": ""0xFFF4F6F8"",
    ""Surface"": ""0xFFFFFFFF"",
    ""Text"": ""0xFF172033"",
    ""Border"": ""0xFFD7DEE8""
  }
}");
            Assert.IsTrue(theme.Ok == true, theme.Message);
            Assert.AreEqual(true, theme.Data?["offlineOnly"]?.GetValue<bool>());
            Assert.AreEqual("ApplyUnifiedHmiScreenDesignJson", theme.Data?["applyTool"]?.ToString());
            Assert.AreEqual("0xFFF4F6F8", theme.Data?["screen"]?["BackColor"]?.ToString());

            var layout = McpServer.BuildUnifiedHmiLayoutDesignJson(@"{
  ""grid"": 8,
  ""left"": 24,
  ""top"": 72,
  ""gap"": 16,
  ""columns"": 2,
  ""cellWidth"": 160,
  ""cellHeight"": 80,
  ""items"": [
    { ""name"": ""Card_Run"", ""type"": ""Rectangle"", ""text"": ""运行"" },
    { ""name"": ""Card_Fault"", ""type"": ""Rectangle"", ""colSpan"": 2, ""text"": ""故障"" }
  ]
}");
            Assert.IsTrue(layout.Ok == true, layout.Message);
            var items = layout.Data?["items"]?.AsArray();
            Assert.AreEqual(2, items?.Count);
            Assert.AreEqual("Card_Run", items?[0]?["name"]?.ToString());
            Assert.AreEqual("24", items?[0]?["left"]?.ToString());
            Assert.AreEqual("200", items?[1]?["left"]?.ToString());
            Assert.AreEqual("336", items?[1]?["width"]?.ToString());
        }

        [TestMethod]
        public void Test_UnifiedHmiThemeAndLayout_ToolDescriptionsExposeContracts()
        {
            foreach (var toolName in new[]
            {
                "BuildUnifiedHmiThemeDesignJson",
                "BuildUnifiedHmiLayoutDesignJson",
                "ApplyUnifiedHmiTheme",
                "ApplyUnifiedHmiLayout"
            })
            {
                var method = typeof(McpServer).GetMethod(toolName, BindingFlags.Public | BindingFlags.Static);
                Assert.IsNotNull(method, toolName + " 必须公开。");
                var tool = method!.GetCustomAttributes(typeof(McpServerToolAttribute), false).OfType<McpServerToolAttribute>().SingleOrDefault();
                Assert.IsNotNull(tool, toolName + " 必须是 MCP 工具。");
                var description = method.GetCustomAttributes(typeof(System.ComponentModel.DescriptionAttribute), false)
                    .OfType<System.ComponentModel.DescriptionAttribute>()
                    .SingleOrDefault()?.Description ?? "";
                StringAssert.Contains(description, "[HMI-Unified]");
                if (toolName.StartsWith("Build", StringComparison.OrdinalIgnoreCase))
                {
                    StringAssert.Contains(description, "Offline");
                }
                else
                {
                    StringAssert.Contains(description, "readback");
                }
            }
        }

        [TestMethod]
        public void Test_UnifiedHmiThemeLayoutDocumentation_ListsPublicContracts()
        {
            var docPath = FindRepoFile("docs", "tools", "hmi-unified-theme-layout.md");
            Assert.IsTrue(File.Exists(docPath), "Unified HMI Theme/Layout 文档必须存在。");
            var doc = File.ReadAllText(docPath!);
            foreach (var expected in new[]
            {
                "BuildUnifiedHmiThemeDesignJson",
                "BuildUnifiedHmiLayoutDesignJson",
                "ApplyUnifiedHmiTheme",
                "ApplyUnifiedHmiLayout",
                "ApplyUnifiedHmiScreenDesignJson",
                "DescribeHmiScreenItem",
                "readback",
                "SyntaxCheck"
            })
            {
                StringAssert.Contains(doc, expected);
            }
        }

        private static string? FindRepoFile(params string[] parts)
        {
            var dir = new DirectoryInfo(AppDomain.CurrentDomain.BaseDirectory);
            while (dir != null)
            {
                var candidate = Path.Combine(new[] { dir.FullName }.Concat(parts).ToArray());
                if (File.Exists(candidate))
                    return candidate;
                dir = dir.Parent;
            }

            return null;
        }
    }
}
