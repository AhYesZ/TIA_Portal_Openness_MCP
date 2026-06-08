# TIA Portal V21 语法规则 Skill —— SCL + LAD 指令最小示例集

> 给后续 AI 模型 / 工程师的"一次到位"指令对照表。每条指令有：
> - 用户自然语言描述
> - SCL 文本写法（人类可读）
> - 真实导出 XML 片段（合规 V21 schema）
> - 当前 builder JSON 对应（如果支持）/ 限制说明（如果不支持）
>
> 全部源自用户 5T车 项目（`C:\Users\XL626\Desktop\PID博途块\TMP_EXPORT\Source\5T车\Blocks`）真实导出 XML 的逆向阅读。每条都有 UId 编号示例 —— 真实 builder 实现时 UId 必须连续唯一。

---

## §0 共同概念

### 0.1 namespace
- SCL 网络：`<StructuredText xmlns="http://www.siemens.com/automation/Openness/SW/NetworkSource/StructuredText/v4">`
- LAD 网络：`<FlgNet xmlns="http://www.siemens.com/automation/Openness/SW/NetworkSource/FlgNet/v5">`
- 接口/UDT/DB：`<Sections xmlns="http://www.siemens.com/automation/Openness/SW/Interface/v5">`

### 0.2 块结构（FB / FC / OB 共通）
```xml
<Document>
  <Engineering version="V21" />
  <DocumentInfo>...</DocumentInfo>
  <SW.Blocks.{FC|FB|OB} ID="0">
    <AttributeList>
      <Interface><Sections>...</Sections></Interface>
      <MemoryLayout>Optimized</MemoryLayout>
      <Name>FC_X</Name>
      <Number>10</Number>
      <ProgrammingLanguage>SCL|LAD|FBD</ProgrammingLanguage>
      <SetENOAutomatically>false</SetENOAutomatically>
      <!-- OB 还要 <SecondaryType>ProgramCycle</SecondaryType> -->
    </AttributeList>
    <ObjectList>
      <!-- 顺序很重要：Comment → CompileUnit(s) → Title -->
      <MultilingualText ID="1" CompositionName="Comment">...</MultilingualText>
      <SW.Blocks.CompileUnit ID="3">
        <AttributeList>
          <NetworkSource><FlgNet|StructuredText>...</NetworkSource>
          <ProgrammingLanguage>SCL|LAD</ProgrammingLanguage>
        </AttributeList>
        <ObjectList>
          <MultilingualText ID="4" CompositionName="Comment">...</MultilingualText>
          <MultilingualText ID="6" CompositionName="Title">...</MultilingualText>
        </ObjectList>
      </SW.Blocks.CompileUnit>
      <MultilingualText ID="8" CompositionName="Title">...</MultilingualText>
    </ObjectList>
  </SW.Blocks.{...}>
</Document>
```

### 0.3 中文 MultilingualText 格式
```xml
<MultilingualText ID="1" CompositionName="Comment">
  <ObjectList>
    <MultilingualTextItem ID="2" CompositionName="Items">
      <AttributeList>
        <Culture>zh-CN</Culture>
        <Text>多行中文注释</Text>   <!-- HMI Screen 用 <Text><body><p>...</p></body></Text> -->
      </AttributeList>
    </MultilingualTextItem>
  </ObjectList>
</MultilingualText>
```

---

## §1 SCL（StructuredText/v4）指令

### 1.1 变量访问（Symbol）

#### 1.1.1 局部变量（单段）
- 用户语言："读 #x" / "把 Run 写到本地变量"
- SCL：`#x` （或省略 `#` 直接 `x`）
- 真实 XML：
```xml
<Access Scope="LocalVariable" UId="22">
  <Symbol UId="23"><Component Name="x" UId="24" /></Symbol>
</Access>
```
- Builder JSON：`{op:"local", name:"x"}` 或 `{op:"symbol", name:"x"}` 或直接在 `assignment.target`/`if.condition` 里传 `"x"`

