using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.Json.Nodes;
using System.Xml.Linq;
using ModelContextProtocol;
using ModelContextProtocol.Server;
using TiaMcpServer.ModelContextProtocol;

namespace TiaMcpServer.Test
{
    [TestClass]
    [DoNotParallelize]
    public class TestPlcBuilderMcpTools
    {
        [TestMethod]
        public void Test_PlcBuilderMcpTools_BuildXmlOffline()
        {
            var udt = McpServer.BuildPlcUdtXml(@"{
  ""name"": ""UDT_FaultStatus"",
  ""members"": [
    { ""name"": ""FaultActive"", ""datatype"": ""Bool"", ""externalWritable"": true, ""commentZhCn"": ""故障激活"" },
    { ""name"": ""FaultCode"", ""datatype"": ""Int"", ""commentZhCn"": ""故障代码"" }
  ]
}");
            AssertOkXml(udt, "SW.Types.PlcStruct");

            var tagTable = McpServer.BuildPlcTagTableXml(@"{
  ""tableName"": ""StartStop"",
  ""tags"": [
    { ""name"": ""StartPB"", ""dataTypeName"": ""Bool"", ""logicalAddress"": ""%I0.0"" },
    { ""name"": ""RunOut"", ""dataTypeName"": ""Bool"", ""logicalAddress"": ""%Q0.0"" }
  ]
}");
            AssertOkXml(tagTable, "SW.Tags.PlcTagTable");

            var globalDb = McpServer.BuildPlcGlobalDbXml(@"{
  ""dbName"": ""DB_HMI_Template_Data"",
  ""dbNumber"": 101,
  ""staticMembers"": [
    { ""name"": ""MotorRun"", ""datatype"": ""Bool"", ""externalWritable"": true, ""commentZhCn"": ""电机运行"", ""startValue"": ""false"" },
    { ""name"": ""SpeedSet"", ""datatype"": ""Int"", ""commentZhCn"": ""速度设定"", ""startValue"": ""0"" }
  ]
}");
            AssertOkXml(globalDb, "SW.Blocks.GlobalDB");

            var st = McpServer.BuildStructuredTextXml(@"{
  ""operations"": [
    { ""op"": ""if"", ""condition"": ""Start"" },
    { ""op"": ""assignment"", ""target"": ""Run"", ""value"": ""TRUE"", ""indent"": 2 },
    { ""op"": ""else"" },
    { ""op"": ""assignment"", ""target"": ""Run"", ""value"": ""FALSE"", ""indent"": 2 },
    { ""op"": ""endif"" }
  ]
}");
            AssertOkXml(st, "StructuredText");

            var flgNet = McpServer.BuildFlgNetCallXml(@"{
  ""callName"": ""Limit_Protect"",
  ""parameters"": [
    { ""name"": ""Current_Location"", ""section"": ""Input"", ""dataType"": ""Real"", ""symbol"": ""DB_Axis.Actual.Position"" },
    { ""name"": ""Enable"", ""section"": ""Input"", ""dataType"": ""Bool"", ""sourceKind"": ""constant"", ""value"": ""1"" },
    { ""name"": ""Fault"", ""section"": ""Output"", ""dataType"": ""Bool"", ""symbolPath"": [""DB_Axis"", ""Fault""] }
  ]
}");
            AssertOkXml(flgNet, "FlgNet");

            var fc = McpServer.ComposePlcFcBlockXml(@"{
  ""blockName"": ""FC_StartStop"",
  ""blockNumber"": 1,
  ""inputs"": [
    { ""name"": ""Start"", ""datatype"": ""Bool"" },
    { ""name"": ""Stop"", ""datatype"": ""Bool"" }
  ],
  ""outputs"": [
    { ""name"": ""Run"", ""datatype"": ""Bool"" }
  ],
  ""structuredText"": {
    ""operations"": [
      { ""op"": ""if"", ""condition"": ""Stop"" },
      { ""op"": ""assignment"", ""target"": ""Run"", ""value"": ""FALSE"", ""indent"": 2 },
      { ""op"": ""else"" },
      { ""op"": ""assignment"", ""target"": ""Run"", ""value"": ""TRUE"", ""indent"": 2 },
      { ""op"": ""endif"" }
    ]
  }
}");
            AssertOkXml(fc, "SW.Blocks.FC");

            var fb = McpServer.ComposePlcFbBlockXml(@"{
  ""blockName"": ""FB_Motor"",
  ""blockNumber"": 20,
  ""inputs"": [
    { ""name"": ""Start"", ""datatype"": ""Bool"" },
    { ""name"": ""Stop"", ""datatype"": ""Bool"" }
  ],
  ""outputs"": [
    { ""name"": ""Run"", ""datatype"": ""Bool"" }
  ],
  ""statics"": [
    { ""name"": ""Latch"", ""datatype"": ""Bool"" }
  ],
  ""structuredText"": {
    ""operations"": [
      { ""op"": ""if"", ""condition"": ""Stop"" },
      { ""op"": ""assignment"", ""target"": ""Latch"", ""value"": ""FALSE"", ""indent"": 2 },
      { ""op"": ""else"" },
      { ""op"": ""if"", ""condition"": ""Start"", ""indent"": 2 },
      { ""op"": ""assignment"", ""target"": ""Latch"", ""value"": ""TRUE"", ""indent"": 4 },
      { ""op"": ""endif"", ""indent"": 2 },
      { ""op"": ""endif"" },
      { ""op"": ""assignment"", ""target"": ""Run"", ""value"": ""Latch"" }
    ]
  }
}");
            AssertOkXml(fb, "SW.Blocks.FB");
        }

