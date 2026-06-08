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
    public class TestOnlineMonitoringSafety
    {
        [TestMethod]
        public void Test_OnlineMonitoringSafetySelfTest_Passes()
        {
            var report = McpServer.RunOnlineMonitoringSafetySelfTest();
            Assert.IsTrue(report.Ok == true, report.Message);
            Assert.IsTrue(report.Policy?.Any(x => x.Contains("读取") || x.Contains("read", StringComparison.OrdinalIgnoreCase)) == true, "安全策略必须明确在线监视只读。");
            Assert.IsTrue(report.Items?.Any(x => x.Id == "safety.no-force-tools" && x.Status == "pass") == true, "不得暴露强制相关 MCP 工具。");
            Assert.IsTrue(report.Items?.Any(x => x.Id == "safety.required-readonly-tools" && x.Status == "pass") == true, "在线只读工具族必须齐全。");
        }

        [TestMethod]
        public void Test_OnlineMonitoringToolDescriptions_AreReadOnly()
        {
            foreach (var toolName in new[]
            {
                "GetPlcWatchTables",
                "ExportPlcWatchTable",
                "ExportPlcWatchTablesToDirectory",
                "ProbePlcMonitorOnlineCapabilities",
                "PlanOnlineReadOnlyMonitoring",
                "PlanOnlineReadOnlyDataProvider",
                "RunOnlineMonitoringSafetySelfTest"
            })
            {
                var method = typeof(McpServer).GetMethod(toolName, BindingFlags.Public | BindingFlags.Static);
                Assert.IsNotNull(method, toolName + " 必须公开。");
                var tool = method!.GetCustomAttributes(typeof(McpServerToolAttribute), false).OfType<McpServerToolAttribute>().SingleOrDefault();
                Assert.IsNotNull(tool, toolName + " 必须是 MCP 工具。");
                var description = GetDescription(method);
                Assert.IsTrue(description.IndexOf("read-only", StringComparison.OrdinalIgnoreCase) >= 0, toolName + " 描述必须明确只读。");
                Assert.IsFalse(description.IndexOf("force operation", StringComparison.OrdinalIgnoreCase) >= 0 && toolName.StartsWith("GetPlc", StringComparison.OrdinalIgnoreCase), toolName + " 不应暗示可执行强制操作。");
            }
        }

        [TestMethod]
        public void Test_OnlineMonitoringNoUnsafeToolNames()
        {
            var unsafeNames = typeof(McpServer)
                .GetMethods(BindingFlags.Public | BindingFlags.Static)
                .Where(x => x.GetCustomAttributes(typeof(McpServerToolAttribute), false).Any())
                .Select(x => x.GetCustomAttributes(typeof(McpServerToolAttribute), false).OfType<McpServerToolAttribute>().SingleOrDefault()?.Name ?? x.Name)
                // Read-only getters (Get*) are safe even if they name force/watch tables.
                .Where(x => !x.StartsWith("Get", StringComparison.OrdinalIgnoreCase))
                .Where(x => new[]
                {
                    "Force",
                    "WritePlcValue",
                    "SetPlcValue",
                    "CreateWatchTable",
                    "ImportWatchTable",
                    "DeleteWatchTable"
                }.Any(token => x.IndexOf(token, StringComparison.OrdinalIgnoreCase) >= 0))
                .ToList();

            Assert.AreEqual(0, unsafeNames.Count, "禁止暴露在线写入、强制、监控表增删改工具: " + string.Join(", ", unsafeNames));
        }

        [TestMethod]
        public void Test_PlanOnlineReadOnlyMonitoring_ValidatesSymbolicTagsOnly()
        {
            var ok = McpServer.PlanOnlineReadOnlyMonitoring("PLC_1", @"[""DB_HMI.MotorRun"",""DB_HMI.SpeedSet""]");
            Assert.IsTrue(ok.Ok == true, ok.Message);
            Assert.AreEqual(false, ok.Data?["connectsToTia"]?.GetValue<bool>(), "预检工具不得连接 TIA。");
            Assert.AreEqual(false, ok.Data?["goesOnlineOrOffline"]?.GetValue<bool>(), "预检工具不得执行上下线。");
            Assert.AreEqual(false, ok.Data?["writesPlcValues"]?.GetValue<bool>(), "预检工具不得写 PLC 值。");
            Assert.AreEqual(false, ok.Data?["usesForce"]?.GetValue<bool>(), "预检工具不得使用强制。");

            var rejected = McpServer.PlanOnlineReadOnlyMonitoring("PLC_1", @"[""M0.0"",""DB_HMI.ForceMotor"",""DB_HMI.WriteSpeed""]");
            Assert.IsFalse(rejected.Ok == true, "M 点、强制意图、写入意图必须被拒绝。");
            Assert.IsTrue(rejected.Data?["rejectedTags"]?.AsArray().Count >= 3, "必须返回每个被拒绝变量的原因。");
        }

        [TestMethod]
        public void Test_PlanOnlineReadOnlyDataProvider_UsesExternalReadOnlyProvider()
        {
            var ok = McpServer.PlanOnlineReadOnlyDataProvider(
                "opcua",
                "opc.tcp://127.0.0.1:4840",
                @"[""DB_HMI.MotorRun"",""DB_HMI.SpeedSet""]",
                @"{""pollMs"":1000}");

            Assert.IsTrue(ok.Ok == true, ok.Message);
            Assert.AreEqual("opcua", ok.Data?["provider"]?.GetValue<string>());
            Assert.AreEqual(false, ok.Data?["usesTiaOpennessForCurrentValues"]?.GetValue<bool>());
            Assert.AreEqual(false, ok.Data?["connectsNow"]?.GetValue<bool>());
            Assert.AreEqual(false, ok.Data?["writesPlcValues"]?.GetValue<bool>());
            Assert.AreEqual(false, ok.Data?["modifiesWatchTables"]?.GetValue<bool>());
            Assert.AreEqual(false, ok.Data?["usesForce"]?.GetValue<bool>());

            var rejected = McpServer.PlanOnlineReadOnlyDataProvider(
                "s7-readonly",
                "192.168.0.1",
                @"[""M0.0"",""DB_HMI.ForceMotor""]");
            Assert.IsFalse(rejected.Ok == true);
            Assert.IsTrue(rejected.Data?["rejectedTags"]?.AsArray().Count >= 2);
        }

        [TestMethod]
        public void Test_OnlineMonitoringDocumentation_ListsSafetyContract()
        {
            var docPath = FindRepoFile("docs", "online-monitoring-safety.md");
            Assert.IsTrue(File.Exists(docPath), "在线监视安全文档必须存在。");
            var doc = File.ReadAllText(docPath!);
            foreach (var expected in new[]
            {
                "GetPlcWatchTables",
                "ExportPlcWatchTable",
                "ExportPlcWatchTablesToDirectory",
                "ProbePlcMonitorOnlineCapabilities",
                "PlanOnlineReadOnlyMonitoring",
                "RunOnlineMonitoringSafetySelfTest",
                "Force",
                "WatchTable",
                "read-only",
                "Future Online Current-Value Tool Requirements"
            })
            {
                StringAssert.Contains(doc, expected);
            }
        }

        private static string GetDescription(MethodInfo method)
        {
            return method
                .GetCustomAttributes(typeof(System.ComponentModel.DescriptionAttribute), false)
                .OfType<System.ComponentModel.DescriptionAttribute>()
                .SingleOrDefault()?.Description ?? "";
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