#### 1.1.2 局部变量多段（实例 FB 输出）
- 用户语言："读 #trig 的 Q 输出"
- SCL：`#trig.Q`
- 真实 XML：
```xml
<Access Scope="LocalVariable" UId="22">
  <Symbol UId="23">
    <Component Name="trig" UId="24" />
    <Token Text="." UId="25" />
    <Component Name="Q" UId="26" />
  </Symbol>
</Access>
```
- Builder JSON：`{op:"symbol", name:"trig.Q"}` 或 `{op:"local", name:"trig.Q"}` ✅ 已支持

#### 1.1.3 全局变量（单段，带 HasQuotes）
- 用户语言：'读全局位 "I_Start"'
- SCL：`"I_Start"`
- 真实 XML：
```xml
<Access Scope="GlobalVariable" UId="21">
  <Symbol UId="22">
    <Component Name="I_Start" UId="23">
      <BooleanAttribute Name="HasQuotes" UId="24">true</BooleanAttribute>
    </Component>
  </Symbol>
</Access>
```
- Builder JSON：`{op:"global", name:"I_Start"}` 或 `{op:"symbol", name:"\"I_Start\""}` ✅

#### 1.1.4 全局 DB 成员（多段）
- 用户语言：'读 DB_Motor 的 Speed'
- SCL：`"DB_Motor".Speed` 或 `"DB_Motor.Speed"`
- 真实 XML：
```xml
<Access Scope="GlobalVariable" UId="22">
  <Symbol UId="23">
    <Component Name="Sim_Data" />
    <Token Text="." />
    <Component Name="Gantry_Pos" />
  </Symbol>
</Access>
```
- Builder JSON：`{sym:"\"Sim_Data\".Gantry_Pos"}` ✅

#### 1.1.5 全局常量
- SCL：`"ABB-Gantry~PPO_Type_6_1"`
- 真实 XML：
```xml
<Access Scope="GlobalConstant" UId="21">
  <Constant Name="ABB-Gantry~PPO_Type_6_1" />
</Access>
```
- Builder JSON：**当前 builder 缺这个 Scope** ⚠️。需扩 `GlobalConstant(name)`

### 1.2 字面常量（LiteralConstant）

#### 1.2.1 Bool / Int / Real
```xml
<!-- TRUE / FALSE -->
<Access Scope="LiteralConstant" UId="36">
  <Constant UId="37"><ConstantValue UId="38">FALSE</ConstantValue></Constant>
</Access>

<!-- 整型 100 -->
<Access Scope="LiteralConstant"><Constant><ConstantValue>100</ConstantValue></Constant></Access>

<!-- 浮点 0.1 (可带 ConstantType 强制类型) -->
<Access Scope="LiteralConstant" UId="25">
  <Constant>
    <ConstantType>Real</ConstantType>
    <ConstantValue>0.1</ConstantValue>
  </Constant>
</Access>
```
- Builder JSON：`{op:"literal", value:"0.1"}` ✅（ConstantType 标签 builder **当前未支持**，靠 TIA 推断）

#### 1.2.2 TIME / 字符串 / Any 指针
```xml
<!-- T#1S -->
<ConstantValue>T#1S</ConstantValue>

<!-- 字符串 'abc' -->
<ConstantValue>'abc'</ConstantValue>

<!-- ANY 指针 P#DB1.DBX20.0 BYTE 20 -->
<Constant>
  <ConstantType>Any</ConstantType>
  <ConstantValue>P#DB1.DBX20.0 BYTE 20</ConstantValue>
</Constant>
```

### 1.3 IF / ELSIF / ELSE / END_IF
- SCL：
  ```scl
  IF "I_EStop" THEN
      "Q_Run" := FALSE;
  ELSIF "I_Stop" THEN
      "Q_Run" := FALSE;
  ELSIF "I_Start" THEN
      "Q_Run" := TRUE;
  END_IF;
  ```
- 真实 XML 结构（每行用 `Token` + `Access` + `Blank` + `NewLine` 组合）：
  ```xml
  <Token Text="IF"/><Blank/><Access GlobalVariable I_EStop/><Blank/><Token Text="THEN"/><NewLine/>
    <Blank Num="2"/><Access GlobalVariable Q_Run/><Blank/><Token Text=":="/><Blank/>
    <Access LiteralConstant FALSE/><Token Text=";"/><NewLine/>
  <Token Text="ELSIF"/><Blank/>...<Token Text="THEN"/><NewLine/>
  ...
  <Token Text="END_IF"/><Token Text=";"/><NewLine/>
  ```
