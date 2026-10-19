#!/usr/bin/env python3
"""Generate the Nook documentation diagrams.

Each diagram is plain data. The script writes an editable .drawio file and
exports a 2x PNG with the local draw.io desktop CLI. Keeping the source here
means the diagrams can be reviewed and regenerated like code.
"""

from __future__ import annotations

import html
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "docs" / "assets"
DRAWIO = Path("/Applications/draw.io.app/Contents/MacOS/draw.io")

BOX = (
    "rounded=1;whiteSpace=wrap;html=1;arcSize=12;"
    "fillColor=#F5F5F7;strokeColor=#D1D1D6;fontColor=#1D1D1F;fontSize=12;"
)
ACCENT = (
    "rounded=1;whiteSpace=wrap;html=1;arcSize=12;"
    "fillColor=#EAF2FF;strokeColor=#007AFF;fontColor=#1D1D1F;fontSize=12;"
)
DARK = (
    "rounded=1;whiteSpace=wrap;html=1;arcSize=12;"
    "fillColor=#007AFF;strokeColor=#0071E3;fontColor=#FFFFFF;fontSize=12;"
)
WHITE = (
    "rounded=1;whiteSpace=wrap;html=1;arcSize=12;"
    "fillColor=#FFFFFF;strokeColor=#E5E5EA;fontColor=#1D1D1F;fontSize=12;"
)
BAND = (
    "rounded=1;whiteSpace=wrap;html=1;arcSize=10;"
    "fillColor=#FAFAFC;strokeColor=#E5E5EA;fontColor=#6E6E73;fontSize=11;"
    "verticalAlign=top;align=left;spacingLeft=12;spacingTop=8;"
)
TITLE = (
    "text;html=1;align=left;verticalAlign=middle;"
    "fontSize=18;fontStyle=1;fontColor=#1D1D1F;"
)
CAPTION = "text;html=1;align=left;verticalAlign=middle;fontSize=11;fontColor=#6E6E73;"
EDGE = (
    "edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;"
    "strokeColor=#8E8E93;strokeWidth=1.5;fontSize=10;fontColor=#515154;"
    "labelBackgroundColor=#FFFFFF;endArrow=block;endFill=1;"
)
DASHED = (
    "edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;dashed=1;"
    "strokeColor=#C7C7CC;strokeWidth=1;endArrow=none;"
)
LIFELINE = "endArrow=none;dashed=1;strokeColor=#D1D1D6;strokeWidth=1;"


def esc(text: str) -> str:
    return html.escape(text).replace("\n", "&lt;br&gt;")


class Diagram:
    def __init__(self, name: str, width: int, height: int):
        self.name = name
        self.width = width
        self.height = height
        self.cells: list[str] = []
        self.index = 0

    def node(
        self,
        label: str,
        x: int,
        y: int,
        w: int,
        h: int,
        style: str = BOX,
    ) -> str:
        self.index += 1
        node_id = f"n{self.index}"
        self.cells.append(
            f'<mxCell id="{node_id}" value="{esc(label)}" style="{style}" vertex="1" parent="1">'
            f'<mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry"/>'
            f"</mxCell>"
        )
        return node_id

    def edge(
        self,
        source: str,
        target: str,
        label: str = "",
        style: str = EDGE,
        points: list[tuple[int, int]] | None = None,
    ) -> None:
        self.index += 1
        geometry = '<mxGeometry relative="1" as="geometry">'
        if points:
            geometry += '<Array as="points">'
            for x, y in points:
                geometry += f'<mxPoint x="{x}" y="{y}"/>'
            geometry += "</Array>"
        geometry += "</mxGeometry>"
        self.cells.append(
            f'<mxCell id="e{self.index}" value="{esc(label)}" style="{style}" edge="1" parent="1" '
            f'source="{source}" target="{target}">{geometry}</mxCell>'
        )

    def xml(self) -> str:
        body = "".join(self.cells)
        return (
            '<mxfile host="app.diagrams.net">'
            f'<diagram id="{self.name}" name="{self.name}">'
            f'<mxGraphModel dx="1200" dy="800" grid="0" gridSize="8" guides="1" tooltips="1" '
            f'connect="1" arrows="1" fold="1" page="1" pageScale="1" '
            f'pageWidth="{self.width}" pageHeight="{self.height}" math="0" shadow="0">'
            "<root>"
            '<mxCell id="0"/><mxCell id="1" parent="0"/>'
            f"{body}"
            "</root></mxGraphModel></diagram></mxfile>"
        )


