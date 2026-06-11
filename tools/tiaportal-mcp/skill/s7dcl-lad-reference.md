# SIMATIC SD (.s7dcl) LAD — 生产级参考手册

> 基于西门子官方规范 Entry ID: **109994073** (V1.0, 09/2025)，每行语法均来自官方 Listing 案例。
> 配套本地样本：`skill/lad-cookbook/*.s7dcl` + `*.s7res`（已验证 TIA V21 往返导入，errorCount=0）

---

## 零、官方文档索引

| 文档 | ID | 获取方式 |
|------|-----|---------|
| SIMATIC Source Documents LADDER Format Description | `109994073` | support.industry.siemens.com |
| Creating and Managing Blocks §1.5 | — | docs.tia.siemens.cloud |
| SimaticSDEnabler User Guide | — | 本仓库 `docs/DS文件收集/` |
| 博途 V21 DS 文件格式中文说明 | — | 本仓库 `docs/DS文件收集/` |

---

## 一、文件对（UTF-8 with BOM）

| 文件 | 内容 |
|------|------|
| `Name.s7dcl` | 块声明 + 网络代码 |
| `Name.s7res` | `MLC_*` → 多语言文本（含 `zh-CN` 和 `en-US`） |

导入: `ImportBlocksFromDocuments(softwarePath, groupPath="", importPath=目录)` 或 `ImportFromDocuments(softwarePath, groupPath, importPath=目录, fileNameWithoutExtension=Name)`

---

## 二、块模板

### 2.1 FC (函数)
```
{
    S7_BlockComment := "MLC_xxx";
    S7_BlockNumber := "901";
    S7_BlockTitle := "MLC_xxx";
    S7_Optimized := "TRUE";
    S7_PreferredLanguage := "LAD";
    S7_Version := "0.1"
}
FUNCTION "FC_Name" : Void
    VAR_INPUT   "A" : Bool;  "Val" : Int;  END_VAR
    VAR_OUTPUT  "Out" : Bool;  "Result" : Int;  END_VAR
    VAR_TEMP    "tmp" : Bool;  END_VAR

    { S7_Language := "LAD"; S7_NetworkComment := "MLC_xxx"; S7_NetworkTitle := "MLC_xxx" }
    NETWORK
        RUNG wire#powerrail
            Contact( #"A" )
            Coil( #Out )
        END_RUNG
    END_NETWORK
END_FUNCTION
```

### 2.2 FB (函数块)
比 FC 多 `VAR` (Static) 区——定时器/计数器实例必须放这里。
```
FUNCTION_BLOCK "FB_Name"
    VAR_INPUT   "Trig" : Bool;  END_VAR
    VAR_OUTPUT  "Q" : Bool;  END_VAR
    VAR         "tonInst" : TON_TIME;  END_VAR     ← Static
    VAR_TEMP    "edge" : Bool;  END_VAR

    { S7_Language := "LAD" }
    NETWORK
        RUNG wire#powerrail
            Contact( #Trig )
            { S7_Templates := "timeType := Time" }
            #tonInst.TON( pt := T#2s, et => )
            Coil( #Q )
        END_RUNG
    END_NETWORK
END_FUNCTION_BLOCK
```

### 2.3 OB (组织块)
```
{
    S7_Optimized := "TRUE";
    S7_PreferredLanguage := "LAD";
    S7_Version := "0.1"
}
ORGANIZATION_BLOCK "Main"
    { S7_Language := "LAD" }
    NETWORK
        RUNG wire#powerrail
            ...instructions...
        END_RUNG
    END_NETWORK
END_ORGANIZATION_BLOCK
```

### 2.4 SCL 网络（混合 LAD/SCL 块）
```
    { S7_Language := "SCL" }
    NETWORK
          #Out := #In1 AND #In2;
          IF #Enable THEN #Result := #Value; END_IF;
    END_NETWORK
```

---

## 二点五、模板（Template）分类速查 — 导入前必读！

不同指令家族使用**不同的模板名称**。用错是导入失败的首要原因（Claude Code 实测 13 错误中 4 个源于此）。

