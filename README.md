
# aisay · 雨滴每日一语 (Rainmeter AI Quote)

一个 Rainmeter 桌面小部件。每天定时（或手动点击）让 AI 给你留一句话。
## 特性

- 支持任何 OpenAI 兼容的 API（官方、各种中转站、代理皆可）。
- 模型自动降级：当默认模型不可用（比如中转站跑路、模型下线）时，会自动弹窗让你选择备用模型，选完自动重试。
- 完全自定义人设：在 get_quote.ps1 里直接改 Prompt，想换成萌妹、管家还是霸道总裁随你。
- 自动/手动触发：每天 18:00 自动刷新，或者点一下皮肤立刻换一句。
- 极简 UI，自适应高度，不挡桌面。

## 安装方法

1. 下载本仓库，把 aisay 文件夹整个丢进你的 Rainmeter 皮肤目录：
   文档\Rainmeter\Skins\
2. 右键 Rainmeter 托盘图标 -> 刷新全部。
3. 在管理面板里找到 aisay，加载 aisay.ini。
4. 此时屏幕上会显示“点点看”，点击它就会触发 AI 生成。

## 首次配置（必读）

打开 aisay\get_quote.ps1，用文本编辑器（推荐 Notepad++ 或 VSCode）修改以下几处：

### 1. 填写 API 地址与 Key


$url = "https://你的服务商域名/v1/chat/completions"
$apiKey = "sk-在这里填你的API-Key"

### 2. 设置默认模型

$defaultModel = "你的-默认模型-全称"

必须填完整的模型全称，包括前缀（如 [反重力-0.025]gemini-3.7-flash），写错会触发弹窗让你重选。

### 3. 修改人设（Prompt）

找到 `$systemPrompt = @' ... '@` 这一段，把你想要的人设写进去。

建议保留“只输出一句话、不要解释、不要加引号”的限制，不然 AI 容易废话连篇。

### 重要：关于文件编码

必须将 get_quote.ps1 另存为 UTF-8 with BOM 编码！
Windows PowerShell 5.1 读取无 BOM 的 UTF-8 时会导致中文乱码（包括你的 Key、提示词和中文模型名）。
在 Notepad++ 中：编码 -> 转为 UTF-8-BOM 编码。

## 使用方法

- 自动：每天 18:00 自动生成一句。
- 手动：鼠标左键点击文字区域，立刻让 AI 重新生成。
- 生成的内容会写入 quote.txt，如果你觉得当前这句太那个，可以随时打开改掉（点一下又会变回去）。

## 常见问题

Q: 为什么点击后一直显示“他正在思考……”？
A: 可能是网络问题或 API 不通。脚本超时是 60 秒。如果彻底失败，quote.txt 会写入报错信息，皮肤上会直接显示出来。

Q: 弹窗选完模型后，下次还会弹吗？
A: 不会。你选的模型会自动保存在 model.txt 里，下次启动优先使用。想恢复默认模型，删掉 model.txt 即可。

Q: 能不能把“Xuyang”改成我自己的名字？
A: 当然。打开 aisay.ini，把 [MeterName] 里的 Text=Xuyang 改掉即可。

## License

MIT License. 随便改，随便玩。

