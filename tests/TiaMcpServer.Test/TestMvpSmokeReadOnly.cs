using Microsoft.Extensions.Logging;
using System;
using TiaMcpServer.Siemens;

namespace TiaMcpServer.Test
{
    /// <summary>
    /// MVP smoke test — exercises the most-used READ-ONLY tools against a running
    /// TIA Portal session to confirm they return sensible results before release.
    /// Does NOT modify the project, change online state, or push anything to the CPU.
    ///
    /// Requires: TIA Portal running with a project open. The test auto-discovers
    /// the first PlcSoftware path found in the project tree.
    /// </summary>
    [TestClass]
    [DoNotParallelize]
    public sealed class TestMvpSmokeReadOnly
    {
        private static Portal? _portal;

        [ClassInitialize]
        public static void Init(TestContext _)
        {
            var loggerFactory = LoggerFactory.Create(b => { b.AddConsole(); b.SetMinimumLevel(LogLevel.Warning); });
            _portal = new Portal(loggerFactory.CreateLogger<Portal>());
        }

        [TestMethod]
        public void Smoke_All_ReadOnly_Tools()
        {
            Assert.IsNotNull(_portal, "Portal not initialized");
            var passes = 0;
            var fails = 0;
            void Check(string label, Func<bool> body)
            {
                try
                {
                    var ok = body();
                    Console.WriteLine($"  [{(ok ? "PASS" : "FAIL")}] {label}");
                    if (ok) passes++; else fails++;
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"  [FAIL] {label} — {ex.GetType().Name}: {ex.Message}");
                    fails++;
                }
            }

            Console.WriteLine("=== MVP Smoke (read-only) ===");

            // 1. Connect (attach to running TIA)
            Check("Connect attaches to running TIA Portal", () =>
            {
                var ok = _portal!.ConnectPortal();
                if (!ok) Console.WriteLine($"      LastConnectError={_portal.LastConnectError}");
                return ok;
            });

            // 2. GetProjectTree returns non-empty content
            string? softwarePath = null;
            Check("GetProjectTree returns content + locates a PlcSoftware", () =>
            {
                var tree = _portal!.GetProjectTree();
                if (string.IsNullOrEmpty(tree)) return false;
                // Walk tree text to find first "PlcSoftware: <name>" line; its parent path becomes our test target
                softwarePath = ExtractFirstPlcSoftwarePath(tree);
                if (softwarePath == null) Console.WriteLine($"      no PlcSoftware in tree — open a project with at least one PLC");
                return softwarePath != null;
            });

            if (softwarePath == null)
            {
                Assert.Inconclusive("No PlcSoftware available in current TIA session — smoke test cannot proceed.");
                return;
            }
            Console.WriteLine($"  Target softwarePath: '{softwarePath}'");

            // 3. GetOnlineState returns a non-empty State
            Check("GetOnlineState returns a state name", () =>
            {
                var s = _portal!.GetOnlineState(softwarePath);
                Console.WriteLine($"      State={s.State}, IsOnline={s.IsOnline}, IsReachable={s.IsReachable}");
                return !string.IsNullOrEmpty(s.State);
            });

            // 4. GetSoftwareInfo (via the typed wrapper that uses Portal underneath)
            Check("GetBlocks returns a list (may be empty for new project)", () =>
            {
                var blocks = _portal!.GetBlocks(softwarePath, "");
                if (blocks == null) return false;
                Console.WriteLine($"      blocks count={blocks.Count}");
                return true;
            });

            // 5. GetTechnologyObjects returns a list (may be empty)
            Check("GetTechnologyObjects returns a list", () =>
            {
                var tos = _portal!.GetTechnologyObjects(softwarePath);
                Console.WriteLine($"      TO count={tos.Count}");
                return tos != null;
            });

            // 6. GetPlcWatchTables — null is acceptable (PLC has no WatchAndForceTableGroup)
            Check("GetPlcWatchTables completes without exception", () =>
            {
                var watch = _portal!.GetPlcWatchTables(softwarePath);
                Console.WriteLine($"      watch table count={watch?.Count.ToString() ?? "(none — group not exposed)"}");
                return true; // tool returning null on PLCs without watch tables is valid behavior
            });

            // 7. CompareSoftwareToOnline — non-null structured response (offline / not-found are valid responses)
            Check("CompareSoftwareToOnline returns a structured response", () =>
            {
                var cmp = _portal!.CompareSoftwareToOnline(softwarePath, maxDepth: 2, maxEntries: 50);
                Console.WriteLine($"      IsOnline={cmp?.IsOnline}, Entries={cmp?.Entries?.Length ?? 0}, Msg={cmp?.Message}");
                return cmp != null; // any non-null response counts; offline/not-found is a valid contract response
            });

            // 8. GetProjects (handle still alive)
            Check("GetProjects (portal handle still alive)", () =>
            {
                var projects = _portal!.GetProjects();
                Console.WriteLine($"      projects open={projects.Count}");
                return projects != null;
            });

            Console.WriteLine($"=== {passes} passed, {fails} failed ===");
            Assert.AreEqual(0, fails, "One or more smoke checks failed; see Console output above.");
        }

        private static string? ExtractFirstPlcSoftwarePath(string tree)
        {
            // Project tree format printed by Portal.GetProjectTree() uses lines like:
            //   "│   ├── PlcSoftware: <name> [PLC Program]" inside a Device subtree.
            // The Device path (e.g. "S7-1200 station_1/PLC_1") is what we need.
            //
            // Walk the tree text by indentation to reconstruct the device path that owns
            // the first PlcSoftware. Return null if none found.
            string[] lines = tree.Replace("\r", "").Split('\n');
            var stack = new System.Collections.Generic.List<(int indent, string name)>();
            string? lastDevicePath = null;
            foreach (var raw in lines)
            {
                if (string.IsNullOrWhiteSpace(raw)) continue;
                int indent = 0;
                while (indent < raw.Length && (raw[indent] == ' ' || raw[indent] == '│' || raw[indent] == '├'
                       || raw[indent] == '└' || raw[indent] == '─')) indent++;
                var content = raw.Substring(indent).Trim();
                if (content.StartsWith("PlcSoftware:"))
                {
                    return lastDevicePath;
                }
                // Track the most recent "[Device:" or "[DeviceItem]" line as a candidate device-path holder
                if (content.Contains("[Device:") || content.EndsWith("[DeviceItem]"))
                {
                    var name = content.Split('[')[0].Trim();
                    while (stack.Count > 0 && stack[stack.Count - 1].indent >= indent) stack.RemoveAt(stack.Count - 1);
                    stack.Add((indent, name));
                    lastDevicePath = string.Join("/", stack.ConvertAll(x => x.name));
                }
            }
            return null;
        }
    }

}
