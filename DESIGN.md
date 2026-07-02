# Demo_PPT 设计说明

## 架构目标

Demo_PPT 是一个浏览器端 PPTX 生成产品。服务器只负责 Lucee 页面、OpenAI 代理调用和 PostgreSQL 日志记录；浏览器负责表单交互、质量门禁、PPTX 渲染和文件下载。服务器不需要安装 Node、Python，也不需要 npm install。

数据流：

1. 用户输入 topic / brief / audience / mode / theme。
2. `api/prompt.cfm` 调用 OpenAI，生成可编辑的 Presentation Prompt。
3. 用户可以修改 Prompt。
4. `api/plan.cfm` 再次调用 OpenAI，生成 22-24 页 slide_spec。
5. 前端执行质量门禁：禁用词、重复标题、重复内容、连续 layout、页数不足都会失败。
6. `assets/pptx-browser.js` 使用确定性 OpenXML 渲染 PPTX。
7. `api/log.cfm` 写入 PostgreSQL：`ppt_jobs`、`ppt_runs`、`ppt_metrics`、`ppt_demo_results`。

## Template-driven，不是硬编码 Demo

5 个公开题目只作为输入样本：Python 入门、年度复盘、咖啡豆选择、Rust 订单系统、京都两日游。系统不会根据某个题目硬编码 slides，而是使用模板结构规则：

- `educational_course`：学习目标、概念地图、核心概念、例子、练习、小项目、常见错误、总结。
- `executive_proposal`：结论先行、业务问题、影响、方案、收益、风险、迁移计划、决策请求。
- `decision_guide`：决策问题、评价维度、选项、对比矩阵、推荐路径、避坑、总结。
- `travel_guide`：行程总览、Day1、Day2、交通、预算、拍照点、避坑、清单。
- `annual_review`：年度主线、成果、坑、转折、反思、下一年计划、总结。

这些规则约束故事线和页面类型，但具体内容由 OpenAI 根据用户输入动态生成。

## OpenAI 与成本

主链路必须使用 OpenAI。前端不显示 API Key；Key、模型和 API URI 均放在 `Application.cfc`：

- `application.openaiApiKey`
- `application.openaiModel`
- `application.openaiApiUri`

当前默认模型为 `gpt-4o-mini` 或配置值。成本估算使用：输入 $0.15 / 1M tokens，输出 $0.60 / 1M tokens。页面会显示 Prompt 阶段、Slide Spec 阶段和合计 tokens / cost / duration。

## 质量门禁

默认不自动 fallback。OpenAI 失败、JSON 解析失败、slide_spec 无效、页数不足、出现禁用模板话术，都会停止生成。前端最多对 slide_spec 质量失败 retry 一次；仍失败则报错，不下载 PPT。

禁用内容包括：形成清晰判断、具体执行建议、本页聚焦、听众看完、为什么重要、保留一个可复盘、把复杂内容变成清晰、解释XXX关系、继续判断等。

## Renderer 取舍

为了不依赖服务器运行时，PPTX 在浏览器生成。当前 renderer 使用最保守的 OpenXML 组件：文本框、矩形、线条、表格、基础布局和统一 footer。它避免复杂 shape、外部图片和不稳定关系文件，优先保证 PowerPoint 可打开。视觉上通过主题色、留白、章节页、时间线、矩阵、对比、卡片和大数字形成差异。

## 批量 Demo

页面提供“生成全部 Demo”按钮，按 5 个公开题目 × beauty/balanced 两种模式生成 10 个 PPT。每个 PPT 都走同一条 OpenAI 动态 planner 链路，并写入 PostgreSQL 指标表。