def doc_map() -> Diagram:
    d = Diagram("doc-map", 1000, 320)
    d.node("60 分钟阅读路线", 40, 20, 420, 40, TITLE)
    boxes = [
        ("0–5 分钟\n01 产品说明", 40, 110),
        ("5–15 分钟\n02 快速开始", 360, 110),
        ("15–25 分钟\n03 概念与术语", 680, 110),
        ("25–40 分钟\n04 架构", 680, 240),
        ("40–50 分钟\n05 设计系统", 360, 240),
        ("50–60 分钟\n06 开发指南", 40, 240),
    ]
    ids = [d.node(label, x, y, 260, 80, ACCENT if i in (0, 3) else BOX) for i, (label, x, y) in enumerate(boxes)]
    for a, b in zip(ids, ids[1:]):
        d.edge(a, b, "")
    return d


def architecture() -> Diagram:
    d = Diagram("architecture", 1120, 780)
    d.node("Nook 的五层结构", 40, 20, 500, 40, TITLE)
    bands = [
        ("界面层 · 只负责显示和输入", 80, ["编辑窗口", "提词面板", "菜单栏", "AI 设置"]),
        ("控制器层 · 组装窗口与命令", 210, ["AppDelegate", "EditorCoordinator", "菜单与状态栏", "快捷键路由"]),
        ("状态层 · 保存可观察状态", 340, ["AppModel", "AISettingsModel", "PlaybackEngine", "InspectorState"]),
        ("领域层 · NookKit 纯逻辑", 470, ["分词与计划", "排版与合成", "AI 协调", "prompt 与校验"]),
        ("基础设施 · 系统能力", 600, ["UserDefaults", "Keychain", "URLSession", "文件缓存"]),
    ]
    band_ids = []
    for label, y, items in bands:
        band = d.node(label, 60, y, 1000, 100, BAND)
        band_ids.append(band)
        for i, item in enumerate(items):
            d.node(item, 90 + i * 240, y + 36, 220, 48, WHITE)
    for a, b in zip(band_ids, band_ids[1:]):
        d.edge(a, b, "依赖", DASHED.replace("endArrow=none", "endArrow=block;endFill=1;strokeColor=#8E8E93;strokeWidth=1.5"))
    d.node("箭头表示依赖方向。上层依赖下层，领域层不依赖界面。", 60, 720, 1000, 30, CAPTION)
    return d


def data_flow() -> Diagram:
    d = Diagram("data-flow", 1080, 540)
    d.node("一次编辑到播放的数据流", 40, 20, 600, 40, TITLE)
    script = d.node("讲稿\nscript", 40, 220, 150, 64, DARK)
    tokenizer = d.node("分词器\nTokenizer", 230, 220, 160, 64, BOX)
    plan = d.node("断句计划\nPhrasePlan", 430, 220, 170, 64, ACCENT)
    composer = d.node("合成器\nComposer", 640, 220, 150, 64, BOX)
    document = d.node("提词文档\nPromptDocument", 830, 220, 190, 64, ACCENT)
    ai = d.node("云端 AI\n只返回编号", 430, 80, 170, 64, BOX)
    local = d.node("本地规则\nHeuristic", 430, 360, 170, 64, BOX)
    panel = d.node("提词面板\nPanel", 830, 380, 190, 64, BOX)
    engine = d.node("播放引擎\nPlaybackEngine", 620, 380, 170, 64, BOX)

    d.edge(script, tokenizer)
    d.edge(tokenizer, plan)
    d.edge(ai, plan, "校验通过")
    d.edge(local, plan, "无密钥")
    d.edge(plan, composer)
    d.edge(composer, document)
    d.edge(document, panel, "歌词与时间")
    d.edge(engine, panel, "进度")
    d.node("文字只来自本地分词器。AI 只改变分组。", 40, 470, 600, 30, CAPTION)
    return d


