using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace TiaMcpServer.ModelContextProtocol
{
    /// <summary>
    /// Offline builder: JSON → .s7dcl + .s7res LAD document pair.
    /// Generates UTF-8 with BOM files suitable for ImportBlocksFromDocuments / ImportFromDocuments.
    ///
    /// Based on Siemens spec Entry ID 109994073 and verified round-trip on TIA V21.
    /// </summary>
    public static class S7dclLadBuilder
    {
        private static readonly Random _rng = new();
        private static int _mlcCounter;

        // ── Public entry point ──

        public static JsonObject BuildFromJson(string json, string outputDirectory)
        {
            var root = JsonNode.Parse(json) as JsonObject
                ?? throw new ArgumentException("S7DCL builder JSON root must be an object.");

            var blockKind = (root["blockKind"]?.ToString() ?? root["k"]?.ToString() ?? "fc").ToLowerInvariant();
            var blockName = root["blockName"]?.ToString() ?? root["n"]?.ToString()
                ?? throw new ArgumentException("blockName is required.");
            var blockNumber = root["blockNumber"]?.GetValue<int>() ?? root["num"]?.GetValue<int>() ?? 0;
            var comment = root["comment"]?.ToString() ?? root["c"]?.ToString() ?? "";
            var title = root["title"]?.ToString() ?? root["t"]?.ToString() ?? blockName;

            var inputs = ParseMembers(root["inputs"] ?? root["i"]);
            var outputs = ParseMembers(root["outputs"] ?? root["o"]);
            var statics = ParseMembers(root["statics"] ?? root["s"]);

            var networksJson = root["networks"]?.AsArray() ?? root["nw"]?.AsArray()
                ?? new JsonArray();

            // Reset MLC counter per build
            _mlcCounter = 1;

            var mlcMap = new Dictionary<string, string>(); // MLC_ID → zh-CN text

            var blockCommentMlc = NextMlc();
            var blockTitleMlc = NextMlc();
            mlcMap[blockCommentMlc] = comment;
            mlcMap[blockTitleMlc] = title;

            // ── Build .s7dcl ──
            var sb = new StringBuilder();

            // UTF-8 BOM will be written by File.WriteAllText with UTF8Encoding(true)
            // Block pragma header
            sb.AppendLine("{");
            sb.AppendLine($"    S7_BlockComment := \"{blockCommentMlc}\";");
            sb.AppendLine($"    S7_BlockNumber := \"{blockNumber}\";");
            sb.AppendLine($"    S7_BlockTitle := \"{blockTitleMlc}\";");
            sb.AppendLine("    S7_Optimized := \"TRUE\";");
            sb.AppendLine("    S7_PreferredLanguage := \"LAD\";");
            sb.AppendLine("    S7_Version := \"0.1\"");
            sb.AppendLine("}");

            switch (blockKind)
            {
                case "fc":
                    sb.AppendLine($"FUNCTION \"{blockName}\" : Void");
                    WriteVarSection(sb, "VAR_INPUT", inputs);
                    WriteVarSection(sb, "VAR_OUTPUT", outputs);
                    WriteVarSection(sb, "VAR_TEMP", new List<(string, string)>());
                    break;
                case "fb":
                    sb.AppendLine($"FUNCTION_BLOCK \"{blockName}\"");
                    WriteVarSection(sb, "VAR_INPUT", inputs);
                    WriteVarSection(sb, "VAR_OUTPUT", outputs);
                    WriteVarSection(sb, "VAR", statics);
                    WriteVarSection(sb, "VAR_TEMP", new List<(string, string)>());
                    break;
                case "ob":
                    sb.AppendLine($"ORGANIZATION_BLOCK \"{blockName}\"");
                    break;
                default:
                    throw new ArgumentException($"Unknown blockKind: {blockKind}. Use fc, fb, or ob.");
            }

            // Networks
            int netIdx = 0;
            foreach (var netNode in networksJson)
            {
                if (netNode is not JsonObject netObj) continue;
                netIdx++;

                var netTitle = netObj["t"]?.ToString() ?? netObj["title"]?.ToString() ?? $"N{netIdx}";
                var netComment = netObj["c"]?.ToString() ?? netObj["comment"]?.ToString() ?? "";
                var elements = netObj["e"]?.AsArray() ?? netObj["elements"]?.AsArray();
                var branches = netObj["b"]?.AsArray() ?? netObj["branches"]?.AsArray();

                var netTitleMlc = NextMlc();
                var netCommentMlc = NextMlc();
                mlcMap[netTitleMlc] = netTitle;
                mlcMap[netCommentMlc] = netComment;

                sb.AppendLine();
                sb.AppendLine("    {");
                sb.AppendLine($"        S7_Language := \"LAD\";");
                sb.AppendLine($"        S7_NetworkComment := \"{netTitleMlc}\";");
                sb.AppendLine($"        S7_NetworkTitle := \"{netCommentMlc}\"");
                sb.AppendLine("    }");
                sb.AppendLine("    NETWORK");

                if (branches != null && branches.Count > 0)
                {
                    // Parallel network: first rung has main elements + wire#w1, subsequent rungs are branches
                    WriteRung(sb, elements, wireLabel: "w1", isFirst: true);
                    int branchIdx = 0;
                    foreach (var branchNode in branches)
                    {
                        branchIdx++;
                        var branchElements = (branchNode as JsonArray) ?? new JsonArray();
                        WriteRung(sb, branchElements, wireTarget: "w1", isFirst: false);
                    }
                    _ = branchIdx; // suppress unused warning
                }
                else
                {
                    WriteRung(sb, elements, wireLabel: null, isFirst: true);
                }

                sb.AppendLine("    END_NETWORK");
            }

            sb.AppendLine(blockKind == "ob" ? "END_ORGANIZATION_BLOCK" :
                          blockKind == "fb" ? "END_FUNCTION_BLOCK" : "END_FUNCTION");

            // ── Build .s7res ──
            var s7resSb = new StringBuilder();
            s7resSb.AppendLine("MultiLingualTexts:");
            foreach (var kvp in mlcMap)
            {
                s7resSb.AppendLine($"  - id: {kvp.Key}");
                s7resSb.AppendLine($"    zh-CN: {kvp.Value}");
                s7resSb.AppendLine($"    en-US: {kvp.Value}");
            }

            // ── Write files ──
            Directory.CreateDirectory(outputDirectory);
            var s7dclPath = Path.Combine(outputDirectory, $"{blockName}.s7dcl");
            var s7resPath = Path.Combine(outputDirectory, $"{blockName}.s7res");

            // Write with UTF-8 BOM
            File.WriteAllText(s7dclPath, sb.ToString(), new UTF8Encoding(true));
            File.WriteAllText(s7resPath, s7resSb.ToString(), new UTF8Encoding(true));

            var result = new JsonObject
            {
                ["format"] = "tia-s7dcl-lad-build-offline-v1",
                ["timestamp"] = DateTime.Now.ToString("O"),
                ["offlineOnly"] = true,
                ["ok"] = true,
                ["blockKind"] = blockKind,
                ["blockName"] = blockName,
                ["blockNumber"] = blockNumber,
                ["outputDirectory"] = outputDirectory,
                ["outputFiles"] = new JsonArray(s7dclPath, s7resPath),
                ["mlcCount"] = mlcMap.Count,
                ["networkCount"] = netIdx,
                ["message"] = $"Generated {blockName}.s7dcl + .s7res (UTF-8 BOM) in {outputDirectory}. Import with ImportBlocksFromDocuments or ImportFromDocuments."
            };

            return result;
        }

        // ── Helpers ──

        private static List<(string name, string datatype)> ParseMembers(JsonNode? node)
        {
            var result = new List<(string, string)>();
            if (node is JsonArray arr)
            {
                foreach (var item in arr)
                {
                    if (item is JsonObject obj)
                    {
                        var n = obj["n"]?.ToString() ?? obj["name"]?.ToString() ?? "";
                        var t = obj["t"]?.ToString() ?? obj["datatype"]?.ToString() ?? "Bool";
                        if (!string.IsNullOrWhiteSpace(n))
                            result.Add((n, t));
                    }
                }
            }
            return result;
        }

        private static void WriteVarSection(StringBuilder sb, string keyword, List<(string name, string datatype)> members)
        {
            if (members.Count == 0)
            {
                sb.AppendLine($"    {keyword}");
                sb.AppendLine($"    END_VAR");
                return;
            }
            sb.Append($"    {keyword}");
            foreach (var (name, datatype) in members)
                sb.Append($"  \"{name}\" : {datatype};");
            sb.AppendLine($"  END_VAR");
        }

        private static void WriteRung(StringBuilder sb, JsonArray? elements, string? wireLabel, bool isFirst, string? wireTarget = null)
        {
            if (!isFirst)
            {
                // Branch rung — starts with wire#powerrail, has elements, ends with wire target
                sb.Append("        RUNG wire#powerrail");
                if (elements != null)
                {
                    foreach (var elem in elements)
                    {
                        if (elem is JsonObject eObj)
                            WriteElement(sb, eObj);
                    }
                }
                if (wireTarget != null)
                    sb.AppendLine($"        END_RUNG wire#{wireTarget}");
                else
                    sb.AppendLine("        END_RUNG");
                return;
            }

            // Main rung
            sb.Append("        RUNG wire#powerrail");
            bool hasWire = wireLabel != null;

            if (elements != null)
            {
                foreach (var elem in elements)
                {
                    if (elem is JsonObject eObj)
                    {
                        // Check if this element itself defines a wire
                        var wireDef = eObj["wire"]?.ToString();
                        if (wireDef != null)
                        {
                            sb.Append($"\n            wire#{wireDef}");
                            continue;
                        }
                        WriteElement(sb, eObj);
                    }
                }
            }
            sb.AppendLine();
            if (hasWire)
                sb.AppendLine($"        END_RUNG wire#{wireLabel}");
            else
                sb.AppendLine("        END_RUNG");
        }

        private static void WriteElement(StringBuilder sb, JsonObject elem)
        {
            var instr = elem["i"]?.ToString() ?? elem["instr"]?.ToString()
                ?? throw new ArgumentException("Element missing 'i' (instruction) field.");
            var template = elem["tp"]?.ToString() ?? elem["template"]?.ToString();
            var operand = elem["o"]?.ToString() ?? elem["operand"]?.ToString();
            var inst = elem["inst"]?.ToString(); // instance prefix for Q-boxes (c.S_RS)
            var wireObj = elem["wire"]?.ToString();

            // Wire element — handled in WriteRung
            if (wireObj != null) return;

            // If template specified, write pragma on its own indented line
            if (!string.IsNullOrWhiteSpace(template))
                sb.Append($"\n            {{ S7_Templates := \"{template}\" }}");

            // Build instruction call
            sb.Append("\n            ");

            // Single operand (coils, contacts with one operand)
            if (!string.IsNullOrWhiteSpace(operand))
            {
                sb.Append($"{instr}( {operand} )");
                return;
            }

            // Instance-prefixed instructions (Q-boxes: c.S_RS, #inst.TON)
            if (!string.IsNullOrWhiteSpace(inst))
            {
                var p = elem["p"]?.AsObject() ?? elem["params"]?.AsObject();
                sb.Append($"{inst}.{instr}(");
                WriteParams(sb, p, instr);
                sb.Append(" )");
                return;
            }

            // Multi-parameter instructions (boxes: Add, Move, TON, etc.)
            var paramObj = elem["p"]?.AsObject() ?? elem["params"]?.AsObject();
            if (paramObj != null && paramObj.Count > 0)
            {
                sb.Append($"{instr}(");
                WriteParams(sb, paramObj, instr);
                sb.Append(" )");
            }
            else
            {
                // Zero-parameter (Not(), ReturnTrue(), etc.)
                sb.Append($"{instr}()");
            }
        }

        private static void WriteParams(StringBuilder sb, JsonObject? paramObj, string instr)
        {
            if (paramObj == null || paramObj.Count == 0) return;

            var items = new List<string>();
            foreach (var kvp in paramObj)
            {
                var key = kvp.Key;
                var val = kvp.Value?.ToString() ?? "";
                // Determine if this param is an input (:=) or output (=>)
                // Common output params: out, out1, et, cv, q, qu, qd, dest0..destN, eno
                bool isOutput = key == "out" || key.StartsWith("out") || key == "et" || key == "cv" ||
                                key == "q" || key == "qu" || key == "qd" || key.StartsWith("dest") || key == "eno" || key == "else";
                string connector = isOutput ? "=>" : ":=";
                items.Add($"{key} {connector} {val}");
            }
            sb.Append(string.Join(",\n                ", items));
        }

        private static string NextMlc()
        {
            // Generate unique MLC IDs like MLC_3fA, MLC_4X9, etc.
            // Use hex encoding of counter for compact unique IDs
            var id = $"MLC_{_mlcCounter:x}{(_rng.Next(0, 16)).ToString("x")}{(_rng.Next(0, 16)).ToString("x")}";
            _mlcCounter++;
            return id;
        }
    }
}