- Builder JSON：`{op:"if", condition:"\"I_EStop\""}` + `{op:"elsif", condition:"\"I_Stop\""}` + `{op:"endif"}` ✅

### 1.4 比较运算符（V21 XML 转义规则）
| SCL 写法 | XML 中 Token Text 应写 |
|---|---|
| `=` | `=` |
| `<>` | `&lt;&gt;` |
| `<` | `&lt;` |
| `>` | `&gt;` |
| `<=` | `&lt;=` |
| `>=` | `&gt;=` |

⚠️ **`<` / `>` 必须 XML 转义**，否则 schema 拒收。Builder 内部 `Escape()` 自动处理。

### 1.5 算术 / 逻辑运算符
- 算术：`+ - * /` 是直接 Token Text；`MOD` 也是 Token（运算符位置）
- 逻辑：`AND OR NOT XOR` 都是 Token
- 示例 `(a OR b) AND NOT c;`：
  ```xml
  <Token Text="("/><Access a/><Blank/><Token Text="OR"/><Blank/><Access b/><Token Text=")"/>
  <Blank/><Token Text="AND"/><Blank/><Token Text="NOT"/><Blank/><Access c/><Token Text=";"/>
  ```
- Builder JSON：`{op:"line", items:[...]}` ✅

### 1.6 赋值
- SCL：`#a := #b;`（局部）/ `"Q" := TRUE;`（全局赋字面）/ `"a" := "b";`（符号到符号）
- 真实 XML 结构：`<Access target/> <Blank/> <Token :=/> <Blank/> <Access source/> <Token ;/> <NewLine/>`
- Builder JSON：
  - 字面：`{op:"assignment", target:"\"Q\"", literalValue:"TRUE"}` ✅
  - 符号→符号：`{op:"assignment", target:"\"Q\"", source:"\"P\""}` ✅
  - 复杂表达式：`{op:"line", items:[...]}` ✅

### 1.7 CASE / OF / END_CASE
- SCL：
  ```scl
  CASE #state OF
      0:        // 单值
          #out := 0;
      1, 2:     // 多值
          #out := 1;
      3..10:    // 范围（V21 SCL 支持）
          #out := 2;
      ELSE
          #out := -1;
  END_CASE;
  ```
- ⚠️ **真实 XML 中 `..` 和 `,` 都是 Token Text**，但 V21 importer 对 `<Token Text=".."/>` **不接受作为 Token**，必须分两个 `Token Text="."` 或者作为 `<Range>` 元素。**当前 builder 按 line 拼会被拒**。
- Builder：受限。**先用单值或多值 `,`**，避免 `..` 范围

### 1.8 FOR / WHILE / REPEAT
- SCL：
  ```scl
  FOR #i := 1 TO 10 BY 1 DO
      #sum := #sum + #i;
  END_FOR;

  WHILE #i < 100 DO
      #i := #i + 1;
  END_WHILE;

  REPEAT
      #i := #i + 1;
  UNTIL #i > 50 END_REPEAT;
  ```
- XML：FOR/WHILE/REPEAT/EXIT/CONTINUE/RETURN 关键词都是 Token
- Builder：用 `line` op 手拼整行 ✅；FOR 已离线验证通过

### 1.9 函数调用 / 类型转换 ⚠️
**核心限制**：SCL 函数调用（`REAL_TO_DINT(x)`、`SQRT(x)`、`ABS(x)`、`MIN(a,b)` 等）真实 XML **必须**用 `<Access Scope="Call">` 包装：

```xml
<Access Scope="Call" UId="21">
  <CallInfo Name="REAL_TO_DINT" BlockType="Type">
    <Token Text="(" UId="22"/>
    <Parameter Name="" Section="Input" Type="Real">
      <Access GlobalVariable Tank_Level/>
    </Parameter>
    <Token Text=")" UId="..."/>
  </CallInfo>
</Access>
```

⚠️ **当前 builder 用 `{token:"REAL_TO_DINT"}` raw 写法 V21 拒收**（"The token is not supported"）。

