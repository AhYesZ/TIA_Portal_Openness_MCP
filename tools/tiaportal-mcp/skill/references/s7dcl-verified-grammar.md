# S7DCL LAD — Verified Grammar Reference
>
> **来源优先级**: 示例代码 > PDF规范。冲突处以示例为准。
> **验证基准**: FB_CompleteInstructionGallery (67网络), FB_Reference (23网络), FC_LAD_InstructionGallery (32网络)
> **全部 TIA V21 编译 0 错误 0 警告**

---

## §1. 文件结构

### 1.1 Block Header (固定格式)

```
{                                                                       ← 必须 {
    S7_BlockComment := "MLC_xxx";                                       ← MLC ID 引用 .s7res
    S7_BlockNumber := "952";                                            ← 字符串格式, 非数字
    S7_BlockTitle := "MLC_xxx";                                         ← MLC ID 引用 .s7res
    S7_Optimized := "TRUE";                                             ← 固定 TRUE
    S7_PreferredLanguage := "LAD";                                      ← 固定 LAD
    S7_Version := "0.1"                                                 ← 固定 0.1
}                                                                       ← 必须 }
FUNCTION_BLOCK "Name"                                                   ← 或 FUNCTION "Name" : Void
```

**来源**: FB_Complete, FB_Reference, FC_Gallery (3/3一致)

### 1.2 Block Types

| 类型 | 声明 | 示例来源 |
|------|------|---------|
| FC | `FUNCTION "Name" : Void` | FC_Gallery |
| FB | `FUNCTION_BLOCK "Name"` | FB_Complete, FB_Reference |

### 1.3 .s7res 格式 (固定)

```yaml
MultiLingualTexts:
  - id: MLC_xxx
    zh-CN: 中文描述
    en-US: English description
```

**规则**: 
- 每个 .s7dcl 中引用的 MLC_* 必须在 .s7res 中有对应条目
- 必须同时提供 zh-CN 和 en-US
- **不允许**多余的 MLC 条目 (.s7res 只保留 .s7dcl 实际引用的)
- **来源**: FB_Complete .s7res (273行, 精确匹配67网络×2+2块级MLC)

---

## §2. VAR 声明

### 2.1 固定格式

```
    VAR_INPUT
        "VarName" : Type;                                               ← 双引号必须
    END_VAR
    VAR_OUTPUT
        "VarName" : Type;
    END_VAR
    VAR                                                               ← FB Static
        "VarName" : Type;
    END_VAR
    VAR_TEMP
        "VarName" : Type;
    END_VAR
```

**来源**: 全部3个示例

### 2.2 已验证的类型空间

```
VAR_INPUT/VAR_OUTPUT 类型: Bool, Int, Real, DInt, DWord, Word, Time
VAR (Static) 类型:        Bool, Int, Real, DInt, DWord, Word, Time,
                         TON_TIME, TOF_TIME, TP_TIME,
                         CTU_INT, CTD_INT, CTUD_INT,
                         _.FB_BasicLatch (FB调用实例)
VAR_TEMP 类型:            Bool, Int, Real
```

**来源**: FB_Complete, FB_Reference

### 2.3 隐含规则

| 规则 | 来源 |
|------|------|
| 变量名必须双引号包裹 `"Name"` | 全部3示例 |
| 引用时用 `#"Name"` 格式 | 全部3示例 |
| 类型不区分大小写 (`Bool`/`Int`/`DInt`) 但声明保持一致 | 全部3示例 |
| VAR_IN_OUT 可用但不常见 (FB_Reference 使用) | FB_Reference |
| 声明顺序: INPUT → OUTPUT → VAR_IN_OUT → VAR → VAR_TEMP | 全部FBs |

---

## §3. 网络结构

### 3.1 网络 Pragma (固定格式)

```
    {                                                                   ← 必须 {
        S7_Language := "LAD";                                           ← LAD 或 SCL
        S7_NetworkComment := "MLC_xxx";                                 ← MLC ID
        S7_NetworkTitle := "MLC_xxx"                                    ← MLC ID (最后一项无分号)
    }
    NETWORK
        RUNG wire#powerrail
            ...instructions...
        END_RUNG
    END_NETWORK
```

**来源**: FB_Complete (67次出现, 格式完全一致)

### 3.2 SCL 网络 (用于计数器/字逻辑)