| 指令家族 | 模板名 | 示例 | 说明 |
|----------|--------|------|------|
| 四则运算 Add/Sub/Mul/Div/Mod | `SrcType` | `{ S7_Templates := "SrcType := Int" }` | TIA 接受 |
| 比较触点 GT/LT/EQ/NE/GE/LE_Contact | `SrcType` | `{ S7_Templates := "SrcType := Int" }` | TIA 接受 |
| 比较盒 GT/LT/EQ/NE/GE/LE (box型) | `SrcType` | `{ S7_Templates := "SrcType := Int" }` | ⚠️ out=> 输出；非 CMP！ |
| IEC 定时器 TON/TOF/TP/TONR | `time_type` | `{ S7_Templates := "time_type := Time" }` | ⚠️ 下划线，非驼峰！TIA V21 实测 |
| IEC 计数器 Ctu/Ctd/Ctud | `value_type` | `{ S7_Templates := "value_type := Int" }` | ⚠️ 非 countType！TIA V21 实测 |
| Convert | Array | `{ S7_Templates := "[SrcType := Int, DestType := Real]" }` | ⚠️ SrcType/DestType 非 inType/outType！ |
| Calculate | `SrcType` | `{ S7_Templates := "SrcType := Real" }` | |
| 选择器 MIN/MAX/LIMIT/SEL | `value_type` | `{ S7_Templates := "value_type := Int" }` | **⚠️ 不是 SrcType！** |
| MUX | `SrcType` | `{ S7_Templates := "SrcType := Int" }` | ⚠️ MUX 用 SrcType（非 value_type！TIA V21 实测） |
| 字逻辑 AND/OR/XOR/INV | **不需要** | 不加模板 pragma | 类型自动推导 |
| 移位 SHR/SHL/ROR/ROL | `SrcType` | `{ S7_Templates := "SrcType := DWord" }` | ⚠️ 非模板豁免！TIA V21 实测 |
| CMP >= / <= / <> | **不需要** | 不加模板 pragma | 加模板反而报错！ |
| JMP/LABEL/RET | — | **S7DCL 导入不支持** | TIA 直接拒绝 |
| 取反 NEG | `SrcType` | `{ S7_Templates := "SrcType := Real" }` | ⚠️ 非模板豁免；引脚 `in` 非 `in1` |
| IEC 计数器 (SCL) | N/A | `#inst.CTU(CU:=#, R:=#, PV:=#, Q=>#, CV=>#)` | LAD 不支持计数器输入引脚 inline 赋值 |

> **根源**: PDF Listing 17 用 `SrcType`，Listing 22 用 `valueType`——官方文档自身不一致。MUX 实测用 SrcType（非 value_type），其余选择器用 value_type。上表来自 TIA V21 实际导入验证（2026-06-10），已用参考程序 `程序语法格式参考(博图编译通过0错误).s7dcl` 二次确认。

---

## 三、指令全集（按官方案例逐条验证）

> 格式说明: `Contact( x )` — 单操作数触点，操作数内联。多操作数指令分行列出所有参数。

### 3.1 触点 Contacts