**已知能用的简单替代**：
- 上下限直接 IF：`IF x > 100 THEN x := 100; END_IF;`
- 比较：`IF a >= 1000 THEN ...`
- 这些避免了类型转换函数调用

**待实现的 builder 功能**：`{op:"call", name:"REAL_TO_DINT", params:[{type:"Real", value:"\"Tank_Level\""}]}` 生成 Access Scope="Call" 包装。**v1.1 backlog**

### 1.10 FB 调用（多实例）

#### 1.10.1 SCL 中调用静态多实例 FB
- SCL：
  ```scl
  #instStartTRIG(CLK := #execute);   // 多实例 R_TRIG
  IF #instStartTRIG.Q THEN ... END_IF;
  ```
- 真实 XML（同 1.9 的 Call 模式，但 BlockType="FB"）：
```xml
<Access Scope="Call">
  <CallInfo Name="R_TRIG" BlockType="FB">
    <Instance Scope="LocalVariable" UId="22">
      <Component Name="instStartTRIG" UId="23"/>
    </Instance>
    <Token Text="("/>
    <Parameter Name="CLK" Section="Input" Type="Bool">
      <Access LocalVariable execute/>
    </Parameter>
    <Token Text=")"/>
  </CallInfo>
</Access>
```
- ⚠️ **builder 当前用 raw `{sym:"#trig"}, {raw:"("}, ...` 拼凑** —— 不会被 V21 当作 Call，schema 会失败
- **待实现**：`{op:"fbCall", name:"R_TRIG", instance:"#instStartTRIG", parameters:[{name:"CLK", section:"Input", type:"Bool", source:"#execute"}]}`

#### 1.10.2 静态成员声明多实例 FB
- 接口 Static 段写法（FB Static 节中）：
```xml
<Member Name="instStartTRIG" Datatype="R_TRIG">
  <AttributeList>
    <StringAttribute Name="InstructionName" SystemDefined="true">R_TRIG</StringAttribute>
    <StringAttribute Name="LibVersion"      SystemDefined="true">1.0</StringAttribute>
  </AttributeList>
</Member>
```
- ⚠️ **builder 当前 Static 成员只写 `Name+Datatype`**，不带 `InstructionName`/`LibVersion`，TIA import 会报"型号未知"
- **待实现**：`statics: [{name:"instStartTRIG", datatype:"R_TRIG", instruction:"R_TRIG", libVersion:"1.0"}]`

### 1.11 RETURN / EXIT / CONTINUE
- SCL：`RETURN;` / `EXIT;`（只能在 FOR/WHILE/REPEAT 内）/ `CONTINUE;`
- 都是 Token + `;` + NewLine ✅ builder 已支持（`{op:"line", items:[{token:"RETURN"}]}`）

---

## §2 LAD（FlgNet/v5）指令

### 2.1 网络结构
```xml
<FlgNet xmlns="http://www.siemens.com/automation/Openness/SW/NetworkSource/FlgNet/v5">
  <Parts>
    <!-- Access 节点：变量符号引用，UId 是它在网络内的标识 -->
    <Access Scope="..." UId="21">...</Access>
    <!-- Part 节点：触点/线圈/比较/MOVE/Timer/FC调用等可视化元件 -->
    <Part Name="Contact" UId="40" />
  </Parts>
  <Wires>
    <!-- 每根连线连接两个端点（Powerrail / NameCon / IdentCon） -->
    <Wire UId="54">
      <Powerrail/>                          <!-- 起点：母线 -->
      <NameCon UId="40" Name="in"/>         <!-- 终点：Part 40 的 in 引脚 -->
    </Wire>
  </Wires>
</FlgNet>
```

### 2.2 三种 Wire 端点
- `<Powerrail/>` — 网络左母线（每个 LAD 网络起点）
- `<NameCon UId="X" Name="pinName"/>` — 接到 Part X 的命名引脚（如 `in`, `out`, `operand`, `en`, `eno`, 或 FC 形参名）
- `<IdentCon UId="X"/>` — 接到 Access X（变量符号），用于触点 operand / 线圈 operand / 形参实参