```
    {
        S7_Language := "SCL";                                           ← 改为 SCL
        S7_NetworkComment := "MLC_xxx";
        S7_NetworkTitle := "MLC_xxx"
    }
    NETWORK
        #"ctuInst".CTU(CU := #"CountUp",                              ← SCL语句, 无RUNG
                       R := #"Reset",
                       PV := #"PresetValue",
                       Q => #"CTU_Q",
                       CV => #"CTU_CV");
    END_NETWORK
```

**来源**: FB_Complete (N54-N56: CTU/CTD/CTUD in SCL; N50: 字逻辑)

---

## §4. RUNG 结构

### 4.1 基本串联 (无分支)

```
        RUNG wire#powerrail
            Contact( #"A" )
            Contact( #"B" )
            Coil( #"OUT" )
        END_RUNG
```

### 4.2 并联 (wire# 分支)

```
        RUNG wire#powerrail
            Contact( #"A" )
            wire#w1                                              ← wire# 标记从此处分叉
            Coil( #"OUT" )                                       ← 汇合后输出
        END_RUNG
        RUNG wire#powerrail
            Contact( #"B" )
        END_RUNG wire#w1                                         ← 分支结束, 汇入 wire#w1
        RUNG wire#powerrail
            Contact( #"C" )
        END_RUNG wire#w1                                         ← 第二个分支
```

**来源**: FB_Complete N04, N29, N63, N66

### 4.3 嵌套分支 (两层 wire#)

```
        RUNG wire#powerrail
            Contact( #"A" )
            wire#w2
            Contact( #"C" )
            wire#w3
            Coil( #"OUT" )
        END_RUNG
        RUNG wire#powerrail
            Contact( #"B" )
        END_RUNG wire#w2                                         ← 分支到第一层
        RUNG wire#powerrail
            Contact( #"RESET" )
        END_RUNG wire#w3                                         ← 分支到第二层
```

**来源**: FB_Complete N29

---

## §5. 指令全集 (已验证)

> 格式: `指令名( 参数列表 )` — 输出针脚用 `=>`, 输入针脚用 `:=`
> [来源标记]: A=FB_Complete, B=FB_Reference, C=FC_Gallery

### 5.1 单操作数指令 (1-op)

| 指令 | 语法 | 语义 | 来源 |
|------|------|------|------|
| `Contact` | `Contact( #"Var" )` | NO触点 | ABC |
| `Contact` | `Contact( "DB".Member )` | 全局变量触点 | A |
| `Contact` | `Contact( "DB".%X0 )` | 全局位触点 | A |
| `Coil` | `Coil( #"Var" )` | 输出线圈 | ABC |
| `S_Coil` | `S_Coil( #"Var" )` | 置位线圈 | ABC |
| `R_Coil` | `R_Coil( #"Var" )` | 复位线圈 | ABC |
| `Not` | `Not()` | RLO取反 | ABC |
| `P_Trig` | `P_Trig( #"EdgeMem" )` | 上升沿检测(Box型) | ABC |
| `N_Trig` | `N_Trig( #"EdgeMem" )` | 下降沿检测(Box型) | ABC |

**操作数格式**: `#"VarName"` 或 `"DB_Name".Member` 或 `"DB_Name".%X0`

**隐含规则**: 
- Not() 不能放在RUNG起始位置 (必须有前导触点提供能流) — [Claude Code 验证]
- 没有 `Negated()` 包裹函数 — [Claude Code 验证]
- P_Trig/N_Trig 是1-op Box型沿检测 (区别于2-op P_Contact/N_Contact)

### 5.2 比较触点 (2-op Contact型)

| 指令 | 模板 | 针脚 | 来源 |
|------|------|------|------|
| `GT_Contact` | `SrcType := Int` 或 `SrcType := Real` | `in1 := expr, in2 := expr` | ABC |
| `LT_Contact` | `SrcType := Int` 或 `SrcType := Real` | `in1 := expr, in2 := expr` | ABC |
| `EQ_Contact` | `SrcType := Int` 或 `SrcType := Real` | `in1 := expr, in2 := expr` | ABC |
| `NE_Contact` | `SrcType := Int` 或 `SrcType := Real` | `in1 := expr, in2 := expr` | ABC |
| `GE_Contact` | `SrcType := Int` 或 `SrcType := Real` | `in1 := expr, in2 := expr` | ABC |
| `LE_Contact` | `SrcType := Int` 或 `SrcType := Real` | `in1 := expr, in2 := expr` | ABC |

