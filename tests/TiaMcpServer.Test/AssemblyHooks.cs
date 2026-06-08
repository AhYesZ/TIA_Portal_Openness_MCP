using System;
using System.IO;
using System.Reflection;
using TiaMcpServer.Siemens;

namespace TiaMcpServer.Test
{
    [TestClass]
    public class AssemblyHooks
    {
        [AssemblyInitialize]
        public static void AssemblyInit(TestContext context)
        {
            // The Siemens.Collaboration.Net.TiaPortal.Openness.Resolver does not always
            // hook AssemblyResolve in time when running under MSTest's test host.
            // Fall back to a manual resolver pointing at TiaPortalLocation.
            AppDomain.CurrentDomain.AssemblyResolve += ResolveSiemensEngineering;

            Openness.Initialize();
        }

        private static Assembly? ResolveSiemensEngineering(object? sender, ResolveEventArgs args)
        {
            var name = new AssemblyName(args.Name).Name;
            if (string.IsNullOrEmpty(name) || !name.StartsWith("Siemens.Engineering"))
                return null;

            var tiaLoc = Environment.GetEnvironmentVariable("TiaPortalLocation");
            if (string.IsNullOrEmpty(tiaLoc)) return null;

            var probes = new[]
            {
                Path.Combine(tiaLoc!, @"PublicAPI\V21\net48", name + ".dll"),
                Path.Combine(tiaLoc!, @"PublicAPI\V20\net48", name + ".dll"),
                Path.Combine(tiaLoc!, @"Bin\PublicAPI",        name + ".dll"),
            };
            foreach (var p in probes)
            {
                if (File.Exists(p)) return Assembly.LoadFrom(p);
            }
            return null;
        }

        [AssemblyCleanup]
        public static void AssemblyCleanup()
        {
            // Runs once after all tests in the assembly  
            // Console.WriteLine("Assembly cleanup completed");
        }
    }
}