### 2.3 触点 NO（normally open）
- 用户语言："I_Start 的常开触点"
- LAD 形态：`├─┤I_Start├─`
- 真实 XML：
```xml
<Access Scope="GlobalVariable" UId="21">
  <Symbol><Component Name="I_Start"/></Symbol>
</Access>
<Part Name="Contact" UId="40" />

<Wire UId="54"><Powerrail/><NameCon UId="40" Name="in"/></Wire>           <!-- 母线→触点 in -->
<Wire UId="55"><IdentCon UId="21"/><NameCon UId="40" Name="operand"/></Wire><!-- 变量→触点 operand -->
<Wire UId="56"><NameCon UId="40" Name="out"/>...</Wire>                    <!-- out→下一段 -->
```
- Builder：**当前 LAD composer 不支持 Contact**，只支持 FC Call。**v1.1 backlog**

### 2.4 触点 NC（normally closed）
- LAD 形态：`├─┤/├─`
- 真实 XML：在 NO 触点 Part 内加 `<Negated Name="operand"/>`：
```xml
<Part Name="Contact" UId="41">
  <Negated Name="operand" />
</Part>
```
- 其余 Wire 同 NO

### 2.5 输出线圈 Coil
- LAD 形态：`──( Q_Run )`
- 真实 XML：
```xml
<Part Name="Coil" UId="45" />

<Wire><NameCon UId="44" Name="eno"/><NameCon UId="45" Name="in"/></Wire>
<Wire><IdentCon UId="..."/><NameCon UId="45" Name="operand"/></Wire>
```

### 2.6 Set / Reset 线圈
- LAD 形态：`──( S )` / `──( R )`
- 真实 XML：`<Part Name="SCoil" />` / `<Part Name="RCoil" />`，wire 同 Coil

### 2.7 串联（AND）
- 多个 Contact 串接：`├─┤A├──┤B├──( Y )`
- Wire 链：`Powerrail → A.in → A.out → B.in → B.out → Coil.in`，每个 operand 单独线
```xml
<Wire><Powerrail/><NameCon UId="40" Name="in"/></Wire>
<Wire><NameCon UId="40" Name="out"/><NameCon UId="41" Name="in"/></Wire>
<Wire><NameCon UId="41" Name="out"/><NameCon UId="45" Name="in"/></Wire>
```

### 2.8 并联（OR）
- 真实样本里用 `<Part Name="O" />` 节点（OR junction）汇合分支：
```xml
<Part Name="O" UId="50" />
<Wire><Powerrail/><NameCon UId="40" Name="in"/></Wire>      <!-- branch 1 起 -->
<Wire><NameCon UId="40" Name="out"/><NameCon UId="50" Name="in1"/></Wire>
<Wire><Powerrail/><NameCon UId="42" Name="in"/></Wire>      <!-- branch 2 起 -->
<Wire><NameCon UId="42" Name="out"/><NameCon UId="50" Name="in2"/></Wire>
<Wire><NameCon UId="50" Name="out"/><NameCon UId="45" Name="in"/></Wire>
```

### 2.9 比较盒子 Eq / Ne / Lt / Gt / Le / Ge
- LAD 形态：`├──[ Eq ]──┐` 两输入一输出
- Part Name 候选：`Eq`, `Ne`, `Lt`, `Gt`, `Le`, `Ge`
- 引脚：`in1`, `in2`, `out`
```xml
<Part Name="Eq" UId="60">
  <TemplateValue Name="SrcType" Type="Type">Int</TemplateValue>
</Part>
<Wire><NameCon UId="59" Name="out"/><NameCon UId="60" Name="in1"/></Wire>
<Wire><IdentCon UId="22"/><NameCon UId="60" Name="in2"/></Wire>          <!-- 比较第二个操作数 -->
<Wire><NameCon UId="60" Name="out"/><NameCon UId="61" Name="in"/></Wire>
```

### 2.10 范围比较 InRange / OutRange
- Part Name `InRange` / `OutRange`，三引脚：`val`, `min`, `max`, `out`