**使用模式**: `GT_Contact(in1:=..., in2:=...)` 后接 `Coil(#out)` 输出比较结果

### 5.3 比较盒 (2-op Box型)

| 指令 | 模板 | 针脚 | 来源 |
|------|------|------|------|
| `GT` | `SrcType := Int` | `in1 := expr, in2 := expr, out => expr` | AC |
| `LT` | `SrcType := Int` | `in1 := expr, in2 := expr, out => expr` | AC |
| `EQ` | `SrcType := Int` | `in1 := expr, in2 := expr, out => expr` | AC |
| `NE` | `SrcType := Int` | `in1 := expr, in2 := expr, out => expr` | AC |
| `GE` | `SrcType := Int` | `in1 := expr, in2 := expr, out => expr` | AC |
| `LE` | `SrcType := Int` | `in1 := expr, in2 := expr, out => expr` | AC |

**与比较触点区别**: 盒型结果通过 `out =>` 输出; 触点型通过后接 `Coil()` 输出

### 5.4 数学运算 (Box型)

| 指令 | 模板 | 针脚 | 来源 |
|------|------|------|------|
| `Add` | `SrcType := Int` 或 `SrcType := Real` | `in1 := expr, in2 := expr, out => expr` | ABC |
| `Sub` | `SrcType := Int` 或 `SrcType := Real` | `in1 := expr, in2 := expr, out => expr` | ABC |
| `Mul` | `SrcType := Int` 或 `SrcType := Real` | `in1 := expr, in2 := expr, out => expr` | ABC |
| `Div` | `SrcType := Int` 或 `SrcType := Real` | `in1 := expr, in2 := expr, out => expr` | ABC |
| `Mod` | `SrcType := DInt` | `in1 := expr, in2 := DINT#3, out => expr` | AB |
| `Neg` | `SrcType := Real` | `in := expr, out => expr` | AB |

### 5.5 传送与转换

| 指令 | 模板 | 针脚 | 来源 |
|------|------|------|------|
| `Move` | 不需要模板 | `in := expr, out1 => expr` | ABC |
| `Convert` | `[SrcType := T1, DestType := T2]` | `in := expr, out => expr` | AB |

**Convert 已验证转换对**: DInt→Real, Real→DInt

### 5.6 选择器

| 指令 | 模板 | 针脚 | 来源 |
|------|------|------|------|
| `MIN` | `value_type := Real` + `S7_GenerateENO := "TRUE"` | `in1 := expr, in2 := expr, out => expr` | AB |
| `MAX` | `value_type := Real` + `S7_GenerateENO := "TRUE"` | `in1 := expr, in2 := expr, out => expr` | AB |
| `Limit` | `value_type := Int` + `S7_GenerateENO := "TRUE"` | `min := expr, in := expr, max := expr, out => expr` | AB |
| `SEL` | `value_type := Int` | `g := expr, in0 := expr, in1 := expr, out => expr` | AB |
| `Mux` | `SrcType := Int` | `k := expr, in0..in3 := const, else := const, out => expr` | AB |

**⚠️ 针脚名精确要求**:
- LIMIT用 `min`/`max` (非 `mn`/`mx`/`minimum`/`maximum`)
- MUX用 `SrcType` (非 `value_type` — 与其他选择器不同!)
- MIN/MAX 需 `S7_GenerateENO := "TRUE"`

### 5.7 移位

| 指令 | 模板 | 针脚 | 来源 |
|------|------|------|------|
| `Shr` | `SrcType := DWord` | `in := expr, n := const, out => expr` | AB |
| `Shl` | `SrcType := DWord` | `in := expr, n := const, out => expr` | AB |

### 5.8 定时器 (Instance-prefixed, LAD)

| 指令 | 模板 | 针脚 | 来源 |
|------|------|------|------|
| `#inst.TON` | `time_type := Time` | `pt := expr, q => expr, et => expr` | A |
| `#inst.TOF` | `time_type := Time` | `pt := expr, q => expr, et => expr` | A |
| `#inst.TP` | `time_type := Time` | `pt := expr, q => expr, et => expr` | A |