| 指令 | 操作数 | 语义 | 语法 |
|------|--------|------|------|
| `Contact` | 1 | `out := in AND a` | `Contact( a )` |
| `I_Contact` | 1 | `out := in AND NOT a` | `I_Contact( a )` |
| `P_Contact` | 2 | 上升沿检测 | `P_Contact( operand:=sig, bit:=store )` **bit 必需** |
| `N_Contact` | 2 | 下降沿检测 | `N_Contact( operand:=sig, bit:=store )` **bit 必需** |
| `P_Trig` | 1 | 上升沿检测（Box型） | `P_Trig( #edge_mem )` — 沿存储 Bool，单操作数 |
| `N_Trig` | 1 | 下降沿检测（Box型） | `N_Trig( #edge_mem )` — 沿存储 Bool，单操作数 |
| `GT_Contact` | 2 | `in1 > in2` | `{SrcType:=Int} GT_Contact(in1:=#A, in2:=100)` |
| `LT_Contact` | 2 | `in1 < in2` | `{SrcType:=Int} LT_Contact(in1:=#A, in2:=0)` |
| `EQ_Contact` | 2 | `in1 == in2` | `{SrcType:=Int} EQ_Contact(in1:=#X, in2:=#Y)` |
| `NE_Contact` | 2 | `in1 <> in2` | `{SrcType:=Int} NE_Contact(in1:=#X, in2:=0)` |
| `GE_Contact` | 2 | `in1 >= in2` | `{SrcType:=Int} GE_Contact(in1:=#V, in2:=#Limit)` |
| `LE_Contact` | 2 | `in1 <= in2` | `{SrcType:=Int} LE_Contact(in1:=#V, in2:=#Max)` |
| `CMP >=` | 2 | `in1 >= in2` (box型) | ⚠️ **不存在!** 改用 `GT(in1:=, in2:=, out=>)` 见 §3.4 |
| `CMP <=` | 2 | `in1 <= in2` (box型) | ⚠️ **不存在!** 改用 `LT(in1:=, in2:=, out=>)` 见 §3.4 |
| `CMP <>` | 2 | `in1 <> in2` (box型) | ⚠️ **不存在!** 改用 `NE(in1:=, in2:=, out=>)` 见 §3.4 |
| `CMP ==` | 2 | `in1 == in2` (box型) | ⚠️ **不存在!** 改用 `EQ(in1:=, in2:=, out=>)` 见 §3.4 |
| `IsValidContact` | 1 | 检查浮点有效性 | `IsValidContact( x )` |
| `IsNotValidContact` | 1 | 检查浮点无效 | `IsNotValidContact( x )` |
| `IsArrayContact` | 1 | 检查 Variant 是否含数组 | `IsArrayContact( x )` |
| `IsNotArrayContact` | 1 | 检查 Variant 是否无数组 | `IsNotArrayContact( x )` |
| `IsNullContact` | 1 | 检查引用类型是否为 Null | `IsNullContact( x )` |
| `IsNotNullContact` | 1 | 检查引用类型是否非 Null | `IsNotNullContact( x )` |
| `EQ_TypeContact` | 2 | 比较数据类型 | `EQ_TypeContact(in1:=, in2:=)` |
| `NE_TypeContact` | 2 | 比较数据类型 | `NE_TypeContact(in1:=, in2:=)` |
| `EQ_ElemTypeContact` | 2 | 比较数组元素类型 | `EQ_ElemTypeContact(in1:=, in2:=)` |
| `NE_ElemTypeContact` | 2 | 比较数组元素类型 | `NE_ElemTypeContact(in1:=, in2:=)` |
| `EQ_TypeOfDBContact` | 2 | 比较 DB 类型 | `EQ_TypeOfDBContact(in1:=, in2:=)` |
| `NE_TypeOfDBContact` | 2 | 比较 DB 类型 | `NE_TypeOfDBContact(in1:=, in2:=)` |
| 标志触点 | 0 | AS300/400 状态字 | 见 §A.1 附录——共 19 个遗留标志触点 |

### 3.2 线圈 Coils

| 指令 | 操作数 | 语义 | 语法 |
|------|--------|------|------|
| `Coil` | 1 | `x := in` | `Coil( x )` |
| `I_Coil` | 1 | `x := NOT in` | `I_Coil( x )` |
| `S_Coil` | 1 | `IF in THEN x:=TRUE` | `S_Coil( x )` |
| `R_Coil` | 1 | `IF in THEN x:=FALSE` | `R_Coil( x )` |
| `P_Coil` | 2 | 上升沿触发 | `P_Coil( operand:=out, bit:=store )` |
| `N_Coil` | 2 | 下降沿触发 | `N_Coil( operand:=out, bit:=store )` |
| `TP_Coil` | 2 | 启动脉冲定时器 | `TP_Coil( timer:=#inst, pt:=T#1s )` |
| `TOn_Coil` | 2 | 启动接通延时 | `TOn_Coil( timer:=#inst, pt:=T#500ms )` |
| `TOf_Coil` | 2 | 启动断开延时 | `TOf_Coil( timer:=#inst, pt:=T#2s )` |
| `TOnr_Coil` | 2 | 启动累积延时 | `TOnr_Coil( timer:=#inst, pt:=T#3s )` |
| `SP_Coil` | 2 | Simatic 脉冲 | `SP_Coil( timer:=#inst, pt:=S5T#1s )` |
| `SE_Coil` | 2 | Simatic 扩展脉冲 | `SE_Coil( timer:=#inst, pt:=S5T#1s )` |
| `SD_Coil` | 2 | Simatic 接通延时 | `SD_Coil( timer:=#inst, pt:=S5T#1s )` |
| `SS_Coil` | 2 | Simatic 保持延时 | `SS_Coil( timer:=#inst, pt:=S5T#1s )` |
| `SF_Coil` | 2 | Simatic 断开延时 | `SF_Coil( timer:=#inst, pt:=S5T#1s )` |
| `PT_Coil` | 2 | 运行时改延时 | `PT_Coil( timer:=#inst, pt:=T#5s )` |
| `RT_Coil` | 1 | 复位定时器 | `RT_Coil( #inst )` |
| `CU_Coil` | 1 | 加计数 | `CU_Coil( counter )` |
| `CD_Coil` | 1 | 减计数 | `CD_Coil( counter )` |
| `SC_Coil` | 2 | 预置计数值 | `SC_Coil( counter:=#ctr, pv:=C#100 )` |
| `R_BitfieldCoil` | 2 | 复位 n 个连续 Bool 位 | `R_BitfieldCoil( operand:=addr, n:=count )` |
| `S_BitfieldCoil` | 2 | 置位 n 个连续 Bool 位 | `S_BitfieldCoil( operand:=addr, n:=count )` |
| `JumpCoil` | 1 | 条件跳转(真) | `JumpCoil( label )` |
| `I_JumpCoil` | 1 | 条件跳转(假) | `I_JumpCoil( label )` |
| `ReturnCoil` | 1 | 返回+ENO | `ReturnCoil( x )` |
| `ReturnFalse` | 0 | 返回 ENO=false | `ReturnFalse()` |
| `ReturnTrue` | 0 | 返回 ENO=true | `ReturnTrue()` |
| `Return` | 0 | 返回 ENO=rung-in | `Return()` |
| `CallCoil` | 1 | 以线圈形式调用块 | `CallCoil( blockName )` |
| 零操作数线圈 | 0 | AS300/400 MCR/SAVE | 见 §A.2 附录——共 5 个遗留线圈 |