def start_sequence() -> Diagram:
    d = Diagram("start-sequence", 1280, 640)
    d.node("一次 Start 的调用顺序", 40, 20, 500, 40, TITLE)
    lanes = [("用户", 110), ("菜单 / 工具栏", 330), ("协调器", 570), ("AppModel", 810), ("提词面板", 1120)]
    for label, center in lanes:
        d.node(label, center - 85, 70, 170, 44, DARK if label == "AppModel" else BOX)
        d.node("", center - 1, 114, 2, 500, LIFELINE)

    def message(x1: int, x2: int, y: int, label: str) -> None:
        d.index += 1
        style = "html=1;endArrow=block;endFill=1;strokeColor=#8E8E93;strokeWidth=1.5;"
        geometry = (
            '<mxGeometry relative="1" as="geometry">'
            f'<mxPoint x="{x1}" y="{y}" as="sourcePoint"/>'
            f'<mxPoint x="{x2}" y="{y}" as="targetPoint"/>'
            "</mxGeometry>"
        )
        d.cells.append(
            f'<mxCell id="m{d.index}" value="" style="{style}" edge="1" parent="1">'
            f"{geometry}</mxCell>"
        )
        middle = (x1 + x2) // 2
        d.node(
            label,
            middle - 80,
            y - 22,
            160,
            18,
            "text;html=1;align=center;verticalAlign=middle;fontSize=10;fontColor=#515154;",
        )

    message(110, 330, 170, "⌘↩ / Start")
    message(330, 570, 220, "start()")
    message(570, 810, 270, "prepareForStart")
    d.node(
        "读取密钥 / 请求 AI\n校验计划 / 写入文档",
        820,
        305,
        190,
        54,
        "rounded=1;whiteSpace=wrap;html=1;arcSize=8;fillColor=#FFFBEB;strokeColor=#E5C07B;fontColor=#515154;fontSize=10;dashed=1;",
    )
    message(810, 570, 390, "ready")
    message(570, 330, 440, "隐藏")
    message(570, 1120, 490, "show()")
    message(1120, 110, 540, "READY / 播放")
    return d


def ai_state() -> Diagram:
    d = Diagram("ai-state", 960, 640)
    d.node("AI 断句状态机", 40, 20, 420, 40, TITLE)
    d.node("idle\n空闲", 60, 240, 170, 64, BOX)
    d.node("planning\n请求中", 330, 240, 170, 64, ACCENT)
    d.node("ready\n可播放", 640, 240, 170, 64, BOX)
    d.node("failed\n失败", 330, 420, 170, 64, BOX)

    label_style = "text;html=1;align=center;verticalAlign=middle;fontSize=10;fontColor=#515154;"

    def arrow(points: list[tuple[int, int]]) -> None:
        d.index += 1
        (x1, y1), (x2, y2) = points[0], points[-1]
        style = "html=1;edgeStyle=none;endArrow=block;endFill=1;strokeColor=#8E8E93;strokeWidth=1.5;"
        geometry = (
            '<mxGeometry relative="1" as="geometry">'
            f'<mxPoint x="{x1}" y="{y1}" as="sourcePoint"/>'
            f'<mxPoint x="{x2}" y="{y2}" as="targetPoint"/>'
        )
        if len(points) > 2:
            geometry += '<Array as="points">'
            for x, y in points[1:-1]:
                geometry += f'<mxPoint x="{x}" y="{y}"/>'
            geometry += "</Array>"
        geometry += "</mxGeometry>"
        d.cells.append(
            f'<mxCell id="s{d.index}" value="" style="{style}" edge="1" parent="1">{geometry}</mxCell>'
        )

    def label(text: str, x: int, y: int, width: int = 150) -> None:
        d.node(text, x, y, width, 18, label_style)

    arrow([(230, 272), (330, 272)])
    label("Start + 密钥", 210, 210, 160)

    arrow([(500, 272), (640, 272)])
    label("校验通过", 510, 210, 120)

    arrow([(415, 304), (415, 420)])
    label("超时 / 错误", 430, 348, 130)

    arrow([(350, 420), (350, 304)])
    label("Retry AI", 205, 348, 120)

    arrow([(500, 452), (760, 452), (760, 304)])
    label("Start locally", 590, 462, 140)

    arrow([(720, 304), (720, 545), (140, 545), (140, 304)])
    label("编辑讲稿", 400, 530, 120)

    arrow([(140, 240), (140, 120), (720, 120), (720, 240)])
    label("无密钥 / 本地", 400, 104, 150)

    d.node("失败不会静默降级。用户可以选择重试或本地开始。", 40, 590, 700, 30, CAPTION)
    return d