**Static 声明**: `"inst" : TON_TIME;`, `"inst" : TOF_TIME;`, `"inst" : TP_TIME;`

### 5.9 计数器 LAD (Instance-prefixed, 小写针脚 + P_Trig 边沿)

| 指令 | 模板 | 针脚 | 来源 |
|------|------|------|------|
| `#inst.CTU` | `value_type := Int` | `r := expr, pv := expr, cv => expr` + Coil(Q) | A (N59) |
| `#inst.CTD` | `value_type := Int` | `ld := expr, pv := expr, cv => expr` + Coil(Q) | A (N60) |
| `#inst.CTUD` | `value_type := Int` | `cd := expr, r := expr, ld := expr, pv := expr, qd => expr, cv => expr` + Coil(QU) | A (N61) |

**规则**:
- 计数针脚(cu/cd)由 P_Trig 能流驱动, 不显式赋值
- LAD 用小写; SCL 用大写
- Static: `CTU_INT`, `CTD_INT`, `CTUD_INT`

### 5.10 计数器 SCL (Instance-method, 大写针脚, 一句完成)

```
#"ctuInst".CTU(CU := #"CountUp",
               R := #"Reset",
               PV := #"PresetValue",
               Q => #"CTU_Q",
               CV => #"CTU_CV");
```

**来源**: A (N54-N56)

### 5.11 块调用

| 类型 | 语法 | 模板 | 来源 |
|------|------|------|------|
| FB调用 | `#"inst"(param:=val, ..., output=>expr)` | 不需要 | A (N62) |
| FC调用 | `"FC_Name"(param:=val, ..., output=>expr)` | 不需要 | AB (N63) |

**FC调用 EN 控制**: `Contact → wire#wN → "FC_Name"(...)`

### 5.12 SCL 字逻辑

```scl
#"OUT_AndWord" := #"WordVal" AND W#16#00FF;
#"OUT_OrWord" := #"WordVal" OR W#16#FF00;
#"OUT_XorWord" := #"WordVal" XOR W#16#FFFF;
```

**来源**: A (N50), B (SCL网络)

---

## §6. 模板速查表

| 模板名 | 适用于 | 验证状态 |
|--------|--------|---------|
| `SrcType := Int` | Add/Sub/Mul/Div, GT/LT/EQ/NE/GE/LE_Contact, GT/LT/EQ/NE/GE/LE, Mod, Mux | ✅ 全部验证 |
| `SrcType := Real` | 同上 Real版本, Neg | ✅ 全部验证 |
| `SrcType := DInt` | Mod(DInt) | ✅ 验证 |
| `SrcType := DWord` | Shr, Shl | ✅ 验证 |
| `value_type := Int` | MIN/MAX/LIMIT/SEL, CTU/CTD/CTUD(LAD) | ✅ 全部验证 |
| `value_type := Real` | MIN/MAX (Real) | ✅ 验证 |
| `time_type := Time` | TON/TOF/TP | ✅ 验证 |
| `[SrcType := T1, DestType := T2]` | Convert | ✅ 验证 |
| 不需要模板 | Move, Contact, Coil, S_Coil, R_Coil, Not, P_Trig, N_Trig, 块调用 | ✅ 全部验证 |
| `S7_GenerateENO := "TRUE"` | MIN/MAX/LIMIT (配合 value_type) | ✅ 验证 |

### ⚠️ PDF vs 示例冲突

| PDF声称 | 示例证实 | 结论 |
|---------|---------|------|
| `timeType := Time` (PDF Listing 29) | `time_type := Time` | **PDF错误!** |
| `countType := DInt` (PDF Listing 30) | `value_type := Int` | **PDF错误!** |
| `SrcType` 用于选择器 | MIN/MAX/SEL用 `value_type` | **PDF部分错误** |
| MUX 用 `value_type` | MUX 用 `SrcType` | **PDF错误!** |
| 移位不需要模板 | Shr/Shl 需 `SrcType` | **PDF不完整** |
| Convert 用 `inType`/`outType` | 用 `SrcType`/`DestType` | **PDF错误!** |

### 未验证项 (PDF有, 示例无)