### 3.3 否定
```
Not()           out := NOT in
```

### 3.4 ENO-Boxes (数学/转换/调用)

#### 数学运算

**比较盒 (Comparison Boxes) — ⚠️ 非 CMP，直接用指令名！**
```                                    
{ S7_Templates := \"SrcType := Int\" }
GT( in1 := #V1, in2 := #V2, out => #OUT_GTb )     ← 大于，输出到 out
LT( in1 := #V1, in2 := #V2, out => #OUT_LTb )     ← 小于
EQ( in1 := #V1, in2 := #V2, out => #OUT_EQb )     ← 等于
NE( in1 := #V1, in2 := #V2, out => #OUT_NEb )     ← 不等于
GE( in1 := #V1, in2 := #V2, out => #OUT_GEb )     ← 大于等于
LE( in1 := #V1, in2 := #V2, out => #OUT_LEb )     ← 小于等于
```
**注意**: S7DCL 不存在 `CMP >=`/`CMP <=` 等 box 语法！直接用 `GT`/`LT`/`EQ`/`NE`/`GE`/`LE` 作为 box，使用 `out =>` 输出比较结果，需要 `SrcType` 模板。

与比较触点的区别: 触点型用 `GT_Contact(in1:=,in2:=)` + `Coil(#out)`；盒型用 `GT(in1:=,in2:=,out=>#out)`。
```
{ S7_Templates := "SrcType := Int" }     ← 必选(除非 Auto)
Add( in1 := #A, in2 := #B, out => #SUM )
Sub( in1 := #A, in2 := #B, out => #DIFF )
Mul( in1 := #A, in2 := #B, out => #PROD )
Div( in1 := #A, in2 := #B, out => #QUOT )
Mod( in1 := #A, in2 := #B, out => #REM )
```

多输入: `Add(in1:=#A, in2:=#B, in3:=#C, in4:=#D, out=>#SUM)`

#### 传送 & 转换
```
Move( in := 42, out1 => #DST )
{ S7_Templates := "[SrcType := Int, DestType := Real]" }
Convert( in := #X, out => #Y )
```

#### EN/ENO 控制
```
{ S7_GenerateENO := "TRUE" }    ← 开启 ENO 计算（选择器常用）
```
默认关闭时 ENO:=EN，不导出 pragma。

**选择器专用模板（MIN/MAX/LIMIT）：**
```
{
    S7_Templates := "value_type := Real";
    S7_GenerateENO := "TRUE"
}
MIN( in1 := #ioRealA, in2 := #ioRealB, out => #oqMinReal )
MAX( in1 := #ioRealA, in2 := #ioRealB, out => #oqMaxReal )
LIMIT( min := 0, in := #ioIntA, max := 100, out => #oqLimitInt )
```
**引脚命名**: LIMIT 用 `min`/`max`（非 `mn`/`mx`）。TIA V21 实测确认。

#### FC 调用 (官方案例 Listing 25)
```
RUNG wire#powerrail
    Contact( x )
    FC_Name(
        in1 := a,
        in2 := b,
        io1 := c,
        out1 => d
    )
END_RUNG
```

#### FB 调用 (官方案例 Listing 26)
```
RUNG wire#powerrail
    Contact( x )
    instName(
        in1 := a,
        in2 := b,
        io1 := c,
        out1 => d
    )
END_RUNG
```

规则: FC 用函数名，FB 用实例名，均不带引号。Contact 直连调用=EN 输入。**禁止 Contact 和调用之间插入 wire#** — 会切断 EN 连接。