### 2.11 MOVE 盒子
- LAD：`──[ MOVE EN ENO ]──`
- 真实 XML：
```xml
<Part Name="Move" UId="44" DisabledENO="true">
  <TemplateValue Name="Card" Type="Cardinality">1</TemplateValue>
</Part>
<Wire><NameCon UId="..." Name="..."/><NameCon UId="44" Name="en"/></Wire>      <!-- en 输入 -->
<Wire><IdentCon UId="..."/><NameCon UId="44" Name="in"/></Wire>                 <!-- 源数据 -->
<Wire><NameCon UId="44" Name="out1"/><IdentCon UId="..."/></Wire>               <!-- 目标 -->
<Wire><NameCon UId="44" Name="eno"/><NameCon UId="next" Name="in"/></Wire>      <!-- ENO 串下一个 -->
```
- `Card`（基数）= 输出引脚个数；MOVE 一般为 1

### 2.12 定时器 TON / TOF / TP
- 真实 XML：
```xml
<Part Name="TON" UId="70" Version="1.0" />
<Wire><NameCon UId="40" Name="out"/><NameCon UId="70" Name="IN"/></Wire>
<Wire><IdentCon UId="literal_T1S"/><NameCon UId="70" Name="PT"/></Wire>
<Wire><NameCon UId="70" Name="Q"/><NameCon UId="80" Name="in"/></Wire>
<Wire><NameCon UId="70" Name="ET"/><IdentCon UId="elapsed_var"/></Wire>
```
- ⚠️ **TON Part 在 LAD 中通常需要一个实例 DB**（IEC_Timer_X_DB），而 V21 的 IEC Timer Part 内嵌了 Static 实例引用 —— 仍需在 FB Static 节声明对应成员

### 2.13 边沿检测 R_TRIG / F_TRIG
- Part Name="R_Trig" 或 "F_Trig"
- 一引脚 CLK、一引脚 Q
- 同样需要 FB Static 实例

### 2.14 FC 调用（不带参数）
- 真实 XML：
```xml
<Access Scope="Call" UId="21">
  <CallInfo BlockType="FC">
    <Instance Scope="GlobalVariable" UId="24">
      <Component Name="00-输入映射" UId="23" />
    </Instance>
    <Token Text="("/>
    <Token Text=")"/>
  </CallInfo>
</Access>
```
- Builder：✅ `ComposePlcLadFcBlockXml networks[].callJson{callName, parameters:[]}` 已支持

### 2.15 FC 调用（带参数）
```xml
<Access Scope="Call">
  <CallInfo Name="MyFC" BlockType="FC">
    <Token Text="("/>
    <Parameter Name="x" Section="Input" Type="Int">
      <Access LocalVariable a/>
    </Parameter>
    <Token Text=","/>
    <Parameter Name="y" Section="Input" Type="Bool">
      <Access GlobalVariable Q_Run/>
    </Parameter>
    <Token Text=")"/>
  </CallInfo>
</Access>
```
- Builder：✅ `parameters: [{name, section, dataType, sourceKind, symbolPath / value}]` 已支持

### 2.16 FB 调用（带实例 DB）
```xml
<Access Scope="Call">
  <CallInfo Name="FB_X" BlockType="FB">
    <Instance Scope="GlobalVariable">
      <Component Name="DB_FB_X_Instance" />
    </Instance>
    <Token Text="("/>
    <Parameter Name="In1" Section="Input" Type="Bool">
      <Access GlobalVariable I_Start/>
    </Parameter>
    <Token Text=")"/>
  </CallInfo>
</Access>
```
- Builder：⚠️ 当前只 FC 支持；**FB 调用 + 实例 DB 待补**

---

## §3 当前 Builder JSON 全量速查（2026-05-10 verified）

### 3.1 SCL `op` 列表（structuredText.operations）

| op | 字段 | 说明 |
|---|---|---|
| `if` | `condition` | IF cond THEN |
| `elsif` | `condition` | ELSIF cond THEN |
| `else` | — | ELSE |
| `endif` | `indent?` | END_IF; |
| `assignment` | `target` + (`literalValue` 或 `source`) | 赋值字面量或符号 |
| `token` | `text` | 单 Token，前后默认不加 Blank |
| `blank` | `count?` | n 个 Blank |
| `newline` | — | NewLine |
| `local` | `name` | LocalVariable 多段（`.` 拆段）|
| `global` | `name` | GlobalVariable 多段 |
| `symbol` | `name` | 智能识别（含 `"` → 全局）|
| `literal` | `value` | LiteralConstant |
| `line` | `items[]` 含 `sym` / `token` / `lit` / `raw` | 自由表达式行，自动末尾 ; + newline |