| 指令/功能 | 说明 |
|----------|------|
| `CMP >=` / `CMP <=` / `CMP <>` / `CMP ==` | **不存在于S7DCL** |
| `Calculate` box | 未有验证示例 |
| Simatic 定时器线圈 (SP_Coil等) | 未有验证示例 |
| Simatic 计数器 (S_Cu等) | 未有验证示例 |
| JMP/LABEL/RET | **S7DCL 导入不支持** |
| JumpList / Switch | 未有验证示例 |
| AS300/400 标志触点 | 未有验证示例 |
| P_Contact/N_Contact (2-op 触点型沿检测) | 未有验证示例 |
| I_Contact (NC触点) | 未有验证示例 |

---

## §7. 非法语法清单 (反例)

> 以下写法**看起来合理但会导致导入/编译错误**

### 7.1 不存在的指令/包裹

```
❌ Contact( Negated( #"A" ) )          ← Negated() 不存在于 S7DCL
❌ CMP >=( in1 := #V, in2 := #V )      ← CMP 盒语法不存在, 用 GT(...)
❌ CMP <=( in1 := #V, in2 := #V )      ← 同上, 用 LT(...)
```

### 7.2 Not() 位置错误

```
❌ RUNG wire#powerrail
      Not()                               ← LAD不允许Not在RUNG起始
      Coil( #"OUT" )
✅ RUNG wire#powerrail
      Contact( #"A" )
      Not()                               ← 必须在触点之后
      Coil( #"OUT" )
```

### 7.3 wire# 断开 Box EN

```
❌ Contact( #"A" )
      wire#w2                              ← wire# 在 Contact 和 Add 之间
      Add( in1:=..., in2:=..., out=>... )  ← EN pin 断开

✅ Contact( #"A" )
      Add( in1:=..., in2:=..., out=>... )  ← Add 直连 Contact
```

### 7.4 计数器针脚错误

```
❌ #"ctuInst".CTU( cu := #"Var", ... )    ← LAD中cu由能流驱动, 不显式赋值
❌ #"ctuInst".CTU( CU := #"Var", ... )    ← LAD用大写CU, 应用小写cu (实际不显式)
❌ #"ctuInst".CTU( r := #"Var", ... )     ← 小写r正确, 但缺 P_Trig 边沿 (每周期计数)

✅ Contact(#"Trig") P_Trig(#"Edge")
   #"ctuEdgeInst".CTU( r:=#, pv:=#, cv=># )
   Coil(#"Q")
```

### 7.5 定时器模板名错误

```
❌ { S7_Templates := "timeType := Time" }   ← camelCase不存在
❌ { S7_Templates := "TimeType := Time" }   ← 不存在
✅ { S7_Templates := "time_type := Time" }   ← 下划线格式
```

### 7.6 Convert 针脚名错误

```
❌ { S7_Templates := "[inType := Int, outType := Real]" }    ← 不存在
✅ { S7_Templates := "[SrcType := Int, DestType := Real]" }   ← 正确
```

### 7.7 选择器模板错误

```
❌ { S7_Templates := "SrcType := Int" }    ← MIN/MAX/LIMIT/SEL 应用 value_type
   MIN( in1:=#, in2:=#, out=># )
✅ { S7_Templates := "value_type := Int" }
   MIN( in1:=#, in2:=#, out=># )

❌ { S7_Templates := "value_type := Int" } ← MUX 用 SrcType (例外!)
   Mux( k:=#, in0:=10, ..., out=># )
✅ { S7_Templates := "SrcType := Int" }
   Mux( k:=#, in0:=10, ..., out=># )
```

### 7.8 变量引用缺少双引号

```
❌ Contact( #SET )                          ← Block接口变量必须双引号
✅ Contact( #"SET" )

❌ Coil( #OUT_AND )                         ← 同上
✅ Coil( #"OUT_AND" )
```

### 7.9 .s7res 多余条目

```
❌ .s7res 包含 MLC_N99t (但 .s7dcl 中没有 N99 网络)
✅ .s7res 只保留 .s7dcl 实际引用的 MLC ID
```

### 7.10 计数器 SCL 分步赋值

```
❌ #"ctuInst".CU := #"CountUp";             ← 分步赋值报 "已使用"
   #"ctuInst".R := #"Reset";
   #"ctuInst".PV := #"PresetValue";
   #"ctuInst"();
   #"CTU_Q" := #"ctuInst".Q;

✅ #"ctuInst".CTU(CU := #"CountUp",         ← 一句完成, 方法调用
                  R := #"Reset",
                  PV := #"PresetValue",
                  Q => #"CTU_Q",
                  CV => #"CTU_CV");
```

