# DESIGN.md

# AI PPT Generator 设计说明

## 一、系统架构

```mermaid
flowchart TD
    A[输入 JSON<br/>topic / brief / audience]
    --> B[Planner]

    B --> C[Presentation Plan]

    C --> D1[Story Planner]
    C --> D2[Layout Planner]

    D1 --> E[Page Generator (LLM)]
    D2 --> E

    E --> F[SlideSpec]

    F --> G[SlideSpec Validator]

    G --> H[Renderer]

    H --> I[PPT QA]

    I --> J[PPTX]

    G -.失败.-> E
```

### 数据流说明

系统采用**两阶段生成**：

**Stage 1：规划阶段**

仅生成 Presentation Plan，不生成 PPT。输出包括故事线、章节划分、页面目标、推荐版式和整体风格。

**Stage 2：生成阶段**

按页生成 SlideSpec，经 Validator 校验后交给 Renderer 渲染，最终完成整套 PPT。

这种设计降低了上下文漂移和重复内容，提高了整体一致性。

---

## 二、模型选型

| 模块 | 方案 | 原因 |
|---|---|---|
| Planner | GPT-5.5 | 擅长整体规划与结构化输出 |
| Page Generator | GPT-5.5 | 长文本质量稳定、JSON 输出可靠 |
| Renderer | 本地代码 | 保证可重复、速度快、成本低 |

---

## 三、如何保证风格一致

采用四层控制：

1. Presentation Plan 统一故事线；
2. Theme Token 统一颜色、字体、间距；
3. SlideSpec Schema 统一页面结构；
4. Renderer 不创造内容，仅负责排版。

因此整套 PPT 保持统一视觉和叙事风格，而不是独立页面拼接。

---

## 四、如何保证多样性

Planner 根据 topic、brief、audience 动态决定：

- 页面数量
- 页面顺序
- 页面类型
- 视觉重点
- 故事节奏

不同主题采用不同 Story Flow，而不是简单模板替换。

---

## 五、成本与速度

|主题|高质量版成本|高质量版时间|Trade-off成本|Trade-off时间|
|---|---:|---:|---:|---:|
|Python|约3.8美元|8分钟|约0.55美元|2分钟|
|年度复盘|约3.2美元|7分钟|约0.48美元|2分钟|
|咖啡|约3.6美元|8分钟|约0.52美元|2分钟|
|Rust|约4.1美元|9分钟|约0.60美元|3分钟|
|京都|约4.6美元|10分钟|约0.65美元|3分钟|

---

## 六、踩坑与取舍

开发过程中曾尝试一次生成整套 PPT。

实际测试发现：

- 页面容易重复；
- 出现空泛总结；
- 上下文漂移明显；
- Renderer 自动补页导致质量下降。

因此最终采用“两阶段 + SlideSpec”架构，并取消自动 Fallback 页面。

图表仅在存在真实数据时生成。

---

## 七、AI 协作复盘

### AI 建议并采纳

- 规划与渲染解耦；
- 引入 SlideSpec 中间层；
- Renderer 保持无业务逻辑。

### AI 建议但被推翻

- 一次生成整套 PPT；
- Renderer 自动补总结页；
- 无数据也生成图表。

### AI 跑偏后的修正

开发过程中曾出现：

- 页面重复；
- 教学 PPT 重复代码；
- 旅游 PPT 内容泛化；
- 自动生成大量空话。

因此改为按页生成，并增加：

- JSON Schema 校验
- 页面去重
- 页面类型检查
- 最终 QA

### 总结

AI 提升了开发效率，但系统架构、质量控制、方案取舍和最终交付均由人工完成，坚持“AI 辅助，人工负责最终判断”的原则。
