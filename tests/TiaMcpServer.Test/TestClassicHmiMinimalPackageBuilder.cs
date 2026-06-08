using System;
using System.IO;
using System.Text;
using TiaMcpServer.ModelContextProtocol;

namespace TiaMcpServer.Test
{
    [TestClass]
    [DoNotParallelize]
    public class TestClassicHmiMinimalPackageBuilder
    {
        [TestMethod]
        public void Test_ClassicHmiMinimalPackageFiles_ValidateGoodAndBadPackage()
        {
            var outputDirectory = Path.Combine(
                Path.GetTempPath(),
                "tia_mcp_classic_hmi_package_validation_" + DateTime.Now.ToString("yyyyMMdd_HHmmss_fff"));
            Directory.CreateDirectory(outputDirectory);

            var packageJson = @"{
  ""Name"": ""Classic_Motor_ValidateProbe"",
  ""TagTable"": {
    ""Name"": ""Motor_HMI_Tags"",
    ""Tags"": [
      {""Name"":""Motor_Start"",""DataType"":""Bool"",""Length"":""1"",""Connection"":""HMI_Connection_1"",""PlcTag"":""DB1_MotorData.Motor.Start""},
      {""Name"":""Motor_Run"",""DataType"":""Bool"",""Length"":""1"",""Connection"":""HMI_Connection_1"",""PlcTag"":""DB1_MotorData.Motor.Run""},
      {""Name"":""Speed_Set"",""DataType"":""Int"",""Length"":""2"",""Connection"":""HMI_Connection_1"",""PlcTag"":""DB1_MotorData.SpeedSet""}
    ]
  },
  ""ScreenDesign"": {
    ""Screen"": {""Name"":""Motor_Main"",""Width"":640,""Height"":480},
    ""Items"": [
      {""Type"":""Text"",""Name"":""Title"",""Left"":20,""Top"":20,""Width"":260,""Height"":36,""Text"":{""zh-CN"":""电机控制""}},
      {""Type"":""Button"",""Name"":""Btn_Start"",""Left"":20,""Top"":82,""Width"":130,""Height"":46,""Text"":{""zh-CN"":""启动""},""Actions"":[
        {""Event"":""Press"",""ActionKind"":""SetBit"",""TargetTag"":""Motor_Start""},
        {""Event"":""Release"",""ActionKind"":""ResetBit"",""TargetTag"":""Motor_Start""}
      ]},
      {""Type"":""Lamp"",""Name"":""Lamp_Run"",""Left"":180,""Top"":86,""Width"":42,""Height"":42,""Tag"":""Motor_Run""},
      {""Type"":""IOField"",""Name"":""IO_Speed"",""Left"":20,""Top"":154,""Width"":140,""Height"":38,""ProcessValueTag"":""Speed_Set""}
    ]
  }
}";

            var written = ClassicHmiMinimalPackageBuilder.WriteFiles(packageJson, outputDirectory);
            Assert.IsTrue(written["ok"]?.GetValue<bool>() == true, "最小文件包应成功生成。");
            Assert.AreEqual(3, written["fileCount"]?.GetValue<int>(), "应写出变量表、画面和 manifest 三个文件。");

            var valid = ClassicHmiMinimalPackageBuilder.ValidateFiles(outputDirectory);
            Assert.IsTrue(valid["ok"]?.GetValue<bool>() == true, "完整包离线校验应通过。");
            Assert.AreEqual(3, valid["declaredTagCount"]?.GetValue<int>(), "变量表应声明 3 个 HMI tag。");
            Assert.AreEqual(3, valid["referencedTagCount"]?.GetValue<int>(), "画面绑定和事件应引用 3 个 HMI tag。");
            Assert.AreEqual(0, valid["missingTagCount"]?.GetValue<int>(), "完整包不应存在缺失 tag。");
            Assert.AreEqual(2, valid["screenAnalysis"]?["dynamicBindingCount"]?.GetValue<int>(), "灯和 IOField 应生成动态绑定。");
            Assert.AreEqual(2, valid["screenAnalysis"]?["eventActionCount"]?.GetValue<int>(), "按钮 Press/Release 应生成两个事件。");

