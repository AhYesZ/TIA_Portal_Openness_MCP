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
    public class TestGlobalLibraryMasterCopyImport
    {
        [TestMethod]
        public void Test_ImportMasterCopyFromGlobalLibrary_ToolDescriptionRequiresReadbackAndTemporaryProject()
        {
            var method = typeof(McpServer).GetMethod("ImportMasterCopyFromGlobalLibrary", BindingFlags.Public | BindingFlags.Static);
            Assert.IsNotNull(method, "ImportMasterCopyFromGlobalLibrary 必须公开。");

            var tool = method!.GetCustomAttributes(typeof(McpServerToolAttribute), false)
                .OfType<McpServerToolAttribute>()
                .SingleOrDefault();
            Assert.IsNotNull(tool, "ImportMasterCopyFromGlobalLibrary 必须是 MCP 工具。");

            var description = method.GetCustomAttributes(typeof(System.ComponentModel.DescriptionAttribute), false)
                .OfType<System.ComponentModel.DescriptionAttribute>()
                .SingleOrDefault()?.Description ?? "";

            StringAssert.Contains(description, "[HMI-Library]");
            StringAssert.Contains(description, "readback");
            StringAssert.Contains(description, "temporary project");
            StringAssert.Contains(description, "modifies the project");
        }

        [TestMethod]
        public void Test_GlobalLibraryImportResponse_ContainsEvidenceFields()
        {
            var type = typeof(ResponseGlobalLibraryImport);
            foreach (var propertyName in new[]
            {
                "Ok",
                "ResolvedLibraryFile",
                "MasterCopyName",
                "HmiSoftwarePath",
                "ScreenName",
                "ImportedItemName",
                "Attempts",
                "ReadbackItems",
                "Warnings",
                "Raw"
            })
            {
                Assert.IsNotNull(type.GetProperty(propertyName), propertyName + " 证据字段必须存在。");
            }
        }

        [TestMethod]
        public void Test_PlanGlobalLibraryTemplateReuse_IsOfflineNativeRebuildFallback()
        {
            var dir = Path.Combine(Path.GetTempPath(), "tia_mcp_global_library_template_reuse_" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(Path.Combine(dir, "System"));
            Directory.CreateDirectory(Path.Combine(dir, "XRef"));
            File.WriteAllText(Path.Combine(dir, "System", "PEData.plf"), "Screen Template MasterCopy Unified");
            File.WriteAllText(Path.Combine(dir, "System", "PEData.idx"), "Index");
            File.WriteAllBytes(Path.Combine(dir, "XRef", "XRef.db"), System.Text.Encoding.ASCII.GetBytes("SQLite format 3\0Template Screen MasterCopy"));

            try
            {
                var plan = McpServer.PlanGlobalLibraryTemplateReuse(dir, @"{""screenType"":""overview""}");
                Assert.IsTrue(plan.Ok == true, plan.Message);
                Assert.AreEqual("template-learn-and-native-rebuild", plan.Data?["strategy"]?.GetValue<string>());
                Assert.AreEqual(false, plan.Data?["directMasterCopyImportRequired"]?.GetValue<bool>());
                Assert.AreEqual(true, plan.Data?["commercialFallbackReady"]?.GetValue<bool>());
                Assert.AreEqual(true, plan.Data?["safety"]?["offlineOnly"]?.GetValue<bool>());
                Assert.AreEqual(false, plan.Data?["safety"]?["importsLibraryContent"]?.GetValue<bool>());
                Assert.AreEqual(false, plan.Data?["safety"]?["modifiesProject"]?.GetValue<bool>());
            }
            finally
            {
                Directory.Delete(dir, recursive: true);
            }
        }
    }
}
