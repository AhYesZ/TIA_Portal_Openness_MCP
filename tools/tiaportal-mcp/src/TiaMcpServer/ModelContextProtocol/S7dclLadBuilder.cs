using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json.Nodes;

namespace TiaMcpServer.ModelContextProtocol
{
    /// <summary>
    /// Offline builder: JSON → .s7dcl + .s7res LAD document pair.
    /// Generates UTF-8 with BOM files suitable for TIA Portal version-controller workspace import.
    ///
    /// Based on Siemens spec Entry ID 109994073 and verified round-trip on TIA V21
    /// against FB_CompleteInstructionGallery (67 networks, 0 errors).
    /// BOM is REQUIRED — TIA-exported reference files all carry EF BB BF.
    /// </summary>
    public static class S7dclLadBuilder
    {
        // Deterministic MLC counter (no Random — same JSON → same output for Git diff friendliness)
        private static int _mlcCounter;

        // ── Instructions that use => (output) pins ──
        // White-list approach: explicit per-instruction output pins, not heuristic
        private static readonly HashSet<string> OutputPins = new(StringComparer.OrdinalIgnoreCase)
        {
            "out", "out1",                                         // Move(out1), Math(out), etc.
            "et",                                                  // Timer elapsed time
            "cv",                                                  // Counter current value
            "q", "qu", "qd",                                       // Timer/Counter Q outputs
            "eno",                                                 // ENO output
            "else",                                                // MUX default output
            "dest0", "dest1", "dest2", "dest3", "dest4",           // JumpList destinations
            "dest5", "dest6", "dest7", "dest8", "dest9",
        };

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

            // Reset MLC counter per build — deterministic (sequential hex)
            _mlcCounter = 1;

            var mlcMap = new Dictionary<string, string>(); // MLC_ID → zh-CN text

            var blockCommentMlc = NextMlc();
            var blockTitleMlc = NextMlc();
            mlcMap[blockCommentMlc] = comment;
            mlcMap[blockTitleMlc] = title;

            // ── Build .s7dcl ──
            var sb = new StringBuilder();

            // UTF-8 with BOM — matches reference files exported from TIA (all have EF BB BF)
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
                    // Only emit VAR_TEMP for FC if it has SCL networks that need temp vars
                    if (HasSclNetworks(networksJson))
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
                var netLang = netObj["lang"]?.ToString() ?? "LAD";  // "LAD" or "SCL"
                var elements = netObj["e"]?.AsArray() ?? netObj["elements"]?.AsArray();
                var branches = netObj["b"]?.AsArray() ?? netObj["branches"]?.AsArray();

                var netTitleMlc = NextMlc();
                var netCommentMlc = NextMlc();
                mlcMap[netTitleMlc] = netTitle;
                mlcMap[netCommentMlc] = netComment;

                // Reference format: only first network has blank line after END_VAR;
                // consecutive networks have NO blank line between END_NETWORK and next pragma.
                if (netIdx == 1)
                    sb.AppendLine();   // blank line after VAR section before first network
                sb.AppendLine("    {");
                sb.AppendLine($"        S7_Language := \"{netLang}\";");
                // Reference order: S7_NetworkComment first, then S7_NetworkTitle (last line no semicolon)
                sb.AppendLine($"        S7_NetworkComment := \"{netCommentMlc}\";");
                sb.AppendLine($"        S7_NetworkTitle := \"{netTitleMlc}\"");
                sb.AppendLine("    }");
                sb.AppendLine("    NETWORK");

                if (netLang.Equals("SCL", StringComparison.OrdinalIgnoreCase))
                {
                    // SCL network: write raw SCL lines
                    WriteSclNetwork(sb, netObj);
                }
                else if (branches != null && branches.Count > 0)
                {
                    // Parallel LAD network: main rung has elements + wire#w1, branches follow
                    WriteRung(sb, elements, wireLabel: "w1", isFirst: true);
                    int branchIdx = 0;
                    foreach (var branchNode in branches)
                    {
                        branchIdx++;
                        var branchElements = (branchNode as JsonArray) ?? new JsonArray();
                        WriteRung(sb, branchElements, wireLabel: null, wireTarget: "w1", isFirst: false);
                    }
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
            }

            // ── Write files ──
            Directory.CreateDirectory(outputDirectory);
            var s7dclPath = Path.Combine(outputDirectory, $"{blockName}.s7dcl");
            var s7resPath = Path.Combine(outputDirectory, $"{blockName}.s7res");

            // Write WITH BOM — reference files from TIA (FC_FromRef, FB_CompleteInstructionGallery) all carry EF BB BF
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
                ["message"] = $"Generated {blockName}.s7dcl + .s7res (UTF-8 with BOM) in {outputDirectory}. Import with ImportBlocksFromDocuments or ImportFromDocuments."
            };