---

## §8. 变量引用规范

| 目标 | 语法 | 来源 |
|------|------|------|
| Block接口变量 (Input/Output/Static/Temp) | `#"VarName"` | ABC |
| 全局DB成员 | `"DB_Name".Member` | A |
| 全局DB位访问 | `"DB_Name".%X0` | A |
| 嵌套DB成员 | `"DB_Name".Group.Member` | A |
| Wire标识 | `wire#name` | ABC |
| 左母线 | `wire#powerrail` | ABC |
| 常量 | 直接写: `TRUE`, `FALSE`, `0`, `10.0`, `T#1s`, `DINT#3`, `W#16#00FF` | ABC |

---

## §9. 指令-针脚-模板 快速查证表

| 指令 | 针脚 (:=输入, =>输出) | 模板 | 源 |
|------|---------------------|------|----|
| Contact | `( var )` 1-op | 无 | ABC |
| Coil | `( var )` 1-op | 无 | ABC |
| S_Coil | `( var )` 1-op | 无 | ABC |
| R_Coil | `( var )` 1-op | 无 | ABC |
| Not | `()` 0-op | 无 | ABC |
| P_Trig | `( #mem )` 1-op | 无 | ABC |
| N_Trig | `( #mem )` 1-op | 无 | ABC |
| GT_Contact | `in1 := , in2 :=` | SrcType | ABC |
| LT_Contact | `in1 := , in2 :=` | SrcType | ABC |
| EQ_Contact | `in1 := , in2 :=` | SrcType | ABC |
| NE_Contact | `in1 := , in2 :=` | SrcType | ABC |
| GE_Contact | `in1 := , in2 :=` | SrcType | ABC |
| LE_Contact | `in1 := , in2 :=` | SrcType | ABC |
| GT | `in1 := , in2 := , out =>` | SrcType | AC |
| LT | `in1 := , in2 := , out =>` | SrcType | AC |
| EQ | `in1 := , in2 := , out =>` | SrcType | AC |
| NE | `in1 := , in2 := , out =>` | SrcType | AC |
| GE | `in1 := , in2 := , out =>` | SrcType | AC |
| LE | `in1 := , in2 := , out =>` | SrcType | AC |
| Add | `in1 := , in2 := , out =>` | SrcType | ABC |
| Sub | `in1 := , in2 := , out =>` | SrcType | ABC |
| Mul | `in1 := , in2 := , out =>` | SrcType | ABC |
| Div | `in1 := , in2 := , out =>` | SrcType | ABC |
| Mod | `in1 := , in2 := , out =>` | SrcType | AB |
| Neg | `in := , out =>` | SrcType | AB |
| Move | `in := , out1 =>` | 无 | ABC |
| Convert | `in := , out =>` | [SrcType,DestType] | AB |
| MIN | `in1 := , in2 := , out =>` | value_type +GenENO | AB |
| MAX | `in1 := , in2 := , out =>` | value_type +GenENO | AB |
| Limit | `min := , in := , max := , out =>` | value_type +GenENO | AB |
| SEL | `g := , in0 := , in1 := , out =>` | value_type | AB |
| Mux | `k := , in0..in3 := , else := , out =>` | SrcType | AB |
| Shr | `in := , n := , out =>` | SrcType | AB |
| Shl | `in := , n := , out =>` | SrcType | AB |
| TON | `pt := , q => , et =>` [inst] | time_type | A |
| TOF | `pt := , q => , et =>` [inst] | time_type | A |
| TP | `pt := , q => , et =>` [inst] | time_type | A |
| CTU(LAD) | `r := , pv := , cv =>` [inst] | value_type | A |
| CTD(LAD) | `ld := , pv := , cv =>` [inst] | value_type | A |
| CTUD(LAD) | `cd := , r := , ld := , pv := , qd => , cv =>` [inst] | value_type | A |
| CTU(SCL) | `CU:=, R:=, PV:=, Q=>, CV=>` [inst] | N/A | A |
| CTD(SCL) | `CD:=, LD:=, PV:=, Q=>, CV=>` [inst] | N/A | A |
| CTUD(SCL) | `CU:=, CD:=, R:=, LD:=, PV:=, QU=>, QD=>, CV=>` [inst] | N/A | A |