通用 `indent?` 字段：插入 N 个前置 Blank（缩进）。

### 3.2 Builder 当前**不支持**（v1.1 backlog）
1. SCL 函数调用 `<Access Scope="Call" BlockType="Type">`（`REAL_TO_DINT`、`SQRT`、`ABS` 等）
2. SCL FB 多实例调用 `<Access Scope="Call" BlockType="FB"><Instance>`（`#trig(CLK:=...)`）
3. CASE 范围 `1..100`（V21 拒 `<Token Text=".."/>`）
4. FB Static 节声明系统 FB 实例（`R_TRIG` / `TON` 类型 + `InstructionName` 属性）
5. LAD Contact / Coil / 比较盒子 / MOVE / Timer Part（FlgNet 真正梯形图）—— 当前只能 FC Call
6. SCL 内联注释（v4 schema 不带 Comment token，inline `//` 走 .scl 文本）

### 3.3 Builder 已支持
1. SCL：变量（局部/全局/多段）+ 字面（Bool/Int/Real/Time/字符串）+ IF/ELSIF/ELSE/END_IF + 赋值（字面/符号）+ 比较运算（含 V21 转义）+ 算术 + AND/OR/NOT + 自由表达式 line + RETURN/EXIT/CONTINUE
2. 块级 + 网络级中文注释（MultilingualText）
3. 接口成员中文注释（UDT 已通；FB/FC 通过 builder 也支持）
4. UDT（hand-craft + builder）
5. PLC Tag Table（builder）
6. GlobalDB（builder + 中文成员注释）
7. SCL FC（builder + 6 大 op + 中文注释 + 全 UID 自动）
8. SCL FB（builder + 同上）
9. LAD FC 调用 FC（builder ComposePlcLadFcBlockXml）

---

## §4 给后续 AI 模型的"自然语言→builder JSON"映射模板

### 4.1 用户说："我要写一个起保停 FC，叫 FC_StartStop，10 号"
```json
PlcBuildAndImport softwarePath="PLC_1" kind="fc" json={
  "blockName":"FC_StartStop", "blockNumber":10,
  "commentZhCn":"...", "titleZhCn":"...",
  "inputs":[], "outputs":[],
  "structuredText":{ "operations":[
    {"op":"if",        "condition":"\"I_EStop\""},
    {"op":"assignment","target":"\"Q_Run\"","literalValue":"FALSE","indent":2},
    {"op":"elsif",     "condition":"\"I_Stop\""},
    {"op":"assignment","target":"\"Q_Run\"","literalValue":"FALSE","indent":2},
    {"op":"elsif",     "condition":"\"I_Start\""},
    {"op":"assignment","target":"\"Q_Run\"","literalValue":"TRUE", "indent":2},
    {"op":"endif"}
  ]}
} dryRun=false
```

### 4.2 用户说："写个液位限幅 FC，把 Tank_Level 限制在 0~100"
```json
{ "blockName":"FC_Clamp", "blockNumber":13,
  "commentZhCn":"液位限幅 0~100",
  "structuredText":{ "operations":[
    {"op":"line", "items":[{"token":"IF"},{"sym":"\"Tank_Level\""},{"token":">"},{"lit":"100.0"},{"token":"THEN"}]},
    {"op":"assignment","target":"\"Tank_Level\"","literalValue":"100.0","indent":2},
    {"op":"line", "items":[{"token":"END_IF"},{"token":";"}]},
    {"op":"line", "items":[{"token":"IF"},{"sym":"\"Tank_Level\""},{"token":"<"},{"lit":"0.0"},{"token":"THEN"}]},
    {"op":"assignment","target":"\"Tank_Level\"","literalValue":"0.0","indent":2},
    {"op":"line", "items":[{"token":"END_IF"},{"token":";"}]}
  ]}
}
```