def ui_anatomy() -> Diagram:
    d = Diagram("ui-anatomy", 1200, 780)
    d.node("主界面结构", 40, 20, 420, 40, TITLE)
    d.node("", 40, 70, 1120, 660, "rounded=1;whiteSpace=wrap;html=1;arcSize=2;fillColor=#F5F5F7;strokeColor=#D1D1D6;")
    d.node("① 工具栏 · 品牌 / AI 状态 / 检查器 / 设置 / Start", 60, 90, 1080, 56, WHITE)
    d.node("② 标题与统计", 80, 170, 700, 60, WHITE)
    d.node("③ 稿纸（可滚动）", 80, 250, 700, 300, "rounded=1;whiteSpace=wrap;html=1;arcSize=2;fillColor=#FFFFFF;strokeColor=#E5E5EA;dashed=1;fontColor=#6E6E73;fontSize=12;")
    d.node("④ 呼吸图", 80, 570, 700, 60, WHITE)
    d.node("⑤ 检查器", 810, 170, 310, 460, WHITE + "verticalAlign=top;spacingTop=14;")
    for i, label in enumerate(["Phrasing", "Pace", "Appearance", "Privacy"]):
        d.node(label, 830, 250 + i * 90, 270, 56, BOX)
    d.node("⑥ 状态栏 · 语速 / 时长 / 快捷键", 60, 650, 1080, 56, WHITE)
    d.node("编号对应 05 设计系统里的区域表。", 40, 740, 600, 30, CAPTION)
    return d


def build_pipeline() -> Diagram:
    d = Diagram("build-pipeline", 1120, 360)
    d.node("从源文件到可运行应用", 40, 20, 500, 40, TITLE)
    nodes = [
        ("Sources/\n*.swift", 40),
        ("find\n收集文件", 220),
        ("swiftc\n编译", 400),
        ("Nook\n二进制", 580),
        (".app\nplist + icon", 760),
        ("codesign\ndist/Nook.app", 940),
    ]
    ids = [d.node(label, x, 130, 150, 76, DARK if i == 2 else BOX) for i, (label, x) in enumerate(nodes)]
    for a, b in zip(ids, ids[1:]):
        d.edge(a, b)
    d.node("构建脚本按目录收集源文件，新增子目录不需要修改脚本。", 40, 260, 800, 30, CAPTION)
    return d


DIAGRAMS = [
    doc_map,
    architecture,
    data_flow,
    start_sequence,
    ai_state,
    ui_anatomy,
    build_pipeline,
]


def main() -> int:
    if not DRAWIO.exists():
        print(f"draw.io not found at {DRAWIO}", file=sys.stderr)
        return 1
    ASSETS.mkdir(parents=True, exist_ok=True)
    for build in DIAGRAMS:
        diagram = build()
        source = ASSETS / f"{diagram.name}.drawio"
        target = ASSETS / f"{diagram.name}.png"
        source.write_text(diagram.xml(), encoding="utf-8")
        result = subprocess.run(
            [
                str(DRAWIO),
                "--export",
                "--format",
                "png",
                "--scale",
                "2",
                "--border",
                "12",
                "--output",
                str(target),
                str(source),
            ],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            print(f"export failed: {diagram.name}\n{result.stdout}\n{result.stderr}", file=sys.stderr)
            return 1
        print(f"exported {target.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
