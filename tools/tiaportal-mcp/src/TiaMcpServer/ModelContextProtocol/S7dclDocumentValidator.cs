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
    /// Offline validator for SIMATIC SD (.s7dcl + .s7res) LAD document pairs.
    /// Checks UTF-8 BOM status, block declarations, network pragmas, MLC cross-references,
    /// wire consistency, known instructions, and common trap patterns — all without
    /// connecting to TIA Portal.
    /// .s7res is only required when .s7dcl contains MLC references (matching TIA export).
    ///
    /// Based on Siemens spec Entry ID 109994073 §4 Instructions.
    /// </summary>
    public static class S7dclDocumentValidator
    {
        // ── Known instruction names from §3 of s7dcl-lad-reference.md ──
        private static readonly HashSet<string> KnownContacts = new(StringComparer.OrdinalIgnoreCase)
        {
            "Contact", "I_Contact", "P_Contact", "N_Contact",
            "GT_Contact", "LT_Contact", "EQ_Contact", "NE_Contact",
            "GE_Contact", "LE_Contact",
            "IsValidContact", "IsNotValidContact",
            "IsArrayContact", "IsNotArrayContact",
            "IsNullContact", "IsNotNullContact",
            "EQ_TypeContact", "NE_TypeContact",
            "EQ_ElemTypeContact", "NE_ElemTypeContact",
            "EQ_TypeOfDBContact", "NE_TypeOfDBContact",
            "BR_FlagContact", "OS_FlagContact", "OV_FlagContact", "UO_FlagContact",
            "BR_I_Flag_Contract", "OS_I_Flag_Contract", "OV_I_Flag_Contract", "UO_I_Flag_Contract",
            "EQ_FlagsContact", "NE_FlagsContact", "GE_FlagsContact", "LE_FlagsContact",
            "GT_FlagsContact", "LT_FlagsContact",
            "EQ_I_Flags_Contract", "NE_I_Flags_Contract", "GE_I_Flags_Contract",
            "LE_I_Flags_Contract", "GT_I_Flags_Contract", "LT_I_Flags_Contract"
        };

        private static readonly HashSet<string> KnownCoils = new(StringComparer.OrdinalIgnoreCase)
        {
            "Coil", "I_Coil", "S_Coil", "R_Coil",
            "P_Coil", "N_Coil",
            "TP_Coil", "TOn_Coil", "TOf_Coil", "TOnr_Coil",
            "SP_Coil", "SE_Coil", "SD_Coil", "SS_Coil", "SF_Coil",
            "PT_Coil", "RT_Coil",
            "CU_Coil", "CD_Coil", "SC_Coil",
            "R_BitfieldCoil", "S_BitfieldCoil",
            "JumpCoil", "I_JumpCoil",
            "ReturnCoil", "CallCoil",
            "OpenDBCoil", "OpenDICoil"
        };

        private static readonly HashSet<string> KnownZeroOpCoils = new(StringComparer.OrdinalIgnoreCase)
        {
            "ReturnFalse", "ReturnTrue", "Return",
            "McrOpenCoil", "McrCloseCoil", "McrActivateCoil", "McrDeactivateCoil", "SaveCoil"
        };

        private static readonly HashSet<string> KnownBoxes = new(StringComparer.OrdinalIgnoreCase)
        {
            "Add", "Sub", "Mul", "Div", "Mod",
            "Move", "Convert", "Calculate",
            // Comparison boxes (NOT CMP >=!)
            "GT", "LT", "EQ", "NE", "GE", "LE",
            // Edge detection boxes
            "P_Trig", "N_Trig",
            // Q-Boxes
            "TP", "TON", "TOF", "TONR",
            "Ctu", "Ctd", "Ctud",
            "S_Cu", "S_Cd", "S_Cud",
            "S_RS", "S_SR",
            // Selectors
            "MIN", "MAX", "LIMIT", "SEL", "MUX",
            // Shift/Rotate/Logic
            "SHR", "SHL", "ROR", "ROL",
            "AND", "OR", "XOR", "INV", "NEG",
            // Jumps
            "JumpList", "Switch",
            // Special
            "Not", "Label"
        };

        private static readonly HashSet<string> AllKnownInstructions;
        private static readonly Regex MlcRefRegex = new(@"MLC_[0-9a-fA-F]+", RegexOptions.Compiled);
        private static readonly Regex InstructionRegex = new(@"\b([A-Z][A-Za-z_0-9]*)\s*\(", RegexOptions.Compiled);
        private static readonly Regex BlockDeclRegex = new(@"(FUNCTION|FUNCTION_BLOCK|ORGANIZATION_BLOCK)\s+""([^""]+)""", RegexOptions.Compiled);
        private static readonly Regex WireRefRegex = new(@"wire#[a-zA-Z_][a-zA-Z0-9_]*", RegexOptions.Compiled);
        private static readonly Regex WirePowerrailRegex = new(@"wire#powerrail", RegexOptions.Compiled);
        private static readonly Regex NetworkPragmaRegex = new(@"\{\s*S7_Language\s*:=\s*""(LAD|SCL|FBD|STL)""", RegexOptions.Compiled);
        private static readonly Regex NetworkKeywordRegex = new(@"^\s*NETWORK\s*$", RegexOptions.Compiled | RegexOptions.Multiline);
        private static readonly Regex S7resEntryRegex = new(@"^\s*-\s+id:\s*(\S+)", RegexOptions.Compiled | RegexOptions.Multiline);
        private static readonly Regex ZhCnRegex = new(@"zh-CN:", RegexOptions.Compiled);
        private static readonly Regex JumpReturnRegex = new(@"\b(JumpCoil|I_JumpCoil|ReturnCoil|ReturnFalse|ReturnTrue|Return|JumpList|Switch)\s*\(", RegexOptions.Compiled);

        // Trap detection: wire# directly between a Contact (or other rung-in) and an ENO-Box
        // (ENO-boxes take EN input; Coil/S_Coil/R_Coil after wire# is valid parallel-OR)
        private static readonly Regex ContactThenWireThenBoxRegex = new(
            @"(Contact|I_Contact|P_Contact|N_Contact|GT_Contact|LT_Contact|EQ_Contact|NE_Contact|GE_Contact|LE_Contact)\s*\([^)]*\)\s*\n\s*wire#[a-zA-Z_][a-zA-Z0-9_]*\s*\n\s*(Add|Sub|Mul|Div|Mod|Move|Convert|Calculate|TP|TON|TOF|TONR|Ctu|Ctd|Ctud|MIN|MAX|LIMIT|SEL|MUX|SHR|SHL|ROR|ROL|AND|OR|XOR|INV|NEG|GT|LT|EQ|NE|GE|LE)\s*\(",
            RegexOptions.Compiled | RegexOptions.IgnorePatternWhitespace);

        // ── Vendor confusion: instructions that belong to OTHER PLC vendors ──
        // Allen-Bradley / Rockwell RSLogix 500/5000
        private static readonly HashSet<string> AllenBradleyInstructions = new(StringComparer.OrdinalIgnoreCase)
        {
            "XIC", "XIO", "OTE", "OTL", "OTU", "ONS", "OSR", "OSF",
            "NEQ", "GRT", "LES", "LEQ", "GEQ", "MEQ", "LIM", "CMP",
            "ADD", "SUB", "MUL", "DIV", "MOV", "CPT", "JSR", "SBR", "RET",
            "TON", "TOF", "RTO", "CTU", "CTD", "RES"
        };

        // Modicon / Schneider Electric
        private static readonly HashSet<string> ModiconInstructions = new(StringComparer.OrdinalIgnoreCase)
        {
            "LD", "LDI", "AND", "ANI", "OR", "ORI", "OUT",
            "SET", "RST", "PLS", "PLF", "MPS", "MRD", "MPP",
            "MC", "MCR", "NOP", "END"
        };

        // Note: Some A-B/Modicon names collide with Siemens (TON, TOF, CTU, CTD, ADD, SUB, MUL, DIV, AND, OR, SET).
        // The vendor check only fires when the instruction is NOT in our known-Siemens set,
        // so a Siemens-valid "TON" won't be flagged.

        // ── ALL-CAPS instruction detection (Siemens S7DCL uses PascalCase) ──
        private static readonly Regex AllCapsInstructionRegex = new(
            @"\b(MOVE|ADD_?AUTO|SUB_?AUTO|MUL_?AUTO|DIV_?AUTO|NEG_?AUTO|CONVERT|CALCULATE|SELECT|LIMIT_|MUX_)\s*\(",
            RegexOptions.Compiled);

        // ── SCL-in-LAD trap: SCL patterns inside LAD networks ──
        private static readonly Regex SclAssignmentInLadRegex = new(
            @"#\w+\s*:=\s*", RegexOptions.Compiled);  // #Var := ... (SCL assignment, not valid in LAD RUNG)

        private static readonly Regex SclIfInLadRegex = new(
            @"\b(IF|THEN|ELSE|ELSIF|END_IF|FOR|WHILE|DO|END_FOR|END_WHILE|CASE|OF|END_CASE|RETURN|EXIT|CONTINUE)\b",
            RegexOptions.Compiled);

        private static readonly Regex SclCommentInLadRegex = new(
            @"//[^\n]*", RegexOptions.Compiled);  // // comment (SCL style, not valid in LAD)

        private static readonly Regex SclBeginInLadRegex = new(
            @"\bBEGIN\b", RegexOptions.Compiled);  // BEGIN...END_FUNCTION (SCL body, not LAD)

        static S7dclDocumentValidator()
        {
            AllKnownInstructions = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            AllKnownInstructions.UnionWith(KnownContacts);
            AllKnownInstructions.UnionWith(KnownCoils);
            AllKnownInstructions.UnionWith(KnownZeroOpCoils);
            AllKnownInstructions.UnionWith(KnownBoxes);
        }

        public static JsonObject Validate(string directoryOrFilePath)
        {
            var result = new JsonObject
            {
                ["format"] = "tia-s7dcl-document-validation-offline-v1",
                ["timestamp"] = DateTime.Now.ToString("O"),
                ["offlineOnly"] = true,
                ["inputPath"] = directoryOrFilePath
            };

            var checks = new JsonArray();
            var errors = new List<string>();
            var warnings = new List<string>();
            int errorCount = 0, warnCount = 0, passCount = 0;

            void AddCheck(string level, string status, string detail)
            {
                checks.Add(new JsonObject
                {
                    ["level"] = level,
                    ["status"] = status,
                    ["detail"] = detail
                });
                if (status == "fail") { errorCount++; errors.Add($"[{level}] {detail}"); }
                else if (status == "warn") { warnCount++; warnings.Add($"[{level}] {detail}"); }
                else passCount++;
            }

            // ── Resolve file list ──
            var s7dclFiles = new List<string>();
            var s7resFiles = new List<string>();

            if (Directory.Exists(directoryOrFilePath))
            {
                s7dclFiles.AddRange(Directory.GetFiles(directoryOrFilePath, "*.s7dcl", SearchOption.TopDirectoryOnly));
                s7resFiles.AddRange(Directory.GetFiles(directoryOrFilePath, "*.s7res", SearchOption.TopDirectoryOnly));
            }
            else if (File.Exists(directoryOrFilePath))
            {
                var ext = Path.GetExtension(directoryOrFilePath).ToLowerInvariant();
                if (ext == ".s7dcl") s7dclFiles.Add(directoryOrFilePath);
                else if (ext == ".s7res") s7resFiles.Add(directoryOrFilePath);
                else { AddCheck("input", "fail", $"Unknown file extension: {ext}. Expected .s7dcl or .s7res."); }
            }
            else
            {
                AddCheck("input", "fail", $"Path not found: {directoryOrFilePath}");
                result["ok"] = false;
                result["checks"] = checks;
                result["errorCount"] = errorCount;
                result["warnCount"] = warnCount;
                result["passCount"] = passCount;
                result["errors"] = new JsonArray(errors.Select(e => (JsonNode)e!).ToArray());
                result["warnings"] = new JsonArray(warnings.Select(w => (JsonNode)w!).ToArray());
                return result;
            }

            // ── File-pair matching ──
            var pairs = new Dictionary<string, (string? s7dcl, string? s7res)>(StringComparer.OrdinalIgnoreCase);
            foreach (var f in s7dclFiles)
            {
                var baseName = Path.GetFileNameWithoutExtension(f);
                if (!pairs.ContainsKey(baseName)) pairs[baseName] = (null, null);
                pairs[baseName] = (f, pairs[baseName].s7res);
            }
            foreach (var f in s7resFiles)
            {
                var baseName = Path.GetFileNameWithoutExtension(f);
                if (!pairs.ContainsKey(baseName)) pairs[baseName] = (null, null);
                pairs[baseName] = (pairs[baseName].s7dcl, f);
            }

            if (pairs.Count == 0)
            {
                AddCheck("files", "fail", "No .s7dcl or .s7res files found.");
                result["ok"] = false;
                result["checks"] = checks;
                result["errorCount"] = errorCount;
                result["warnCount"] = warnCount;
                result["passCount"] = passCount;
                return result;
            }

            result["fileCount"] = pairs.Count;

            foreach (var kvp in pairs)
            {
                var baseName = kvp.Key;
                var (s7dclPath, s7resPath) = kvp.Value;

                // .s7res without .s7dcl is always an error
                if (s7dclPath == null)
                {
                    AddCheck("files", "fail", $"{baseName}: .s7res found but .s7dcl is missing.");
                    continue;
                }

                string? s7dclContent = null;
                string? s7resContent = null;

                // ── UTF-8 BOM check ──
                // TIA-exported reference files do NOT carry BOM; we report status neutrally
                s7dclContent = CheckBom(s7dclPath, baseName, ".s7dcl", AddCheck);

                if (s7dclContent == null) continue;

                // ── Check if .s7dcl contains MLC references ──
                var mlcIdsInDcl = new HashSet<string>();
                foreach (Match m in MlcRefRegex.Matches(s7dclContent))
                    mlcIdsInDcl.Add(m.Value);
                bool dclHasMlc = mlcIdsInDcl.Count > 0;

                // .s7res only required if .s7dcl has MLC (matches TIA export behavior)
                if (s7resPath == null)
                {
                    if (dclHasMlc)
                        AddCheck("files", "fail", $"{baseName}: .s7dcl has {mlcIdsInDcl.Count} MLC references but .s7res is missing.");
                    else
                        AddCheck("files", "pass", $"{baseName}: No .s7res needed (no MLC in .s7dcl, matches TIA export).");
                    continue;
                }

                s7resContent = CheckBom(s7resPath, baseName, ".s7res", AddCheck);
                if (s7resContent == null) continue;

                // ── Block declaration ──
                var blockMatch = BlockDeclRegex.Match(s7dclContent);
                if (!blockMatch.Success)
                    AddCheck("block", "fail", $"{baseName}: No FUNCTION/FUNCTION_BLOCK/ORGANIZATION_BLOCK declaration found.");
                else
                {
                    var blockType = blockMatch.Groups[1].Value;
                    var blockName = blockMatch.Groups[2].Value;
                    AddCheck("block", "pass", $"{baseName}: {blockType} \"{blockName}\" declared.");

                    // ── Timer in FC Temp check (only applies to FUNCTION, not FUNCTION_BLOCK) ──
                    if (blockType == "FUNCTION" && (s7dclContent.Contains("TON_TIME") || s7dclContent.Contains("TON(") || s7dclContent.Contains("TONR")))
                        AddCheck("block", "warn", $"{baseName}: FC \"{blockName}\" uses TON/TONR/TON_TIME — must be in FB VAR (Static). (陷阱#2)");
                }

                // ── Parse .s7res for MLC entries ──
                var mlcIdsInRes = new Dictionary<string, bool>(); // id → hasZhCn
                var currentId = "";
                var hasZhCn = false;
                foreach (var line in s7resContent.Split('\n'))
                {
                    var idMatch = S7resEntryRegex.Match(line);
                    if (idMatch.Success)
                    {
                        if (!string.IsNullOrEmpty(currentId))
                            mlcIdsInRes[currentId] = hasZhCn;
                        currentId = idMatch.Groups[1].Value;
                        hasZhCn = false;
                    }
                    if (ZhCnRegex.IsMatch(line)) hasZhCn = true;
                }
                if (!string.IsNullOrEmpty(currentId))
                    mlcIdsInRes[currentId] = hasZhCn;

                // ── MLC cross-reference ──
                if (mlcIdsInDcl.Count == 0)
                    AddCheck("mlc", "warn", $"{baseName}: No MLC_xxx references found in .s7dcl.");
                else
                {
                    var missingInRes = new List<string>();
                    var missingZhCn = new List<string>();
                    foreach (var mlc in mlcIdsInDcl)
                    {
                        if (!mlcIdsInRes.ContainsKey(mlc))
                            missingInRes.Add(mlc);
                        else if (!mlcIdsInRes[mlc])
                            missingZhCn.Add(mlc);
                    }
                    if (missingInRes.Count > 0)
                        AddCheck("mlc", "fail", $"{baseName}: {missingInRes.Count} MLC IDs referenced in .s7dcl but missing from .s7res: {string.Join(", ", missingInRes.Take(10))}{(missingInRes.Count > 10 ? "..." : "")}");
                    if (missingZhCn.Count > 0)
                        AddCheck("mlc", "fail", $"{baseName}: {missingZhCn.Count} MLC entries missing zh-CN in .s7res: {string.Join(", ", missingZhCn.Take(10))}{(missingZhCn.Count > 10 ? "..." : "")}");
                    if (missingInRes.Count == 0 && missingZhCn.Count == 0)
                        AddCheck("mlc", "pass", $"{baseName}: All {mlcIdsInDcl.Count} MLC references resolved in .s7res with zh-CN.");
                }

                // ── Detect orphan MLC IDs in .s7res (not referenced in .s7dcl) ──
                var orphanMlcs = mlcIdsInRes.Keys.Except(mlcIdsInDcl).ToList();
                if (orphanMlcs.Count > 0)
                    AddCheck("mlc", "warn", $"{baseName}: {orphanMlcs.Count} MLC IDs in .s7res not referenced in .s7dcl: {string.Join(", ", orphanMlcs.Take(5))}{(orphanMlcs.Count > 5 ? "..." : "")}");

                // ── Per-network checks ──
                var networks = SplitNetworks(s7dclContent);
                AddCheck("network", "pass", $"{baseName}: {networks.Count} network(s) found.");

                for (int ni = 0; ni < networks.Count; ni++)
                {
                    var netContent = networks[ni];
                    var netLabel = $"N{ni + 1}";

                    // S7_Language pragma
                    if (!NetworkPragmaRegex.IsMatch(netContent))
                        AddCheck("network", "warn", $"{baseName}:{netLabel}: Missing {{ S7_Language := \"LAD\" }} pragma. (陷阱#8)");

                    // Wire consistency (non-powerrail)
                    var allWires = WireRefRegex.Matches(netContent).Cast<Match>()
                        .Select(m => m.Value)
                        .Where(w => !WirePowerrailRegex.IsMatch(w))
                        .Distinct()
                        .ToList();

                    var wireSources = new HashSet<string>();
                    var wireTargets = new HashSet<string>();
                    foreach (var wire in allWires)
                    {
                        // wire#xxx on its own line → source (definition)
                        if (Regex.IsMatch(netContent, $@"^\s*{Regex.Escape(wire)}\s*$", RegexOptions.Multiline))
                            wireSources.Add(wire);
                        // wire#xxx at end of a RUNG line → target (consumer)
                        if (Regex.IsMatch(netContent, $@"END_RUNG\s+{Regex.Escape(wire)}\s*$", RegexOptions.Multiline))
                            wireTargets.Add(wire);
                    }
                    foreach (var wire in allWires)
                    {
                        if (wireSources.Contains(wire) && !wireTargets.Contains(wire))
                            AddCheck("wire", "warn", $"{baseName}:{netLabel}: wire {wire} defined but never consumed.");
                    }
                    foreach (var wire in allWires)
                    {
                        if (wireTargets.Contains(wire) && !wireSources.Contains(wire))
                            AddCheck("wire", "fail", $"{baseName}:{netLabel}: wire {wire} consumed but never defined.");
                    }

                    // Jump/return count per network
                    var jumpReturnCount = JumpReturnRegex.Matches(netContent).Count;
                    if (jumpReturnCount > 1)
                        AddCheck("network", "fail", $"{baseName}:{netLabel}: {jumpReturnCount} jump/return instructions — max 1 per network. (陷阱#5)");

                    // ── Instruction validation ──
                    foreach (Match m in InstructionRegex.Matches(netContent))
                    {
                        var instr = m.Groups[1].Value;
                        // Skip known non-instructions
                        if (instr == "RUNG" || instr == "END_RUNG" || instr == "END_NETWORK" ||
                            instr == "NETWORK" || instr == "VAR" || instr == "END_VAR")
                            continue;

                        // ── Vendor confusion trap (陷阱#32) ──
                        if (AllenBradleyInstructions.Contains(instr) && !AllKnownInstructions.Contains(instr))
                            AddCheck("vendor", "fail", $"{baseName}:{netLabel}: '{instr}' is Allen-Bradley/Rockwell RSLogix syntax — NOT valid Siemens S7DCL! 正确: Contact/I_Contact/Coil/S_Coil/R_Coil/P_Trig. (陷阱#32-AB)");
                        if (ModiconInstructions.Contains(instr) && !AllKnownInstructions.Contains(instr))
                            AddCheck("vendor", "fail", $"{baseName}:{netLabel}: '{instr}' is Modicon/Mitsubishi syntax — NOT valid Siemens S7DCL! (陷阱#32-MOD)");

                        if (!AllKnownInstructions.Contains(instr) && !KnownZeroOpCoils.Contains(instr))
                            AddCheck("instr", "warn", $"{baseName}:{netLabel}: Unknown instruction '{instr}' — verify syntax or export real block with ExportBlocksAsDocuments. (陷阱#9)");
                    }

                    // ── ALL-CAPS instruction trap (陷阱#33) ──
                    var allCapsMatch = AllCapsInstructionRegex.Match(netContent);
                    if (allCapsMatch.Success)
                        AddCheck("instr", "fail", $"{baseName}:{netLabel}: '{allCapsMatch.Groups[1].Value}' is ALL-CAPS — Siemens S7DCL uses PascalCase (Move/Add/Sub, NOT MOVE/ADD/SUB). (陷阱#33)");

                    // ── SCL-in-LAD detection (陷阱#34-#37) ──
                    // Only check in LAD networks (not SCL)
                    var isSclNetwork = Regex.IsMatch(netContent, @"S7_Language\s*:=\s*""SCL""");
                    if (!isSclNetwork)
                    {
                        if (SclAssignmentInLadRegex.IsMatch(netContent))
                            AddCheck("scl-in-lad", "fail", $"{baseName}:{netLabel}: SCL assignment ':=' found in LAD network — use RUNG/END_RUNG with Contact/Coil/Box instead. (陷阱#34)");
                        if (SclIfInLadRegex.IsMatch(netContent))
                            AddCheck("scl-in-lad", "fail", $"{baseName}:{netLabel}: SCL control flow (IF/FOR/WHILE/CASE/RETURN) found in LAD network — use {{ S7_Language := \"SCL\" }} network instead. (陷阱#35)");
                        if (SclCommentInLadRegex.IsMatch(netContent))
                            AddCheck("scl-in-lad", "fail", $"{baseName}:{netLabel}: SCL-style comment '//' found in LAD network — use MLC for comments, not //. (陷阱#36)");
                    }

                    // ── Trap #1: Contact → wire# → Box ──
                    if (ContactThenWireThenBoxRegex.IsMatch(netContent))
                        AddCheck("trap", "warn", $"{baseName}:{netLabel}: Possible Contact→wire#→Box pattern — wire# between Contact and Box may break EN connection. (陷阱#1)");

                    // ── Trap #19/20: Negated() / Not() at RUNG start ──
                    if (Regex.IsMatch(netContent, @"Negated\s*\("))
                        AddCheck("trap", "fail", $"{baseName}:{netLabel}: Negated() does not exist in S7DCL — use I_Contact or Contact→Not. (陷阱#19)");
                    if (Regex.IsMatch(netContent, @"RUNG\s+wire#powerrail\s*\n\s*Not\s*\("))
                        AddCheck("trap", "fail", $"{baseName}:{netLabel}: Not() at RUNG start — LAD requires preceding Contact. (陷阱#20)");
                }
            }

            var ok = errorCount == 0;
            result["ok"] = ok;
            result["checks"] = checks;
            result["errorCount"] = errorCount;
            result["warnCount"] = warnCount;
            result["passCount"] = passCount;
            result["errors"] = new JsonArray(errors.Select(e => (JsonNode)e!).ToArray());
            result["warnings"] = new JsonArray(warnings.Select(w => (JsonNode)w!).ToArray());
            result["message"] = ok
                ? $"S7DCL validation passed: {passCount} checks ok, {warnCount} warnings."
                : $"S7DCL validation found {errorCount} error(s), {warnCount} warning(s). Fix errors and re-run.";

            return result;
        }

        private static string? CheckBom(string path, string baseName, string ext, Action<string, string, string> addCheck)
        {
            try
            {
                var bytes = File.ReadAllBytes(path);
                bool hasBom = bytes.Length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF;
                if (hasBom)
                {
                    // Match TIA export behavior: BOM is NOT required, but present is fine
                    addCheck("file", "pass", $"{baseName}{ext}: UTF-8 BOM present (TIA exports without BOM — both accepted).");
                    return Encoding.UTF8.GetString(bytes, 3, bytes.Length - 3);
                }
                addCheck("file", "pass", $"{baseName}{ext}: UTF-8 without BOM (matches TIA export format).");
                return Encoding.UTF8.GetString(bytes);
            }
            catch (Exception ex)
            {
                addCheck("file", "fail", $"{baseName}{ext}: Cannot read file: {ex.Message}");
                return null;
            }
        }

        /// <summary>Split .s7dcl body into individual network blocks.</summary>
        private static List<string> SplitNetworks(string content)
        {
            var networks = new List<string>();
            var matches = NetworkKeywordRegex.Matches(content);
            for (int i = 0; i < matches.Count; i++)
            {
                var startIdx = matches[i].Index;
                var endIdx = (i + 1 < matches.Count) ? matches[i + 1].Index : content.Length;
                // Walk back to include the { S7_Language ... } pragma block before NETWORK
                // Use regex to match both single-line and multi-line pragmas
                var segStart = startIdx;
                var before = content.Substring(0, startIdx);
                var pragmaMatch = NetworkPragmaRegex.Match(before);
                // Find the LAST pragma before this NETWORK (closest one)
                var lastPragmaIdx = -1;
                var pragmaRegex = new Regex(@"\{\s*S7_Language\s*:=\s*""(LAD|SCL|FBD|STL)""", RegexOptions.RightToLeft);
                var lastPragma = pragmaRegex.Match(before);
                if (lastPragma.Success)
                {
                    lastPragmaIdx = lastPragma.Index;
                    // Verify the pragma is reasonably close (within 300 chars for multi-line)
                    if (startIdx - lastPragmaIdx < 300)
                        segStart = lastPragmaIdx;
                }
                networks.Add(content.Substring(segStart, Math.Min(endIdx - segStart, content.Length - segStart)));
            }
            return networks;
        }
    }
}