### 4.3 用户说："写个高液位报警 FC，用 DB 里的阈值 HighLimit"
```json
{ "blockName":"FC_HighAlarm", "blockNumber":14,
  "structuredText":{ "operations":[
    {"op":"line", "items":[
      {"token":"IF"}, {"sym":"\"Tank_Level\""}, {"token":">="}, {"sym":"\"DB_Tank\".HighLimit"}, {"token":"THEN"}
    ]},
    {"op":"assignment","target":"\"DB_Tank\".AlarmHigh","literalValue":"TRUE","indent":2},
    {"op":"line", "items":[{"token":"END_IF"},{"token":";"}]}
  ]}
}
```

### 4.4 用户说："计数器加 1"
```json
{"op":"line", "items":[
  {"sym":"\"DB_X\".Counter"}, {"token":":="},
  {"sym":"\"DB_X\".Counter"}, {"token":"+"}, {"lit":"1"}, {"token":";"}
]}
```

### 4.5 用户说："位移寄存器 4 位"
```json
[
  {"op":"assignment","target":"\"Q4\"","source":"\"Q3\""},
  {"op":"assignment","target":"\"Q3\"","source":"\"Q2\""},
  {"op":"assignment","target":"\"Q2\"","source":"\"Q1\""},
  {"op":"assignment","target":"\"Q1\"","source":"\"Q_Init\""}
]
```

---

## §5 限制汇总（明确告诉用户什么做不到）

| 用户描述 | builder 当前 | 解决路径 |
|---|---|---|
| "把 Real 转 DInt" | ❌ raw `REAL_TO_DINT(...)` token V21 拒 | 等 builder 实现 Access Scope="Call" |
| "用 R_TRIG 检测上升沿" | ❌ FB 多实例调用 builder 没出 | 等 fbCall + Static InstructionName |
| "用 TON 做延时" | ❌ 同上 | 同上 |
| "CASE 用 1..100 范围" | ❌ V21 拒 `..` token | 用单值 + 多值 `,` 列举或 IF 替代 |
| "在 SCL 代码里加 `// 注释`" | ❌ v4 schema 没 Comment token | 用块/网络/成员级 MultilingualText 表达 |
| "我要画一个 LAD 网络：触点 + 线圈" | ❌ LAD composer 只支持 FC 调用 | 等 LAD 真梯形图 builder |
| "HMI Connection 自动建" | ❌ V21 Openness 不会随 PROFINET 自动建 | 手工 export 一份连接 XML 当模板 + ImportHmiConnection |
| "导入 HMI 画面（含 TextField）" | ❌ V21 KTP700 schema 严，逐属性踩 | 重写 BuildClassicHmiScreenXml 严格仿真实导出 |

---

## 附录 A：UId 分配约定
- 一个网络内全局唯一，从 21 开始递增
- 跨 CompileUnit 不重置（同一个块内 UId 累加）
- 块级 ID（MultilingualText/CompileUnit）用十六进制（"1","2","3"，".."Hex 后跳到 "A","B"...）
- HMI Screen 用 hex（"A","B","C","D"...）

## 附录 B：必看的真实样本（学习参考）
| 文件 | 看什么 |
|---|---|
| `TMP_EXPORT/Source/5T车/Blocks/01_手动控制/FC控制/02-大车控制.xml` | LAD: Contact 串联 + Coil + 比较 Eq + Move |
| `TMP_EXPORT/Source/5T车/Blocks/01_手动控制/FC控制/00-输入映射.xml` | LAD: 系统 FC 调用（DPRD_DAT/DPWR_DAT）+ Wire 接形参 |
| `TMP_EXPORT/Source/5T车/Blocks/FB_AntiSway_SpeedCtl.scl` | SCL: R_TRIG / TON_TIME 多实例 Static 声明 + 调用 |
| `TMP_EXPORT/Source/5T车/Datatypes/UDT_Fault.xml` | UDT: Member + Bool + 中文注释 |
| `TMP_EXPORT/Source/5T车/Tags/默认变量表.xml` | PLC Tag Table: %M/%I/%Q 各类地址 |
| `TMP_EXPORT/optimized_hmi/Screens/主画面_优化.xml` | HMI Classic: TextField/Button/IOField + Events SetBit/ResetBit |
