using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.Json.Nodes;
using TiaMcpServer.ModelContextProtocol;

namespace TiaMcpServer.Test
{
    [TestClass]
    [DoNotParallelize]
    public class TestHmiUnifiedActionRecipes
    {
        [TestMethod]
        public void Test_HmiActionRecipes_AllowOnlyDeterministicBitCommands()
        {
            var setBit = HmiActionScriptRecipeBuilder.Build("set-bit", "Tapped", new[] { "Cmd_Start" });
            AssertRecipe(setBit, ok: true, blocked: false, requiresApi: false, requiresPolicy: false);
            StringAssert.Contains(setBit["script"]?.ToString() ?? "", "SetBitInTag");

            var resetBit = HmiActionScriptRecipeBuilder.Build("reset-bit", "Released", new[] { "Cmd_Start" });
            AssertRecipe(resetBit, ok: true, blocked: false, requiresApi: false, requiresPolicy: false);
            StringAssert.Contains(resetBit["script"]?.ToString() ?? "", "ResetBitInTag");

            var toggleBit = HmiActionScriptRecipeBuilder.Build("toggle-bit", "Tapped", new[] { "Cmd_Auto" });
            AssertRecipe(toggleBit, ok: true, blocked: false, requiresApi: false, requiresPolicy: false);
            StringAssert.Contains(toggleBit["script"]?.ToString() ?? "", "ToggleBitInTag");

            var setValue = HmiActionScriptRecipeBuilder.Build("set-value", "Tapped", new[] { "Speed_Set" });
            AssertRecipe(setValue, ok: true, blocked: true, requiresApi: false, requiresPolicy: true);
            StringAssert.Contains(setValue["applyBlockedReason"]?.ToString() ?? "", "range validation");

            var gotoScreen = HmiActionScriptRecipeBuilder.Build("goto-screen", "Tapped", Array.Empty<string>(), "Alarm_Overview");
            AssertRecipe(gotoScreen, ok: true, blocked: true, requiresApi: true, requiresPolicy: false);

            var popup = HmiActionScriptRecipeBuilder.Build("open-popup", "Tapped", Array.Empty<string>(), "", "Popup_Parameter");
            AssertRecipe(popup, ok: true, blocked: true, requiresApi: true, requiresPolicy: false);
        }

        [TestMethod]
        public void Test_HmiActionRecipeSafetySelfTest_Passes()
        {
            var report = McpServer.RunHmiActionScriptRecipeSafetySelfTest();
            Assert.IsTrue(report.Ok == true, report.Message);
            Assert.IsTrue(report.Data?["ok"]?.GetValue<bool>() == true, "HMI 动作配方安全自测必须通过。");
            Assert.IsTrue(report.Data?["caseCount"]?.GetValue<int>() >= 8, "安全自测必须覆盖安全动作、缺参、写值、导航和弹窗。");
        }

        [TestMethod]
        public void Test_HmiActionRecipeToolDescriptions_ExposeSafetyBoundary()
        {
            var buildMethod = typeof(McpServer).GetMethod("BuildUnifiedHmiButtonActionScript", BindingFlags.Public | BindingFlags.Static);
            Assert.IsNotNull(buildMethod, "BuildUnifiedHmiButtonActionScript 必须公开。");
            var buildDescription = GetDescription(buildMethod!);
            StringAssert.Contains(buildDescription, "without connecting to TIA");

            var applyMethod = typeof(McpServer).GetMethod("EnsureUnifiedHmiButtonAction", BindingFlags.Public | BindingFlags.Static);
            Assert.IsNotNull(applyMethod, "EnsureUnifiedHmiButtonAction 必须公开。");
            var applyDescription = GetDescription(applyMethod!);
            StringAssert.Contains(applyDescription, "Only set-bit/reset-bit/toggle-bit");
            StringAssert.Contains(applyDescription, "high-risk");
        }

        [TestMethod]
        public void Test_HmiUnifiedActionsDocumentation_ListsSafetyContract()
        {
            var docPath = FindRepoFile("docs", "tools", "hmi-unified-actions.md");
            Assert.IsTrue(File.Exists(docPath), "Unified HMI 动作契约文档必须存在。");
            var doc = File.ReadAllText(docPath!);
            foreach (var expected in new[]
            {
                "BuildUnifiedHmiButtonActionScript",
                "EnsureUnifiedHmiButtonAction",
                "SetUnifiedHmiButtonEventScriptCode",
                "set-bit",
                "reset-bit",
                "toggle-bit",
                "set-value",
                "confirm-write",
                "goto-screen",
                "open-popup",
                "Force",
                "WatchTable",
                "Real Apply Checklist"
            })
            {
                StringAssert.Contains(doc, expected);
            }
        }

        private static void AssertRecipe(JsonObject recipe, bool ok, bool blocked, bool requiresApi, bool requiresPolicy)
        {
            Assert.AreEqual(ok, recipe["ok"]?.GetValue<bool>(), "ok mismatch for " + recipe["recipeKind"]);
            Assert.AreEqual(blocked, recipe["applyBlocked"]?.GetValue<bool>(), "applyBlocked mismatch for " + recipe["recipeKind"]);
            Assert.AreEqual(requiresApi, recipe["requiresApiDiscovery"]?.GetValue<bool>(), "requiresApiDiscovery mismatch for " + recipe["recipeKind"]);
            Assert.AreEqual(requiresPolicy, recipe["requiresSafetyPolicy"]?.GetValue<bool>(), "requiresSafetyPolicy mismatch for " + recipe["recipeKind"]);
            var script = recipe["script"]?.ToString() ?? "";
            Assert.IsFalse(script.IndexOf("Force", StringComparison.OrdinalIgnoreCase) >= 0, "脚本禁止包含 Force。");
            Assert.IsFalse(script.IndexOf("WatchTable", StringComparison.OrdinalIgnoreCase) >= 0, "脚本禁止引用 WatchTable。");
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