#### Calculate Box (官方案例 Listing 38)
```
{
    S7_Templates := "SrcType := Real";
    S7_Expression := "sqr( sin( in1 )) + sqr( cos( in2 ))"
}
Calculate(
    in1 := a,
    in2 := b,
    out => c
)
```

### 3.5 Q-Boxes (双稳态/定时器/计数器)

#### 双稳态 Flip-Flop (官方案例 Listing 27)
```
RUNG wire#powerrail
    Contact( set )
    c.S_RS( wire#w1 )           ← 第二个输入通过 wire# 汇入
    Coil( q )
END_RUNG
RUNG wire#powerrail
    Contact( reset )
END_RUNG wire#w1
```
`c.S_SR( wire#w1 )` 同理。第二个输入是主导的（Dominant）。

> **TIA V21 导入确认**: 也可使用直接的 SR/RS Box 形式，引脚名为 `operand`（存储位）、`s`（置位）、`r`（复位）：
> ```
> SR( operand := #var, s := #set, r := #reset )
> RS( operand := #var, s := #set, r := #reset )
> ```

#### IEC 定时器 (官方案例 Listing 29)
```
{ S7_Templates := "time_type := Time" }
#inst.TP(  pt := T#10s,  et => #elapsed )
#inst.TON( pt := T#2s,   et => #elapsed )
#inst.TOF( pt := T#1s,   et => #elapsed )
#inst.TONR(pt := T#3s,   et => #elapsed )
```
实例 MUST 在 FB VAR (Static) 中声明: `"inst" : TON_TIME;`

#### IEC 计数器 (官方案例 Listing 30)
```
{ S7_Templates := "value_type := Int" }

#inst.Ctu(  r := #Reset,  pv := #Preset,  cv => #Value )
#inst.Ctd(  ld := #Load,  pv := #Preset,  cv => #Value )
#inst.Ctud( cu := , cd := , r := #Reset, ld := #Load,
            pv := #Preset, qd => , qu => , cv => #Value )
```
注意: IEC 计数器没有对应的线圈形式。

#### Simatic 计数器 Box（兼容 AS300/400）
```
S_Cu(
    cu := #CountUp,
    pv := C#100,
    cv => #Value
)
S_Cd(
    cd := #CountDown,
    pv := C#100,
    cv => #Value
)
S_Cud(
    cu := #CountUp,
    cd := #CountDown,
    pv := C#100,
    cv => #Value
)
```
Simatic 计数器用 BCD 编码预设值（`C#100`），输出 `cv` 为整数，`cv_bcd` 为 BCD 格式。`q` 输出 = `cv > 0`。

### 3.7 计数器 — LAD（边沿触发）+ SCL 双模式

#### LAD 模式（带 P_Trig 边沿触发）— ⚠️ 小写引脚名！

S7DCL LAD 中计数器可通过 P_Trig 边沿触发方式使用，模板为 `value_type := Int`，引脚名**小写**：

```lad
{ S7_Language := "LAD" }
NETWORK
    RUNG wire#powerrail
        Contact( #"Trig" )
        P_Trig( #"EdgeWorkCtu" )
        { S7_Templates := "value_type := Int" }
        #"ctuEdgeInst".CTU(
            r := #"Reset",
            pv := #"PresetValue",
            cv => #"CTU_CV"
        )
        Coil( #"CTU_Q" )
    END_RUNG
END_NETWORK
```

**CTU LAD 规则**: `cu` 引脚由 P_Trig 的能流驱动（不显式赋值），`r` 复位输入，`pv` 预设值，`cv =>` 当前值输出，`Q` 通过 Coil 输出。

```lad
{ S7_Language := "LAD" }
NETWORK
    RUNG wire#powerrail
        Contact( #"Trig" )
        P_Trig( #"EdgeWorkCtd" )
        { S7_Templates := "value_type := Int" }
        #"ctdEdgeInst".CTD(
            ld := #"LoadPv",
            pv := #"PresetValue",
            cv => #"CTD_CV"
        )
        Coil( #"CTD_Q" )
    END_RUNG
END_NETWORK
```

**CTD LAD 规则**: `cd` 由能流驱动，`ld` 加载预设值，`pv` 预设值。

**CTUD LAD 规则**: `cu`/`cd` 由能流驱动（根据 CountDown 输入选方向），`r`/`ld`/`pv`/`qd =>`/`cv =>` 为显式引脚。

> **LAD 计数器引脚命名对照**: LAD 中用**小写** (`r`, `pv`, `cv`, `ld`, `cd`, `qd`)，SCL 中用**大写** (`CU`, `R`, `PV`, `Q`, `CV` 等)。不可混用！

