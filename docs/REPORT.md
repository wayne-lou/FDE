# Demo 结果记录

5 个主题，每个主题生成 beauty / balanced 两版。默认 balanced 25 页，beauty 28 页。

| # | Topic | Mode | Slide Count | Theme | Duration | Estimated Cost | Output File | Quality Note |
|---:|---|---|---:|---|---:|---:|---|---|
| 1 | Python 入门：从零到做出第一个自动化脚本 | beauty | 28 | 教育清爽 | 待测 | 0 / OpenAI 低成本 | 待生成 | 包含变量、循环、函数、列表、字典、自动化脚本 |
| 2 | Python 入门：从零到做出第一个自动化脚本 | balanced | 25 | 教育清爽 | 待测 | 0 / OpenAI 低成本 | python_smoke.pptx | 已完成 25 页烟测 |
| 3 | 个人年度复盘：从结果、反思到下一年计划 | beauty | 28 | 极简白 | 待测 | 0 / OpenAI 低成本 | 待生成 | 年度主线、三件成果、三个坑、明年计划 |
| 4 | 个人年度复盘：从结果、反思到下一年计划 | balanced | 25 | 极简白 | 待测 | 0 / OpenAI 低成本 | 待生成 | 适合个人或团队复盘分享 |
| 5 | 如何选择适合自己的咖啡豆 | beauty | 28 | 咖啡暖色 | 待测 | 0 / OpenAI 低成本 | 待生成 | 烘焙度、产地、处理法、风味轮、购买框架 |
| 6 | 如何选择适合自己的咖啡豆 | balanced | 25 | 咖啡暖色 | 待测 | 0 / OpenAI 低成本 | 待生成 | 更短的消费决策框架 |
| 7 | Rust 重构订单系统：给 CEO 的投资回报论证 | beauty | 28 | 商务深色 | 待测 | 0 / OpenAI 低成本 | 待生成 | 业务损失、性能瓶颈、风险、ROI、立项路径 |
| 8 | Rust 重构订单系统：给 CEO 的投资回报论证 | balanced | 25 | 商务深色 | 待测 | 0 / OpenAI 低成本 | 待生成 | 管理层决策简报结构 |
| 9 | 京都两天旅行路线：从清水寺到岚山 | beauty | 28 | 旅行杂志 | 待测 | 0 / OpenAI 低成本 | 待生成 | Day1/Day2 时间线、路线、预算、交通 |
| 10 | 京都两天旅行路线：从清水寺到岚山 | balanced | 25 | 旅行杂志 | 待测 | 0 / OpenAI 低成本 | 待生成 | 轻量路线说明 |

## 验收项

- 页面无前端 API Key 输入框。
- API Key 只在 `Application.cfc` 服务端配置。
- 无 Node / Python / npm 依赖。
- 浏览器生成 PPTX。
- OpenAI 只生成 Slide Spec。
- OpenAI 失败时使用本地高质量 fallback spec。
- PPT 至少 25 页。
- Python 示例内容具体，不再复读“核心观点先行”等泛泛话术。
- PPT 内无乱码式英文缩写。
- Metrics 显示生成耗时。

## 当前 smoke test

已用本地 Node 模拟浏览器 Blob 环境生成：

```text
Demo_PPT/output/python_smoke.pptx
slides: 25
size: 299407 bytes
```

该测试仅用于验证浏览器 PPTX 打包逻辑，服务器运行不需要 Node。
