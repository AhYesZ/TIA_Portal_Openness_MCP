using System;
using System.IO;
using System.Linq;
using System.Text.Json.Nodes;
using TiaMcpServer.ModelContextProtocol;

namespace TiaMcpServer.Test
{
    [TestClass]
    [DoNotParallelize]
    public class TestV2PlanCompletionAudit
    {
        [TestMethod]
        public void Test_V2PlanCompletionAudit_UsesCommercialFallbackHardGates()
        {
            var workspaceRoot = FindWorkspaceRoot();
            var reportDir = Path.Combine(Path.GetTempPath(), "tia_mcp_v2_audit_test_" + Guid.NewGuid().ToString("N"));
            var report = V2PlanCompletionAuditor.Run(workspaceRoot, reportDir);

            Assert.IsTrue(report["ok"]?.GetValue<bool>() == true, "Audit should run.");
            Assert.IsTrue(File.Exists(report["jsonPath"]?.ToString()), "JSON report should be written.");
            Assert.IsTrue(File.Exists(report["markdownPath"]?.ToString()), "Markdown report should be written.");
            Assert.IsTrue(report["hardGateCount"]?.GetValue<int>() >= 10, "V2 hard gate count should stay meaningful.");

            var blockedIds = (report["blockedItems"] as JsonArray ?? new JsonArray())
                .OfType<JsonObject>()
                .Select(x => x["id"]?.ToString() ?? "")
                .ToList();

            CollectionAssert.DoesNotContain(blockedIds, "online-current-value-real", "The V2 hard gate is now the OPC UA/S7 read-only DataProvider route.");
            CollectionAssert.DoesNotContain(blockedIds, "global-library-mastercopy-import", "The V2 hard gate is now global-library template learning plus native MCP rebuild.");

            var itemIds = (report["items"] as JsonArray ?? new JsonArray())
                .OfType<JsonObject>()
                .Select(x => x["id"]?.ToString() ?? "")
                .ToList();
            CollectionAssert.Contains(itemIds, "online-readonly-data-provider-plan", "Audit should include the read-only DataProvider route.");
            CollectionAssert.Contains(itemIds, "global-library-template-reuse", "Audit should include the global-library template reuse route.");
        }

        [TestMethod]
        public void Test_RunV2PlanCompletionAudit_McpTool_ReturnsReportPaths()
        {
            var workspaceRoot = FindWorkspaceRoot();
            var reportDir = Path.Combine(Path.GetTempPath(), "tia_mcp_v2_audit_tool_test_" + Guid.NewGuid().ToString("N"));
            var response = McpServer.RunV2PlanCompletionAudit(workspaceRoot, reportDir);

            Assert.IsTrue(response.Ok == true, response.Message);
            Assert.IsTrue(File.Exists(response.Data?["markdownPath"]?.ToString()), "MCP tool should return a readable report path.");
        }

        private static string FindWorkspaceRoot()
        {
            var dir = new DirectoryInfo(AppDomain.CurrentDomain.BaseDirectory);
            while (dir != null)
            {
                var candidate = Path.Combine(dir.FullName, "docs", "TIA_MCP_常见操作全覆盖方案_V2_二次优化计划.md");
                if (File.Exists(candidate))
                    return dir.FullName;
                dir = dir.Parent;
            }

            throw new DirectoryNotFoundException("Cannot find workspace root containing V2 plan document.");
        }
    }
}