#### SCL 模式（全引脚控制）

```scl
{ S7_Language := "SCL" }
NETWORK
    #"ctuInst".CTU(CU := #"CountUp",
                   R := #"Reset",
                   PV := #"PresetValue",
                   Q => #"CTU_Q",
                   CV => #"CTU_CV");
END_NETWORK
```

```scl
{ S7_Language := "SCL" }
NETWORK
    #"ctdInst".CTD(CD := #"CountDown",
                   LD := #"Load",
                   PV := #"PresetValue",
                   Q => #"CTD_Q",
                   CV => #"CTD_CV");
END_NETWORK
```

```scl
{ S7_Language := "SCL" }
NETWORK
    #"ctudInst".CTUD(CU := #"CountUp",
                     CD := #"CountDown",
                     R := #"Reset",
                     LD := #"Load",
                     PV := #"PresetValue",
                     QU => #"CTUD_QU",
                     QD => #"CTUD_QD",
                     CV => #"CTUD_CV");
END_NETWORK
```

**Static 类型声明**: 分别使用 `CTU_INT`、`CTD_INT`、`CTUD_INT`（非 `IEC_COUNTER`）:

```
VAR
    "ctuInst" : CTU_INT;
    "ctdInst" : CTD_INT;
    "ctudInst" : CTUD_INT;
END_VAR
```

**关键规则**:
- 必须用 `inst.CTU(...)` 方法调用模式（非直接实例调用 `inst(CU:=...)`）
- 所有输入/输出引脚在一个语句内完成（**禁止**分步赋值 `inst.CU := ...; inst(); inst.Q`）
- 输出引脚用 `=>`（非 `:=`）

### 3.8 跳转 & 标签 — ⚠️ S7DCL 导入不支持！

> **TIA V21 验证 (2026-06-10)**: JMP/LABEL/RET

以下语法仅存在于 SD 导出文件中，不可用于导入：

#### Label (官方案例 Listing 31)
```
{ S7_Language := "LAD" }
NETWORK
    Label( here )              ← 必须紧跟 NETWORK
    RUNG wire#powerrail ...
END_NETWORK
```

#### Jump (官方案例 Listing 32)
```
JumpCoil( here )        if rung-in true, jump
I_JumpCoil( here )      if rung-in false, jump
```
必须为 RUNG 最后指令。每网络最多 1 个跳转。

#### JumpList (官方案例 Listing 35)
```
RUNG wire#powerrail
    Contact( a )
    JumpList(
        k := b,
        dest0 => label0,
        dest1 => label1,
        dest2 => label2
    )
END_RUNG
```

#### Switch (官方案例 Listing 36)
```
RUNG wire#powerrail
    Contact( a )
    Switch(
        k := b,
        EQ c => label0,
        LT d => label1,
        NE e => label2,
        else => label_else
    )
END_RUNG
```
关系: `EQ NE LT GT LE GE`. 第一个匹配获胜。

---

## 四、并联分支 (官方案例 Listing 14)

```
NETWORK
    RUNG wire#powerrail
        Contact( a )
        wire#w1
        Coil( x )
    END_RUNG
    RUNG wire#powerrail
        Contact( b )
    END_RUNG wire#w1
    RUNG wire#powerrail
        Contact( c )
    END_RUNG wire#w1
END_NETWORK
```
等价 SCL: `x := a OR b OR c;`

---

## 五、变量引用

| 目标 | 语法 | 说明 |
|------|------|------|
| 块接口变量 | `#VarName` 或 `#\"VarName\"` | Input/Output/InOut |
| 静态变量 | `#VarName` | FB VAR 区 |
| 临时变量 | `#VarName` | VAR_TEMP 区 |
| 全局 DB 成员 | `\"DB_Name\".Member` | 双引号包裹 DB 名 |
| 字位访问 | `\"WordVar\".%X0` | 第 0 位 |
| Wire 标识 | `wire#name` | 网络级作用域 |
| 左母线 | `wire#powerrail` | 预定义 |

---

## 六、.s7res 格式

```
MultiLingualTexts:
  - id: MLC_548
    zh-CN: 块注释
    en-US: Block comment
  - id: MLC_3fA
    zh-CN: N1-串联
    en-US: N1-Series
```

每个 `MLC_*` 必须在 .s7res 中有对应条目。**务必同时提供 `zh-CN` 和 `en-US`**，否则 LAD 导入可能失败。