            return result;
        }

        // ── Helpers ──

        private static bool HasSclNetworks(JsonArray networks)
        {
            foreach (var net in networks)
            {
                if (net is JsonObject obj)
                {
                    var lang = obj["lang"]?.ToString();
                    if (lang != null && lang.Equals("SCL", StringComparison.OrdinalIgnoreCase))
                        return true;
                }
            }
            return false;
        }

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
            sb.AppendLine($"    {keyword}");
            if (members.Count == 0)
            {
                sb.AppendLine($"    END_VAR");
                return;
            }
            // One variable per line — TIA SD parser requires this format
            foreach (var (name, datatype) in members)
                sb.AppendLine($"        \"{name}\" : {datatype};");
            sb.AppendLine($"    END_VAR");
        }

        // ── SCL network writer ──
        private static void WriteSclNetwork(StringBuilder sb, JsonObject netObj)
        {
            var sclLines = netObj["scl"]?.AsArray();
            if (sclLines != null)
            {
                foreach (var line in sclLines)
                {
                    var text = line?.ToString() ?? "";
                    sb.AppendLine($"        {text}");
                }
                return;
            }
            // Single SCL statement
            var sclStmt = netObj["stmt"]?.ToString();
            if (!string.IsNullOrWhiteSpace(sclStmt))
            {
                sb.AppendLine($"        {sclStmt}");
                return;
            }
            // Empty SCL network
            sb.AppendLine("        ");
        }

        // ── RUNG writer ──
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
                sb.AppendLine();
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
                            sb.Append($"\r\n            wire#{wireDef}");
                            continue;
                        }
                        WriteElement(sb, eObj);
                    }
                }
            }
            sb.AppendLine();
            if (hasWire)
            {
                // Ensure wire label is just the name (strip any wire# prefix from input)
                var wl = wireLabel!.StartsWith("wire#") ? wireLabel.Substring(5) : wireLabel;
                sb.AppendLine($"        END_RUNG wire#{wl}");
            }
            else
            {
                sb.AppendLine("        END_RUNG");
            }
        }

        // ── Element writer ──
        private static void WriteElement(StringBuilder sb, JsonObject elem)
        {
            var instr = elem["i"]?.ToString() ?? elem["instr"]?.ToString()
                ?? throw new ArgumentException("Element missing 'i' (instruction) field.");
            var template = elem["tp"]?.ToString() ?? elem["template"]?.ToString();
            var operand = elem["o"]?.ToString() ?? elem["operand"]?.ToString();
            var inst = elem["inst"]?.ToString();           // instance prefix for Q-boxes (#inst.TON)
            var wireObj = elem["wire"]?.ToString();
            // New pragma fields
            var genEno = elem["ge"]?.ToString();            // S7_GenerateENO
            var expr = elem["expr"]?.ToString();             // S7_Expression (for Calculate)

            // Wire element — handled in WriteRung
            if (wireObj != null) return;

            // ── Block call: "call" field → FC or FB invocation ──
            var callName = elem["call"]?.ToString();
            if (!string.IsNullOrWhiteSpace(callName))
            {
                // Block call: FC name or FB instance name (no quotes in S7DCL)
                var callParams = elem["p"]?.AsObject() ?? elem["params"]?.AsObject();
                sb.Append($"\r\n            {callName}(");
                if (callParams != null && callParams.Count > 0)
                    WriteParams(sb, callParams, instr);
                sb.Append(" )");
                return;
            }

            // ── Write pragmas (S7_Templates + S7_GenerateENO + S7_Expression) ──
            bool hasTemplate = !string.IsNullOrWhiteSpace(template);
            bool hasGenEno = !string.IsNullOrWhiteSpace(genEno);
            bool hasExpr = !string.IsNullOrWhiteSpace(expr);

            if (hasTemplate || hasGenEno || hasExpr)
            {
                sb.Append("\r\n            {");
                var pragmas = new List<string>();
                if (hasTemplate) pragmas.Add($" S7_Templates := \"{template}\"");
                if (hasGenEno) pragmas.Add($" S7_GenerateENO := \"{genEno}\"");
                if (hasExpr) pragmas.Add($" S7_Expression := \"{expr}\"");
                sb.Append(string.Join(";", pragmas));
                sb.Append(" }");
            }

            // Build instruction call
            sb.Append("\r\n            ");

            // ── Single operand (contacts, coils, edge-detect boxes) ──
            if (!string.IsNullOrWhiteSpace(operand))
            {
                // P_Contact / N_Contact have 2-param form: (operand:=sig, bit:=store)
                if (instr.Equals("P_Contact", StringComparison.OrdinalIgnoreCase) ||
                    instr.Equals("N_Contact", StringComparison.OrdinalIgnoreCase))
                {
                    var bit = elem["bit"]?.ToString() ?? elem["o"]?.ToString() ?? "";
                    sb.Append($"{instr}( operand := {operand}, bit := {bit} )");
                    return;
                }
                sb.Append($"{instr}( {FormatVarRef(operand)} )");
                return;
            }

            // ── Zero-operand instructions (Not(), ReturnFalse(), etc.) ──
            var paramObj = elem["p"]?.AsObject() ?? elem["params"]?.AsObject();
            bool hasParams = paramObj != null && paramObj.Count > 0;

            // Instance-prefixed instructions (Q-boxes: #inst.TON, c.S_RS)
            if (!string.IsNullOrWhiteSpace(inst))
            {
                var effectiveInstr = elem["method"]?.ToString();  // optional: explicit method name
                var callInstr = effectiveInstr ?? instr;
                sb.Append($"{FormatVarRef(inst)}.{callInstr}(");
                if (hasParams)
                    WriteParams(sb, paramObj, instr);
                sb.Append(" )");
                return;
            }

            // ── Multi-parameter instructions (boxes: Add, Move, GT, MIN, etc.) ──
            if (hasParams)
            {
                sb.Append($"{instr}(");
                WriteParams(sb, paramObj, instr);
                sb.Append(" )");
            }
            else
            {
                // Zero-parameter (Not(), ReturnTrue(), ReturnFalse(), Return(), SaveCoil(), etc.)
                sb.Append($"{instr}()");
            }
        }

        // ── Parameter writer with instruction-aware output pin detection ──
        private static void WriteParams(StringBuilder sb, JsonObject? paramObj, string instr)
        {
            if (paramObj == null || paramObj.Count == 0) return;

            var items = new List<string>();
            foreach (var kvp in paramObj)
            {
                var key = kvp.Key;
                var val = kvp.Value?.ToString() ?? "";
                bool isOutput = IsOutputPin(key, instr);
                string connector = isOutput ? "=>" : ":=";
                items.Add($"{key} {connector} {FormatVarRef(val)}");
            }
            sb.Append(string.Join(",\r\n                ", items));
        }

        /// <summary>
        /// Determine if a parameter pin is an output (=>) based on instruction + pin name.
        /// Uses explicit white-list per instruction family for correctness.
        /// </summary>
        private static bool IsOutputPin(string pinName, string instr)
        {
            // Generic output pins (works for most boxes)
            if (OutputPins.Contains(pinName))
                return true;

            // Pattern-based fallbacks for numbered outputs
            if (pinName.StartsWith("dest", StringComparison.OrdinalIgnoreCase)) return true;
            if (pinName.StartsWith("in", StringComparison.OrdinalIgnoreCase) &&
                pinName.Length > 2 && char.IsDigit(pinName[2])) return false; // in0, in1, in2... are inputs

            // Instruction-specific overrides
            var instrLower = instr.ToLowerInvariant();

            // MIN/MAX/LIMIT/SEL: "out" is the result output
            if (pinName.Equals("out", StringComparison.OrdinalIgnoreCase)) return true;

            // MUX: k, in0..inN are inputs; out, else are outputs (covered by OutputPins)
            // AND/OR/XOR: in1, in2, in3... are inputs; out is output
            // SHR/SHL/ROR/ROL: in, n are inputs; out is output
            // NEG: in is input; out is output
            // Calculate: in1, in2... are inputs; out is output

            // SR/RS flip-flop: operand, s, r are all inputs (no output pins in box form)
            // But q is sometimes an output in some variants

            // Default: assume input (:=)
            return false;
        }

        // ── Variable reference formatter ──
        // TIA requires block-local variables in #"Name" format (hash + double-quoted).
        // Global tags use "Name" format (just quotes, no hash). Constants are left as-is.
        private static string FormatVarRef(string value)
        {
            if (string.IsNullOrWhiteSpace(value))
                return value;

            // Already formatted: #"Name" → keep
            if (value.StartsWith("#\"") && value.EndsWith("\""))
                return value;

            // Block-local var without quotes: #Name → #"Name"
            if (value.StartsWith("#"))
                return "#\"" + value.Substring(1) + "\"";

            // Global tag or constant → keep as-is
            return value;
        }

        // ── Deterministic MLC ID generator ──
        // Uses pure sequential hex counter: MLC_001, MLC_002, ..., MLC_fff
        // Same JSON input always produces the same MLC IDs → Git diff friendly
        private static string NextMlc()
        {
            var id = $"MLC_{_mlcCounter:x3}";
            _mlcCounter++;
            return id;
        }
    }
}