            var plcSymbolsJson = @"[
  ""DB1_MotorData.Motor.Start"",
  ""DB1_MotorData.Motor.Run"",
  ""DB1_MotorData.SpeedSet""
]";
            var sync = ClassicHmiMinimalPackageBuilder.ValidateFilesWithPlcSymbols(outputDirectory, plcSymbolsJson);
            Assert.IsTrue(sync["ok"]?.GetValue<bool>() == true, "HMI 变量表绑定的 PLC 符号都存在时，同步校验应通过。");
            Assert.AreEqual(3, sync["controllerTagCount"]?.GetValue<int>(), "应检测到 3 个 ControllerTag。");
            Assert.AreEqual(0, sync["missingPlcSymbolCount"]?.GetValue<int>(), "完整 PLC 符号清单不应缺失。");

            var badPlcSymbolsJson = @"[
  ""DB1_MotorData.Motor.Start"",
  ""DB1_MotorData.Motor.Run""
]";
            var badSync = ClassicHmiMinimalPackageBuilder.ValidateFilesWithPlcSymbols(outputDirectory, badPlcSymbolsJson);
            Assert.IsFalse(badSync["ok"]?.GetValue<bool>() == true, "PLC 符号清单缺少绑定目标时必须失败。");
            Assert.AreEqual(1, badSync["missingPlcSymbolCount"]?.GetValue<int>(), "应检测到 1 个缺失 PLC 符号。");
            StringAssert.Contains(badSync["missingPlcSymbols"]?.ToJsonString() ?? "", "DB1_MotorData.SpeedSet");

            // 负例：删除 Speed_Set 声明，校验器必须阻止继续导入真实工程。
            var badDirectory = Path.Combine(outputDirectory, "bad_missing_tag");
            Directory.CreateDirectory(badDirectory);
            var screenPath = Path.Combine(outputDirectory, "Classic_Motor_ValidateProbe_Screen.xml");
            var tagPath = Path.Combine(outputDirectory, "Classic_Motor_ValidateProbe_TagTable.xml");
            File.Copy(screenPath, Path.Combine(badDirectory, "Bad_Screen.xml"), true);
            var tagXml = File.ReadAllText(tagPath, Encoding.UTF8);
            tagXml = tagXml.Replace("<Name>Speed_Set</Name>", "<Name>Speed_Set_Deleted</Name>");
            File.WriteAllText(Path.Combine(badDirectory, "Bad_TagTable.xml"), tagXml, Encoding.UTF8);
            File.WriteAllText(
                Path.Combine(badDirectory, "Bad_manifest.json"),
                @"{""format"":""test"",""tagTableXmlPath"":""Bad_TagTable.xml"",""screenXmlPath"":""Bad_Screen.xml""}",
                Encoding.UTF8);

            var bad = ClassicHmiMinimalPackageBuilder.ValidateFiles(badDirectory);
            Assert.IsFalse(bad["ok"]?.GetValue<bool>() == true, "缺少被画面引用的 HMI tag 时必须失败。");
            Assert.AreEqual(1, bad["missingTagCount"]?.GetValue<int>(), "应检测到 1 个缺失 tag。");
            StringAssert.Contains(bad["missingTags"]?.ToJsonString() ?? "", "Speed_Set");
        }

        [TestMethod]
        public void Test_PlcSymbolManifestBuilder_ExtractsTagTableAndGlobalDbSymbols()
        {
            var outputDirectory = Path.Combine(
                Path.GetTempPath(),
                "tia_mcp_plc_symbol_manifest_" + DateTime.Now.ToString("yyyyMMdd_HHmmss_fff"));
            Directory.CreateDirectory(outputDirectory);

            File.WriteAllText(Path.Combine(outputDirectory, "Tags.xml"), @"<?xml version=""1.0"" encoding=""utf-8""?>
<Document>
  <SW.Tags.PlcTagTable ID=""0"">
    <AttributeList><Name>Tags</Name></AttributeList>
    <ObjectList>
      <SW.Tags.PlcTag ID=""1"" CompositionName=""Tags""><AttributeList><DataTypeName>Bool</DataTypeName><LogicalAddress>%M0.0</LogicalAddress><Name>Motor_Start</Name></AttributeList></SW.Tags.PlcTag>
    </ObjectList>
  </SW.Tags.PlcTagTable>
</Document>", Encoding.UTF8);
            File.WriteAllText(Path.Combine(outputDirectory, "DB1_MotorData.xml"), @"<?xml version=""1.0"" encoding=""utf-8""?>
<Document>
  <SW.Blocks.GlobalDB ID=""0"">
    <AttributeList>
      <Interface>
        <Sections xmlns=""http://www.siemens.com/automation/Openness/SW/Interface/v5"">
          <Section Name=""Static"">
            <Member Name=""Motor"" Datatype=""&quot;UDT_Motor&quot;"">
              <Member Name=""Start"" Datatype=""Bool"" />
            </Member>
            <Member Name=""SpeedSet"" Datatype=""Int"" />
          </Section>
        </Sections>
      </Interface>
      <Name>DB1_MotorData</Name>
    </AttributeList>
  </SW.Blocks.GlobalDB>
</Document>", Encoding.UTF8);

            var manifest = PlcSymbolManifestBuilder.BuildFromXmlPath(outputDirectory);
            Assert.IsTrue(manifest["ok"]?.GetValue<bool>() == true, "PLC 符号清单应成功提取。");
            var symbols = manifest["symbolNames"]?.ToJsonString() ?? "";
            StringAssert.Contains(symbols, "Motor_Start");
            StringAssert.Contains(symbols, "DB1_MotorData.Motor");
            StringAssert.Contains(symbols, "DB1_MotorData.Motor.Start");
            StringAssert.Contains(symbols, "DB1_MotorData.SpeedSet");
        }

        [TestMethod]
        public void Test_ClassicHmiOfflineValidationSuite_RunsPositiveAndNegativeGates()
        {
            var outputDirectory = Path.Combine(
                Path.GetTempPath(),
                "tia_mcp_classic_hmi_offline_suite_" + DateTime.Now.ToString("yyyyMMdd_HHmmss_fff"));
            var suite = ClassicHmiOfflineValidationSuite.Run(outputDirectory);
            Assert.IsTrue(suite["ok"]?.GetValue<bool>() == true, "Classic HMI 离线总验收套件应通过。");
            var items = suite["items"] as System.Text.Json.Nodes.JsonArray;
            Assert.IsNotNull(items, "套件应返回验收项。");
            Assert.IsTrue(items!.Count >= 6, "套件应覆盖 PLC 符号、HMI 包、同步正负例。");
            StringAssert.Contains(suite["syncBad"]?["missingPlcSymbols"]?.ToJsonString() ?? "", "DB1_MotorData.SpeedSet");
            StringAssert.Contains(suite["packageBad"]?["missingTags"]?.ToJsonString() ?? "", "Speed_Set");
        }

        [TestMethod]
        public void Test_HmiTemplatePlcSyncPrecheckSuite_BlocksMissingPlcSymbols()
        {
            var outputDirectory = Path.Combine(
                Path.GetTempPath(),
                "tia_mcp_hmi_template_plc_sync_" + DateTime.Now.ToString("yyyyMMdd_HHmmss_fff"));
            var templateDirectory = Path.Combine(outputDirectory, "templates");
            var plcDirectory = Path.Combine(outputDirectory, "plc");
            var reportDirectory = Path.Combine(outputDirectory, "reports");
            Directory.CreateDirectory(templateDirectory);
            Directory.CreateDirectory(plcDirectory);

            File.WriteAllText(Path.Combine(templateDirectory, "sync_template.json"), @"{
  ""Format"": ""tia-unified-screen-v1"",
  ""TemplateName"": ""sync-template"",
  ""RequiredTags"": [
    { ""Name"": ""Motor_Run"", ""DataType"": ""Bool"", ""PlcTag"": ""DB1_MotorData.Motor.Run"" },
    { ""Name"": ""Speed_Set"", ""DataType"": ""Int"", ""PlcTag"": ""DB1_MotorData.SpeedSet"" }
  ],
  ""Items"": []
}", Encoding.UTF8);
            File.WriteAllText(Path.Combine(plcDirectory, "DB1_MotorData.xml"), @"<?xml version=""1.0"" encoding=""utf-8""?>
<Document>
  <SW.Blocks.GlobalDB ID=""0"">
    <AttributeList>
      <Interface>
        <Sections xmlns=""http://www.siemens.com/automation/Openness/SW/Interface/v5"">
          <Section Name=""Static"">
            <Member Name=""Motor"" Datatype=""&quot;UDT_Motor&quot;"">
              <Member Name=""Run"" Datatype=""Bool"" />
            </Member>
            <Member Name=""SpeedSet"" Datatype=""Int"" />
          </Section>
        </Sections>
      </Interface>
      <Name>DB1_MotorData</Name>
    </AttributeList>
  </SW.Blocks.GlobalDB>
</Document>", Encoding.UTF8);

            var good = HmiTemplatePlcSyncPrecheckSuite.Run(templateDirectory, plcDirectory, reportDirectory);
            Assert.IsTrue(good["ok"]?.GetValue<bool>() == true, "完整 PLC 符号存在时，套件应通过并输出报告。");
            Assert.AreEqual(1, good["readyTemplateCount"]?.GetValue<int>(), "模板应被判定为可进入临时工程验证。");

            var badPlcDirectory = Path.Combine(outputDirectory, "plc_bad");
            Directory.CreateDirectory(badPlcDirectory);
            File.WriteAllText(Path.Combine(badPlcDirectory, "DB1_MotorData.xml"), @"<?xml version=""1.0"" encoding=""utf-8""?>
<Document>
  <SW.Blocks.GlobalDB ID=""0"">
    <AttributeList>
      <Interface>
        <Sections xmlns=""http://www.siemens.com/automation/Openness/SW/Interface/v5"">
          <Section Name=""Static"">
            <Member Name=""Motor"" Datatype=""&quot;UDT_Motor&quot;"">
              <Member Name=""Run"" Datatype=""Bool"" />
            </Member>
          </Section>
        </Sections>
      </Interface>
      <Name>DB1_MotorData</Name>
    </AttributeList>
  </SW.Blocks.GlobalDB>
</Document>", Encoding.UTF8);
            var bad = HmiTemplatePlcSyncPrecheckSuite.Run(templateDirectory, badPlcDirectory, Path.Combine(outputDirectory, "reports_bad"));
            Assert.AreEqual(1, bad["blockedTemplateCount"]?.GetValue<int>(), "缺失 PLC 完整符号时必须阻断模板绑定。");
            StringAssert.Contains(bad["templates"]?.ToJsonString() ?? "", "DB1_MotorData.SpeedSet");
        }

        [TestMethod]
        public void Test_HmiActionScriptRecipeBuilder_SafetySelfTestBlocksRiskyActions()
        {
            var selfTest = HmiActionScriptRecipeBuilder.RunSafetySelfTest();
            Assert.IsTrue(selfTest["ok"]?.GetValue<bool>() == true, "HMI 事件配方安全自测应通过。");
            Assert.AreEqual(8, selfTest["caseCount"]?.GetValue<int>(), "应覆盖安全位操作、缺失目标、写值、确认写入、导航和弹窗。");
            var casesJson = selfTest["cases"]?.ToJsonString() ?? "";
            StringAssert.Contains(casesJson, "confirm-write-blocked");
            StringAssert.Contains(casesJson, "goto-screen-api-discovery-blocked");
            StringAssert.Contains(casesJson, "open-popup-api-discovery-blocked");

            var safe = HmiActionScriptRecipeBuilder.Build("set-bit", "Tapped", new[] { "Cmd_Start" });
            Assert.IsTrue(safe["ok"]?.GetValue<bool>() == true, "set-bit 单目标应生成确定脚本。");
            Assert.IsFalse(safe["applyBlocked"]?.GetValue<bool>() == true, "安全位操作不应被离线配方层阻断。");
            StringAssert.Contains(safe["script"]?.ToString() ?? "", "SetBitInTag");

            var risky = HmiActionScriptRecipeBuilder.Build("set-value", "Tapped", new[] { "Set_Speed" });
            Assert.IsTrue(risky["ok"]?.GetValue<bool>() == true, "set-value 应能生成阻断占位配方。");
            Assert.IsTrue(risky["applyBlocked"]?.GetValue<bool>() == true, "set-value 在没有范围/确认/读回验证前必须阻断。");
            StringAssert.Contains(risky["applyBlockedReason"]?.ToString() ?? "", "SetValue");
        }

        [TestMethod]
        public void Test_ReleaseDiagnosticReportBuilder_SummarizesFailuresAndSignals()
        {
            var suite = new System.Text.Json.Nodes.JsonObject
            {
                ["timestamp"] = DateTime.Now.ToString("O"),
                ["offlineOnly"] = true,
                ["ok"] = false,
                ["suiteDirectory"] = Path.Combine(Path.GetTempPath(), "tia_mcp_diag_suite"),
                ["items"] = new System.Text.Json.Nodes.JsonArray
                {
                    new System.Text.Json.Nodes.JsonObject
                    {
                        ["id"] = "ok-item",
                        ["title"] = "OK Item",
                        ["ok"] = true,
                        ["summary"] = "items=1",
                        ["markdownPath"] = "ok.md",
                        ["jsonPath"] = "ok.json"
                    },
                    new System.Text.Json.Nodes.JsonObject
                    {
                        ["id"] = "bad-item",
                        ["title"] = "Bad Item",
                        ["ok"] = false,
                        ["summary"] = "missing=1",
                        ["markdownPath"] = "bad.md",
                        ["jsonPath"] = "bad.json"
                    }
                },
                ["hmiAction"] = new System.Text.Json.Nodes.JsonObject
                {
                    ["applyBlockedCount"] = 2,
                    ["apiDiscoveryRequiredCount"] = 1,
                    ["safeDeterministicApplyCandidateCount"] = 3
                },
                ["hmiTemplatePlcSyncPrecheck"] = new System.Text.Json.Nodes.JsonObject
                {
                    ["readyTemplateCount"] = 1,
                    ["blockedTemplateCount"] = 1
                },
                ["onlineSafety"] = new System.Text.Json.Nodes.JsonObject
                {
                    ["ok"] = true,
                    ["checkedTools"] = 140
                },
                ["someNested"] = new System.Text.Json.Nodes.JsonObject
                {
                    ["errors"] = new System.Text.Json.Nodes.JsonArray("sample-error"),
                    ["missingTags"] = new System.Text.Json.Nodes.JsonArray("Tag_A")
                }
            };

            var diagnostics = ReleaseDiagnosticReportBuilder.Build(suite);
            Assert.IsTrue(diagnostics["ok"]?.GetValue<bool>() == true, "诊断报告构建本身应成功。");
            Assert.AreEqual(2, diagnostics["summary"]?["itemCount"]?.GetValue<int>(), "应索引两个子项。");
            Assert.AreEqual(1, diagnostics["summary"]?["failedItemCount"]?.GetValue<int>(), "应识别失败项。");
            StringAssert.Contains(diagnostics["failedItems"]?.ToJsonString() ?? "", "bad-item");
            StringAssert.Contains(diagnostics["observations"]?.ToJsonString() ?? "", "hmi-plc-sync");
            StringAssert.Contains(diagnostics["collectedSignals"]?.ToJsonString() ?? "", "sample-error");
            StringAssert.Contains(ReleaseDiagnosticReportBuilder.BuildMarkdown(diagnostics, "diag.json"), "Safety Redlines");
        }

        [TestMethod]
        public void Test_ReleaseRunbookBuilder_ContainsQuickStartAndSafetyRedlines()
        {
            var suite = new System.Text.Json.Nodes.JsonObject
            {
                ["workspaceRoot"] = @"C:\Workspace",
                ["ok"] = true,
                ["markdownPath"] = @"C:\Workspace\reports\offline_release_suite.md",
                ["diagnosticMarkdownPath"] = @"C:\Workspace\reports\offline_release_diagnostics.md"
            };
            var diagnostics = new System.Text.Json.Nodes.JsonObject
            {
                ["markdownPath"] = @"C:\Workspace\reports\offline_release_diagnostics.md",
                ["safetyRedlines"] = new System.Text.Json.Nodes.JsonArray
                {
                    "在线监视只能读当前状态。",
                    "HMI 绑定必须来自真实 PLC tag 或 DB 成员。"
                },
                ["recommendedNextActions"] = new System.Text.Json.Nodes.JsonArray
                {
                    "执行临时 TIA 工程导入、读回、SyntaxCheck/编译诊断验证。"
                },
                ["observations"] = new System.Text.Json.Nodes.JsonObject
                {
                    ["items"] = new System.Text.Json.Nodes.JsonArray
                    {
                        new System.Text.Json.Nodes.JsonObject
                        {
                            ["id"] = "hmi-plc-sync",
                            ["status"] = "blocked",
                            ["detail"] = "blockedTemplateCount=1",
                            ["blocking"] = true
                        }
                    }
                }
            };

            var runbook = ReleaseRunbookBuilder.Build(suite, diagnostics);
            Assert.IsTrue(runbook["ok"]?.GetValue<bool>() == true, "运行手册构建应成功。");
            StringAssert.Contains(runbook["quickStartCommands"]?.ToJsonString() ?? "", "--run-offline-release-suite");
            var redlines = runbook["safetyRedlines"] as System.Text.Json.Nodes.JsonArray;
            Assert.IsNotNull(redlines, "运行手册应包含安全红线。");
            var hasRealPlcRedline = false;
            foreach (var redline in redlines!)
            {
                if ((redline?.ToString() ?? "").Contains("真实 PLC"))
                {
                    hasRealPlcRedline = true;
                    break;
                }
            }
            Assert.IsTrue(hasRealPlcRedline, "安全红线应保留 HMI 绑定必须来自真实 PLC 符号的要求。");
            StringAssert.Contains(runbook["currentKnownBlocks"]?.ToJsonString() ?? "", "hmi-plc-sync");
            var markdown = ReleaseRunbookBuilder.BuildMarkdown(runbook, "runbook.json");
            StringAssert.Contains(markdown, "Start Here");
            StringAssert.Contains(markdown, "Quick Commands");
            StringAssert.Contains(markdown, "Safety Redlines");
        }

        [TestMethod]
        public void Test_ReleaseManifestBuilder_MarksKnownBlocksNotCommercialReady()
        {
            var suite = new System.Text.Json.Nodes.JsonObject
            {
                ["workspaceRoot"] = @"C:\Workspace",
                ["ok"] = true,
                ["markdownPath"] = @"C:\Workspace\reports\main.md",
                ["jsonPath"] = @"C:\Workspace\reports\main.json"
            };
            var diagnostics = new System.Text.Json.Nodes.JsonObject
            {
                ["failedItems"] = new System.Text.Json.Nodes.JsonArray(),
                ["safetyRedlines"] = new System.Text.Json.Nodes.JsonArray("在线监视只读。"),
                ["reportIndex"] = new System.Text.Json.Nodes.JsonArray
                {
                    new System.Text.Json.Nodes.JsonObject
                    {
                        ["id"] = "online-monitoring-safety",
                        ["title"] = "在线安全",
                        ["ok"] = true,
                        ["summary"] = "items=6",
                        ["markdownPath"] = "safety.md"
                    }
                },
                ["markdownPath"] = @"C:\Workspace\reports\diag.md",
                ["jsonPath"] = @"C:\Workspace\reports\diag.json"
            };
            var runbook = new System.Text.Json.Nodes.JsonObject
            {
                ["markdownPath"] = @"C:\Workspace\reports\runbook.md",
                ["jsonPath"] = @"C:\Workspace\reports\runbook.json",
                ["quickStartCommands"] = new System.Text.Json.Nodes.JsonArray("dotnet build"),
                ["currentKnownBlocks"] = new System.Text.Json.Nodes.JsonArray
                {
                    new System.Text.Json.Nodes.JsonObject
                    {
                        ["id"] = "hmi-plc-sync",
                        ["status"] = "blocked",
                        ["detail"] = "blockedTemplateCount=1"
                    }
                }
            };

            var manifest = ReleaseManifestBuilder.Build(suite, diagnostics, runbook);
            Assert.IsTrue(manifest["ok"]?.GetValue<bool>() == true, "发布清单构建应成功。");
            Assert.IsFalse(manifest["commercialReady"]?.GetValue<bool>() == true, "存在已知阻断时不能标记为最终商用就绪。");
            StringAssert.Contains(manifest["knownBlocks"]?.ToJsonString() ?? "", "hmi-plc-sync");
            StringAssert.Contains(manifest["verifiedCapabilities"]?.ToJsonString() ?? "", "online-monitoring-safety");
            StringAssert.Contains(ReleaseManifestBuilder.BuildMarkdown(manifest, "manifest.json"), "Commercial ready");
        }

        [TestMethod]
        public void Test_CommercialReadinessGateBuilder_BlocksMissingHmiSyncAndApiProof()
        {
            var suite = new System.Text.Json.Nodes.JsonObject
            {
                ["workspaceRoot"] = @"C:\Workspace",
                ["ok"] = true,
                ["temporaryProof"] = "temporary TIA project import preflight"
            };
            var diagnostics = new System.Text.Json.Nodes.JsonObject
            {
                ["suiteOk"] = true,
                ["failedItems"] = new System.Text.Json.Nodes.JsonArray(),
                ["safetyRedlines"] = new System.Text.Json.Nodes.JsonArray
                {
                    "在线监视只能读当前状态，禁止通过监控表在线修改对象。",
                    "不暴露、不生成、不执行强制表/Force 相关能力。",
                    "HMI 绑定必须来自真实 PLC tag 或 DB 成员，禁止凭空绑定 M 点。",
                    "交付包未获得明确许可前不自动修改。"
                },
                ["reportIndex"] = new System.Text.Json.Nodes.JsonArray
                {
                    new System.Text.Json.Nodes.JsonObject
                    {
                        ["id"] = "classic-hmi-temporary-import-preflight",
                        ["ok"] = true
                    }
                },
                ["observations"] = new System.Text.Json.Nodes.JsonObject
                {
                    ["items"] = new System.Text.Json.Nodes.JsonArray
                    {
                        new System.Text.Json.Nodes.JsonObject
                        {
                            ["id"] = "online-safety",
                            ["status"] = "pass",
                            ["blocking"] = false
                        },
                        new System.Text.Json.Nodes.JsonObject
                        {
                            ["id"] = "hmi-plc-sync",
                            ["status"] = "blocked",
                            ["detail"] = "blockedTemplateCount=4",
                            ["blocking"] = true
                        },
                        new System.Text.Json.Nodes.JsonObject
                        {
                            ["id"] = "hmi-action-api-discovery",
                            ["status"] = "needs-api-discovery",
                            ["detail"] = "apiDiscoveryRequiredCount=3",
                            ["blocking"] = true
                        }
                    }
                }
            };
            var runbook = new System.Text.Json.Nodes.JsonObject
            {
                ["currentKnownBlocks"] = new System.Text.Json.Nodes.JsonArray()
            };
            var manifest = new System.Text.Json.Nodes.JsonObject
            {
                ["commercialReady"] = false
            };

            var gate = CommercialReadinessGateBuilder.Build(suite, diagnostics, runbook, manifest);
            Assert.IsTrue(gate["ok"]?.GetValue<bool>() == true, "商用就绪门禁报告应构建成功。");
            Assert.IsFalse(gate["commercialReady"]?.GetValue<bool>() == true, "存在 HMI 同步和事件 API 阻断时不能标记商用就绪。");
            StringAssert.Contains(gate["gaps"]?.ToJsonString() ?? "", "hmi-plc-real-symbol-sync");
            StringAssert.Contains(gate["gaps"]?.ToJsonString() ?? "", "hmi-action-api-readback");
            StringAssert.Contains(CommercialReadinessGateBuilder.BuildMarkdown(gate, "gate.json"), "Commercial Readiness Gate");
        }

        [TestMethod]
        public void Test_ReleaseHandoffArtifactBuilder_RebuildsFilesFromSuiteJson()
        {
            var outputDirectory = Path.Combine(
                Path.GetTempPath(),
                "tia_mcp_release_handoff_" + DateTime.Now.ToString("yyyyMMdd_HHmmss_fff"));
            Directory.CreateDirectory(outputDirectory);
            var suiteJsonPath = Path.Combine(outputDirectory, "offline_release_validation_suite_fixture.json");
            File.WriteAllText(suiteJsonPath, @"{
  ""workspaceRoot"": ""C:\\Workspace"",
  ""offlineOnly"": true,
  ""ok"": true,
  ""suiteDirectory"": ""C:\\Workspace\\reports\\suite"",
  ""markdownPath"": ""C:\\Workspace\\reports\\main.md"",
  ""jsonPath"": ""C:\\Workspace\\reports\\main.json"",
  ""items"": [
    { ""id"": ""online-monitoring-safety"", ""title"": ""在线安全"", ""ok"": true, ""summary"": ""items=6"", ""markdownPath"": ""safety.md"", ""jsonPath"": ""safety.json"" }
  ],
  ""hmiAction"": { ""applyBlockedCount"": 1, ""apiDiscoveryRequiredCount"": 1, ""safeDeterministicApplyCandidateCount"": 2 },
  ""hmiTemplatePlcSyncPrecheck"": { ""readyTemplateCount"": 0, ""blockedTemplateCount"": 1 },
  ""onlineSafety"": { ""ok"": true, ""checkedTools"": 135 }
}", Encoding.UTF8);

            var result = ReleaseHandoffArtifactBuilder.RebuildFromSuiteJson(suiteJsonPath, outputDirectory);
            Assert.IsTrue(result["ok"]?.GetValue<bool>() == true, "交接材料重建应成功。");
            Assert.IsTrue(File.Exists(result["diagnosticMarkdownPath"]?.ToString() ?? ""), "应生成诊断报告。");
            Assert.IsTrue(File.Exists(result["runbookMarkdownPath"]?.ToString() ?? ""), "应生成运行手册。");
            Assert.IsTrue(File.Exists(result["manifestMarkdownPath"]?.ToString() ?? ""), "应生成发布清单。");
            Assert.IsFalse(result["commercialReady"]?.GetValue<bool>() == true, "fixture 中保留阻断项时不应标记商用就绪。");
        }
    }
}