**⚠️ .s7res 必须精确定义**: .s7res 中不能有多余的 MLC 条目——只保留 .s7dcl 中实际引用的 MLC ID。多余的 MLC ID（例如从模板复制遗留的、旧网络删除后未清理的）会导致导入错误。修改 .s7dcl 时必须同步清理 .s7res。

---

## 七、陷阱速查

| # | 问题 | 症状 | 正确做法 |
|---|------|------|----------|
| 1 | **Contact 和 Box 间插入 wire#** | `Pin 'en' connection is missing` | Contact 直连 Box |
| 2 | **定时器放 FC Temp** | 编译报错 | FB Static (`TON_TIME`) |
| 3 | **缺少 UTF-8 BOM** | 导入乱码/失败 | 两文件都带 BOM |
| 4 | **MLC_ID 不匹配** | 导入失败 | 逐条核对 .s7res |
| 5 | **超过 1 个跳转/网络** | 语义歧义 | 拆分网络 |
| 6 | **FC 调用用了实例名** | 未找到块 | FC 用函数名 |
| 7 | **.s7res 缺 en-US** | LAD 导入失败 | 加 `en-US:` 行 |
| 8 | **忘写 `S7_Language`** | 网络无效 | 每个 NETWORK 前加 pragma |
| 9 | **猜测未知指令语法** | 导入报错 | `ExportBlocksAsDocuments` 导出真实语法 |
| 10 | **wire# 放错位置** | EN 断连 | wire# 只用于并联分支 |
| 11 | **MIN/MAX/LIMIT/SEL 用了 SrcType** | `Invalid Template Types` | 改为 `value_type`（§二点五） |
| 12 | **MUX 用了 value_type** | `Invalid Template Types` | MUX 用 `SrcType`（§二点五）— 与其余选择器不同！ |
| 13 | **移位 SHR/SHL/ROR/ROL 没写模板** | 编译/导入失败 | 必加 `{ S7_Templates := "SrcType := DWord" }` |
| 14 | **P_Contact/N_Contact 没写 bit 引脚** | `Pin 'bit' connection is missing` | 写 `P_Contact( operand:=sig, bit:=#mem )` |
| 15 | **MUX 没写 else 输出** | `Pin 'else' missing` | 加 `else := default_value` |
| 16 | **NEG 用了 in1 引脚** | 编译报错 | 引脚名是 `in` 不是 `in1` |
| 17 | **VAR_TEMP 用了 AT 覆盖** | 语法错误 | LAD 不支持 `AT` 语法，用独立变量 |
| 18 | **JMP/LABEL/RET 导入** | `mismatched input 'LABEL'` | S7DCL 导入不支持跳转/返回指令 |
| 19 | **Contact(Negated(#Var))** | 语法错误 | S7DCL 无 Negated() 包裹函数！用 Not() 或 I_Contact |
| 20 | **Not() 放 RUNG 起始** | `不可将 NOT 运算连接到程序段` | 必须前有触点：Contact→Not→Coil |
| 21 | **wire# 在 Contact 和 Box 之间** | `Pin 'en' missing` / `pre missing` | Box 必须直连前一个元素，无 wire# |
| 22 | **两个 Box 同一 RUNG 串联** | ENO→EN 断开 | 拆成两个独立网络 |
| 23 | **CTU/CTD/CTUD 计数器用大写在 LAD** | 编译错误 | LAD 用小写引脚名 `r`/`pv`/`cv`/`ld`/`cd`！SCL 才用大写 |
| 24 | **Counter SCL 分步赋值** | 参数"已使用" | 全部引脚一个语句完成 |
| 25 | **计数器 Static 类型用 IEC_COUNTER** | 类型错误 | 分别用 `CTU_INT`/`CTD_INT`/`CTUD_INT` |
| 26 | **变量引用不用双引号** | 变量未定义 | `#"VarName"` 声明和引用都必须有双引号 |
| 27 | **用了不存在的 CMP >= 盒语法** | 语法错误 | 比较盒用 `GT(in1:=, in2:=, out=>)` 非 `CMP >=` |
| 28 | **.s7res 含多余 MLC 条目** | 导入失败 | .s7res 必须精确定义：只保留 .s7dcl 中实际引用的 MLC ID |
| 29 | **CTU/CTD/CTUD 忘记 P_Trig 边沿** | 每周期计数 | LAD 计数器需 P_Trig 提供上升沿，否则每个扫描周期都计数 |
| 30 | **FC 调用 EN 用 wire# 直连** | 看似违规，实则有效 | Block 调用可用 wire# 提供 EN（非 box 指令规则） |
| 31 | **两个 Box 从 powerrail 串联** | 看似违规，实则有效 | 从 powerrail 起的双 Box（无 Contact 前置）ENO→EN 正常连接 |

---

## 附录 A：AS300/400 专用遗留指令（完整清单）

以下指令仅在目标平台为 AS300/AS400 时可用。S7-1200/1500 优化块访问模式下通常不需要。

### A.1 标志触点（共 19 个，对应 PDF Table 3）

| 指令 | 标志 | 说明 |
|------|------|------|
| `BR_FlagContact()` | BR | 二进制结果位 |
| `BR_I_Flag_Contract()` | not BR | 取反 BR |
| `OS_FlagContact()` | OS | 溢出存储位 |
| `OS_I_Flag_Contract()` | not OS | 取反 OS |
| `OV_FlagContact()` | OV | 溢出位 |
| `OV_I_Flag_Contract()` | not OV | 取反 OV |
| `UO_FlagContact()` | UO | 无序位（浮点无效） |
| `UO_I_Flag_Contract()` | not UO | 取反 UO |
| `EQ_FlagsContact()` | not A0 and not A1 | A0=A1 |
| `EQ_I_Flags_Contract()` | A0 or A1 | A0<>A1 |
| `NE_FlagsContact()` | A0 <> A1 | A0<>A1 |
| `NE_I_Flags_Contract()` | A0 = A1 | A0=A1 |
| `GE_FlagsContact()` | not A0 | >=0 |
| `GE_I_Flags_Contract()` | A0 | <0 |
| `LE_FlagsContact()` | not A1 | <=0 |
| `LE_I_Flags_Contract()` | A1 | >0 |
| `GT_FlagsContact()` | not A0 and A1 | >0 |
| `GT_I_Flags_Contract()` | A0 or not A1 | <=0 |
| `LT_FlagsContact()` | A0 and not A1 | <0 |
| `LT_I_Flags_Contract()` | not A0 or A1 | >=0 |

### A.2 零操作数线圈（共 5 个，对应 PDF §4.2.3）

| 指令 | 说明 |
|------|------|
| `McrOpenCoil()` | 打开 MCR 区 |
| `McrCloseCoil()` | 关闭 MCR 区 |
| `McrActivateCoil()` | 激活 MCR |
| `McrDeactivateCoil()` | 停用 MCR |
| `SaveCoil()` | 保存 RLO 到 BR 位 |

### A.3 其他遗留指令

| 指令 | 说明 |
|------|------|
| `OpenDBCoil( operand )` | 打开全局数据块 |
| `OpenDICoil( operand )` | 打开实例数据块 |

> 以上条目基于 Siemens spec Entry ID 109994073 §4.1.3、§4.2.3、§4.6.1 逐条提取。

---

## 八、本地样本路径

| 样本 | 内容 |
|------|------|
| `skill/lad-cookbook/MCPVerify_FC_LAD.s7dcl` + `.s7res` | 串联/并联/SR/比较/Move/Add |
| `skill/lad-cookbook/MCPVerify_FB_LAD_v3.s7dcl` + `.s7res` | 定时器/P_Trig/Not/LT |
| `docs/DS文件收集/程序语法格式参考(博图编译通过0错误).s7dcl` | **权威参考程序** — FB全语法覆盖，TIA V21 编译 0 错误 |
| `docs/DS文件收集/SIMATIC_Source_Documents_LADDER_Format_Description.pdf` | 官方规范 Entry ID 109994073 |
| `docs/DS文件收集/SimaticSDEnabler_V1.1.0/` | Siemens 官方 SimaticSDEnabler CLI 工具 (SDEnablerCli v1.1.0) |

### SimaticSDEnabler CLI 工具
Siemens 官方提供的命令行工具，位于 `docs/DS文件收集/SimaticSDEnabler_V1.1.0/`，核心可执行文件：
```
S7MlcCreator.exe -p "C:\path\to\project.ap21"
```
需要 TIA Portal Openness 运行时（`Siemens.Engineering.dll`）。配套 PDF 文档 `SimaticSDEnabler_DOC_1_1_0_en.pdf` 包含完整使用说明。

---

## 九、与 SKILL.md 的关系

本文件是 `SKILL.md` §9 (LAD via S7DCL) 的扩展参考。SKILL.md §9 提供快速入门和决策规则；本文件提供完整指令语法。

**快速决策：**
- 任何触点/线圈/SR/比较/Move/数学 → 写 `.s7dcl` 文本 → `ImportBlocksFromDocuments`
- 仅 FC 调用网络 → `ComposePlcLadFcBlockXml`
- 手写 FlgNet XML → 避免
