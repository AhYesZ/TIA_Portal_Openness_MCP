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
    public class TestHardwareNetworkPrimitives
    {
        [TestMethod]
        public void Test_HardwareNetworkPlanValidator_AcceptsResolvedPlan()
        {
            var report = McpServer.PlanHardwareNetworkConfiguration(@"{
  ""operations"": [
    {
      ""type"": ""EnsureSubnet"",
      ""anchorDeviceItemPath"": ""PLC_1/PLC_1.CPU_1"",
      ""subnetType"": ""PROFINET"",
      ""subnetName"": ""PN_IE_1"",
      ""ip"": ""192.168.0.1"",
      ""mask"": ""255.255.255.0""
    },
    {
      ""type"": ""AttachDeviceNodeToSubnet"",
      ""deviceItemPath"": ""HMI_1/HMI_1.IE_CP_1"",
      ""interfaceIndex"": 0,
      ""subnetName"": ""PN_IE_1""
    },
    {
      ""type"": ""SetCpuCommonSettings"",
      ""cpuPath"": ""PLC_1/PLC_1.CPU_1"",
      ""settings"": {
        ""exactAttributes"": {
          ""Name"": ""PLC_1""
        }
      }
    }
  ]
}");

            Assert.IsTrue(report.Ok == true, report.Message);
            Assert.AreEqual(false, report.Data?["connectsToTia"]?.GetValue<bool>());
            Assert.AreEqual(false, report.Data?["modifiesProject"]?.GetValue<bool>());
            Assert.AreEqual(true, report.Data?["requiresReadbackAfterApply"]?.GetValue<bool>());
        }

        [TestMethod]
        public void Test_HardwareNetworkPlanValidator_RejectsGuessesAndAliases()
        {
            var report = McpServer.PlanHardwareNetworkConfiguration(@"{
  ""operations"": [
    {
      ""type"": ""EnsureSubnet"",
      ""anchorDeviceItemPath"": ""PLC"",
      ""subnetType"": ""MPI"",
      ""subnetName"": ""PN_IE_1"",
      ""ip"": ""999.1.1.1"",
      ""mask"": ""255.0.255.0""
    },
    {
      ""type"": ""SetCpuCommonSettings"",
      ""cpuPath"": ""CPU"",
      ""settings"": {
        ""ip"": ""192.168.0.1"",
        ""exactAttributes"": {
          ""ip"": ""192.168.0.1""
        }
      }
    }
  ]
}");

            Assert.IsFalse(report.Ok == true, "猜测路径、非法网络参数、别名属性必须被拒绝。");
            var errors = report.Data?["errors"]?.AsArray().Select(x => x?.ToString() ?? "").ToList() ?? [];
            Assert.IsTrue(errors.Any(x => x.Contains("looks guessed", StringComparison.OrdinalIgnoreCase)));
            Assert.IsTrue(errors.Any(x => x.Contains("subnetType", StringComparison.OrdinalIgnoreCase)));
            Assert.IsTrue(errors.Any(x => x.Contains("valid IPv4", StringComparison.OrdinalIgnoreCase)));
            Assert.IsTrue(errors.Any(x => x.Contains("exactAttributes.ip", StringComparison.OrdinalIgnoreCase)));
        }

        [TestMethod]
        public void Test_HardwareNetworkToolDescriptions_ExposeReadbackContract()
        {
            foreach (var toolName in new[]
            {
                "PlanHardwareNetworkConfiguration",
                "EnsureSubnet",
                "AttachDeviceNodeToSubnet",
                "SetCpuCommonSettings"
            })
            {
                var method = typeof(McpServer).GetMethod(toolName, BindingFlags.Public | BindingFlags.Static);
                Assert.IsNotNull(method, toolName + " 必须公开。");
                var tool = method!.GetCustomAttributes(typeof(McpServerToolAttribute), false).OfType<McpServerToolAttribute>().SingleOrDefault();
                Assert.IsNotNull(tool, toolName + " 必须是 MCP 工具。");
                var description = method.GetCustomAttributes(typeof(System.ComponentModel.DescriptionAttribute), false)
                    .OfType<System.ComponentModel.DescriptionAttribute>()
                    .SingleOrDefault()?.Description ?? "";
                StringAssert.Contains(description, "[Hardware]");
                if (!toolName.StartsWith("Plan", StringComparison.OrdinalIgnoreCase))
                    StringAssert.Contains(description, "readback");
            }
        }

        [TestMethod]
        public void Test_HardwareNetworkDocumentation_ListsPublicContracts()
        {
            var docPath = FindRepoFile("docs", "tools", "hardware-network.md");
            Assert.IsTrue(File.Exists(docPath), "硬件网络工具文档必须存在。");
            var doc = File.ReadAllText(docPath!);
            foreach (var expected in new[]
            {
                "PlanHardwareNetworkConfiguration",
                "EnsureSubnet",
                "AttachDeviceNodeToSubnet",
                "SetCpuCommonSettings",
                "GetProjectTree",
                "GetDeviceItemTree",
                "GetDeviceItemNetworkInfo",
                "readback",
                "exactAttributes"
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