        [TestMethod]
        public void Test_PlcBuilderMcpTools_BlockInvalidInput()
        {
            try
            {
                McpServer.BuildPlcTagTableXml(@"{ ""tableName"": ""Bad"", ""tags"": [{ ""name"": ""NoAddress"", ""dataTypeName"": ""Bool"" }] }");
                Assert.Fail("缺少 logicalAddress 时必须返回 InvalidParams。");
            }
            catch (McpException ex)
            {
                StringAssert.Contains(ex.Message, "$.tags[0].logicalAddress");
            }
        }

        [TestMethod]
        public void Test_StructuredText_RejectsExpressionSymbols()
        {
            // condition 写表达式：必须在离线生成阶段就抛错，而不是静默生成「变量名含空格」的错误 XML。
            AssertThrowsWithGuidance(() => McpServer.BuildStructuredTextXml(@"{
  ""operations"": [ { ""op"": ""if"", ""condition"": ""RawMax <> RawMin"" }, { ""op"": ""endif"" } ]
}"), "RawMax <> RawMin");

            // assignment.source 写算术表达式。
            AssertThrowsWithGuidance(() => McpServer.BuildStructuredTextXml(@"{
  ""operations"": [ { ""op"": ""assignment"", ""target"": ""ErrorValue"", ""source"": ""Setpoint - Actual"" } ]
}"), "Setpoint - Actual");

            // source 写函数调用。
            AssertThrowsWithGuidance(() => McpServer.BuildStructuredTextXml(@"{
  ""operations"": [ { ""op"": ""assignment"", ""target"": ""AbsError"", ""source"": ""ABS(ErrorValue)"" } ]
}"), "ABS(ErrorValue)");

            // condition 写布尔字面量 TRUE。
            AssertThrowsWithGuidance(() => McpServer.BuildStructuredTextXml(@"{
  ""operations"": [ { ""op"": ""if"", ""condition"": ""TRUE"" }, { ""op"": ""endif"" } ]
}"), "TRUE");
        }

        private static void AssertThrowsWithGuidance(Action action, string offendingText)
        {
            try
            {
                action();
                Assert.Fail("表达式 \"" + offendingText + "\" 必须在离线生成阶段被拦截。");
            }
            catch (McpException ex)
            {
                StringAssert.Contains(ex.Message, offendingText);
            }
            catch (ArgumentException ex)
            {
                StringAssert.Contains(ex.Message, offendingText);
            }
        }

        [TestMethod]
        public void Test_PlcBuildAndImport_DryRunWritesAndClassifiesXml()
        {
            var udt = McpServer.PlcBuildAndImport(
                softwarePath: "",
                kind: "udt",
                json: @"{
  ""name"": ""UDT_ReadyStatus"",
  ""members"": [
    { ""name"": ""Ready"", ""datatype"": ""Bool"", ""externalWritable"": true, ""commentZhCn"": ""就绪"" },
    { ""name"": ""Code"", ""datatype"": ""Int"", ""commentZhCn"": ""代码"" }
  ]
}",
                dryRun: true);

            Assert.IsTrue(udt.Meta?["success"]?.GetValue<bool>() == true, "dryRun 应只生成并分类 XML，不要求连接 TIA。");
            Assert.AreEqual(true, udt.DryRun, "默认干跑应保持只验证不导入。");
            Assert.AreEqual("udt", udt.BuildKind);
            Assert.IsNotNull(udt.WrittenFiles, "响应必须返回生成 XML 文件。");
            var udtPath = udt.WrittenFiles!.Single();
            Assert.IsTrue(File.Exists(udtPath), "dryRun 必须写出临时 XML 供人工/后续导入复查。");
            Assert.IsTrue(udt.DiscoveredTypes?.Any() == true, "UDT 应被分类为 type。");
            Assert.IsFalse(udt.ImportedTypes?.Any() == true, "dryRun 不允许导入类型。");
            AssertOkXmlFile(udtPath, "SW.Types.PlcStruct");

            var fc = McpServer.PlcBuildAndImport(
                softwarePath: "",
                kind: "fc",
                json: @"{
  ""blockName"": ""FC_DryRun"",
  ""blockNumber"": 12,
  ""inputs"": [{ ""name"": ""Start"", ""datatype"": ""Bool"" }],
  ""outputs"": [{ ""name"": ""Run"", ""datatype"": ""Bool"" }],
  ""structuredText"": {
    ""operations"": [
      { ""op"": ""if"", ""condition"": ""Start"" },
      { ""op"": ""assignment"", ""target"": ""Run"", ""value"": ""TRUE"", ""indent"": 2 },
      { ""op"": ""endif"" }
    ]
  }
}",
                dryRun: true);

            Assert.IsTrue(fc.Meta?["success"]?.GetValue<bool>() == true, "FC dryRun 应成功生成并分类。");
            Assert.AreEqual("fc", fc.BuildKind);
            Assert.IsTrue(fc.DiscoveredBlocks?.Contains("FC_DryRun") == true, "FC 应被分类为 block。");
            Assert.IsFalse(fc.ImportedBlocks?.Any() == true, "dryRun 不允许导入块。");
            AssertOkXmlFile(fc.WrittenFiles!.Single(), "SW.Blocks.FC");

            var fb = McpServer.PlcBuildAndImport(
                softwarePath: "",
                kind: "fb",
                json: @"{
  ""blockName"": ""FB_DryRun"",
  ""blockNumber"": 21,
  ""inputs"": [{ ""name"": ""Enable"", ""datatype"": ""Bool"" }],
  ""statics"": [{ ""name"": ""State"", ""datatype"": ""Bool"" }],
  ""structuredText"": {
    ""operations"": [
      { ""op"": ""assignment"", ""target"": ""State"", ""value"": ""Enable"" }
    ]
  }
}",
                dryRun: true);

            Assert.IsTrue(fb.Meta?["success"]?.GetValue<bool>() == true, "FB dryRun 应成功生成并分类。");
            Assert.AreEqual("fb", fb.BuildKind);
            Assert.IsTrue(fb.DiscoveredBlocks?.Contains("FB_DryRun") == true, "FB 应被分类为 block。");
            Assert.IsFalse(fb.ImportedBlocks?.Any() == true, "dryRun 不允许导入 FB。");
            AssertOkXmlFile(fb.WrittenFiles!.Single(), "SW.Blocks.FB");
        }

        [TestMethod]
        public void Test_PlcBuildAndImport_BlocksUnsupportedKind()
        {
            try
            {
                McpServer.PlcBuildAndImport("", "ob", @"{}", dryRun: true);
                Assert.Fail("未实现的 kind 必须被明确拦截，不能悄悄生成错误 XML。");
            }
            catch (McpException ex)
            {
                StringAssert.Contains(ex.Message, "Supported values");
            }
        }

        [TestMethod]
        public void Test_PlcBuilderMcpToolDescriptions_AreTaggedAndSafeByDefault()
        {
            var buildTools = new[]
            {
                "BuildPlcUdtXml",
                "BuildPlcTagTableXml",
                "BuildPlcGlobalDbXml",
                "BuildStructuredTextXml",
                "BuildFlgNetCallXml",
                "ComposePlcFcBlockXml",
                "ComposePlcFbBlockXml"
            };

            foreach (var toolName in buildTools)
            {
                var method = typeof(McpServer).GetMethod(toolName, BindingFlags.Public | BindingFlags.Static);
                Assert.IsNotNull(method, toolName + " 必须作为 MCP 工具公开。");
                var tool = method!.GetCustomAttributes(typeof(McpServerToolAttribute), false).OfType<McpServerToolAttribute>().SingleOrDefault();
                Assert.IsNotNull(tool, toolName + " 必须带 McpServerToolAttribute。");
                var description = method.GetCustomAttributes(typeof(System.ComponentModel.DescriptionAttribute), false)
                    .OfType<System.ComponentModel.DescriptionAttribute>()
                    .SingleOrDefault()?.Description ?? "";
                StringAssert.Contains(description, "[PLC-Builders]");
                StringAssert.Contains(description, "[Offline]");
                StringAssert.Contains(description, "does not connect to TIA Portal");
            }

            var buildAndImport = typeof(McpServer).GetMethod("PlcBuildAndImport", BindingFlags.Public | BindingFlags.Static);
            Assert.IsNotNull(buildAndImport, "PlcBuildAndImport 必须作为 MCP 工具公开。");
            var dryRun = buildAndImport!.GetParameters().Single(x => x.Name == "dryRun");
            Assert.AreEqual(true, dryRun.DefaultValue, "PlcBuildAndImport 的 dryRun 默认值必须保持 true。");
            var buildAndImportDescription = buildAndImport.GetCustomAttributes(typeof(System.ComponentModel.DescriptionAttribute), false)
                .OfType<System.ComponentModel.DescriptionAttribute>()
                .SingleOrDefault()?.Description ?? "";
            StringAssert.Contains(buildAndImportDescription, "[PLC-Software]");
            StringAssert.Contains(buildAndImportDescription, "dryRun=true");
        }

        [TestMethod]
        public void Test_PlcBuilderDocumentation_ListsPublicContracts()
        {
            var dir = new DirectoryInfo(AppDomain.CurrentDomain.BaseDirectory);
            string? docPath = null;
            while (dir != null)
            {
                var candidate = Path.Combine(dir.FullName, "docs", "tools", "plc-builders.md");
                if (File.Exists(candidate))
                {
                    docPath = candidate;
                    break;
                }

                dir = dir.Parent;
            }

            Assert.IsTrue(File.Exists(docPath), "PLC Builder 工具契约文档必须存在。");
            var doc = File.ReadAllText(docPath!);
            foreach (var expected in new[]
            {
                "BuildPlcUdtXml",
                "BuildPlcTagTableXml",
                "BuildPlcGlobalDbXml",
                "BuildStructuredTextXml",
                "BuildFlgNetCallXml",
                "ComposePlcFcBlockXml",
                "ComposePlcFbBlockXml",
                "PlcBuildAndImport",
                "dryRun=true",
                "Real import checklist"
            })
            {
                StringAssert.Contains(doc, expected);
            }
        }

        private static void AssertOkXml(ResponseJsonReport response, string expectedElement)
        {
            Assert.IsTrue(response.Ok == true, response.Message);
            Assert.IsTrue(response.Data?["offlineOnly"]?.GetValue<bool>() == true, "PLC Builder 工具必须保持离线只生成。");
            Assert.IsTrue(response.Data?["xmlParseOk"]?.GetValue<bool>() == true, "生成 XML 必须可解析。");
            var xml = response.Data?["xml"]?.ToString() ?? "";
            Assert.IsFalse(string.IsNullOrWhiteSpace(xml), "响应必须返回 XML 字符串。");

            var doc = TryParseDocument(xml);
            Assert.IsTrue(doc.Descendants().Any(x => x.Name.LocalName == expectedElement) ||
                          string.Equals(doc.Root?.Name.LocalName, expectedElement, StringComparison.OrdinalIgnoreCase),
                "生成 XML 中应包含 " + expectedElement + "。");
        }

        private static XDocument TryParseDocument(string xml)
        {
            try
            {
                return XDocument.Parse(xml);
            }
            catch
            {
                return XDocument.Parse("<Fragment>" + xml + "</Fragment>");
            }
        }

        private static void AssertOkXmlFile(string path, string expectedElement)
        {
            var doc = XDocument.Load(path);
            Assert.IsTrue(doc.Descendants().Any(x => x.Name.LocalName == expectedElement) ||
                          string.Equals(doc.Root?.Name.LocalName, expectedElement, StringComparison.OrdinalIgnoreCase),
                "生成文件中应包含 " + expectedElement + "。");
        }
    }
}
