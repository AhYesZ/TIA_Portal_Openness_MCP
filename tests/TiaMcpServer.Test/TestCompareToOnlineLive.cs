using Microsoft.Extensions.Logging;
using System;
using TiaMcpServer.Siemens;

namespace TiaMcpServer.Test
{
    /// <summary>
    /// Live-against-TIA validation for CompareSoftwareToOnline.
    /// Requires: TIA Portal running, project open, target PLC currently online.
    /// Uses only the Portal facade — does NOT reference Siemens.Engineering types
    /// directly, otherwise JIT would fail to resolve them in this test assembly.
    /// </summary>
    [TestClass]
    [DoNotParallelize]
    public sealed class TestCompareToOnlineLive
    {
        private static Portal? _portal;

        [ClassInitialize]
        public static void Init(TestContext _)
        {
            var loggerFactory = LoggerFactory.Create(b => { b.AddConsole(); b.SetMinimumLevel(LogLevel.Information); });
            _portal = new Portal(loggerFactory.CreateLogger<Portal>());
        }

        [TestMethod]
        public void Compare_LivePlc_AutoDiscover()
        {
            Assert.IsNotNull(_portal, "Portal not initialized");

            var connected = _portal.ConnectPortal();
            Assert.IsTrue(connected, $"Failed to attach to running TIA Portal. LastConnectError={_portal.LastConnectError}");

            Console.WriteLine("=== Project tree ===");
            var tree = _portal.GetProjectTree();
            Console.WriteLine(string.IsNullOrEmpty(tree) ? "(empty — no project open?)" : tree);

            // Candidate softwarePaths to probe — from most-likely to least-likely
            var candidates = new[]
            {
                "S7-1200 station_1/机组PLC", // confirmed valid path from project tree above
            };

            string? working = null;
            foreach (var c in candidates)
            {
                Console.WriteLine($"\nProbing softwarePath: '{c}'");
                var probe = _portal.GetOnlineState(c);
                Console.WriteLine($"  State='{probe.State}' Msg='{probe.Message}'");
                // Accept any path whose probe doesn't say "PLC software not found".
                if (probe.Message == null || !probe.Message.Contains("not found"))
                {
                    working = c;
                    break;
                }
            }

            if (working == null)
            {
                Console.WriteLine("\nNo candidate path matched. Open the test output above and copy the actual PLC path; rerun with that path.");
                Assert.Inconclusive("Could not auto-discover softwarePath. See tree above and adjust candidates[].");
                return;
            }

            Console.WriteLine($"\n=== Using softwarePath: '{working}' ===");

            var state = _portal.GetOnlineState(working);
            Console.WriteLine($"Online state: {state.State} (IsOnline={state.IsOnline})");

            Console.WriteLine($"\n=== Calling CompareSoftwareToOnline ===");
            var result = _portal.CompareSoftwareToOnline(working, maxDepth: 4, maxEntries: 100);
            Console.WriteLine($"Message:   {result.Message}");
            Console.WriteLine($"IsOnline:  {result.IsOnline}");
            Console.WriteLine($"Truncated: {result.Truncated}");

            if (result.Summary != null && result.Summary.Count > 0)
            {
                Console.WriteLine("Status summary (count of each ComparisonResult):");
                foreach (var kv in result.Summary)
                    Console.WriteLine($"  {kv.Key}: {kv.Value}");
            }

            if (result.Entries != null && result.Entries.Length > 0)
            {
                int n = Math.Min(result.Entries.Length, 30);
                Console.WriteLine($"\nDifferences (showing top {n} of {result.Entries.Length}):");
                for (int i = 0; i < n; i++)
                {
                    var e = result.Entries[i];
                    Console.WriteLine($"  [{e.Status,-15}] {e.Path}    L='{e.LeftName}' R='{e.RightName}'  {e.Details}");
                }
            }
            else
            {
                Console.WriteLine("\nNo differences reported (or precondition not met).");
            }

            Assert.IsNotNull(result, "Result should not be null");
        }
    }
}
