#!/usr/bin/env python3
"""Check Nook documentation against the project's STE-style rules.

The script is deliberately dependency-free. It measures what can be measured
without pretending to certify ASD-STE100 compliance.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = [
    ROOT / "README.md",
    ROOT / "docs" / "README.md",
    *sorted((ROOT / "docs").glob("0*.md")),
    ROOT / "docs" / "style-guide.md",
]

CJK = re.compile(r"[\u4e00-\u9fff]")
LATIN_WORD = re.compile(r"[A-Za-z0-9]+")
SENTENCE_SPLIT = re.compile(r"[。！？!?；;]")
FENCE = re.compile(r"^\s*```")
LINK = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
IMAGE = re.compile(r"!\[([^\]]*)\]\(([^)]+)\)")
H1 = re.compile(r"^#\s+")
H2 = re.compile(r"^##\s+")
ORDERED = re.compile(r"^\s*\d+[.、]\s*")
BULLET = re.compile(r"^\s*[-*]\s+")

PROCEDURE_VERBS = (
    "打开", "关闭", "运行", "点击", "选择", "输入", "粘贴", "按", "写", "添加",
    "修改", "设置", "安装", "启动", "保存", "检查", "读", "看", "进入", "退出",
    "复制", "删除", "创建", "填写", "确认", "等待", "回到", "发送", "记录",
)

BAD_PHRASES = ["予以", "加以", "进行", "；", ";"]
FORBIDDEN_TERMS = ["稿件", "台词", "悬浮窗", "播放文档", "分组方案", "快取", "提词行"]

@dataclass
class FileReport:
    path: Path
    sentences: int = 0
    long_sentences: list[str] = field(default_factory=list)
    long_paragraphs: list[str] = field(default_factory=list)
    bad_phrases: list[str] = field(default_factory=list)
    terms: list[str] = field(default_factory=list)
    broken_links: list[str] = field(default_factory=list)
    missing_images: list[str] = field(default_factory=list)
    missing_alt: list[str] = field(default_factory=list)
    structural: list[str] = field(default_factory=list)

    @property
    def clean(self) -> bool:
        return not (
            self.long_sentences
            or self.long_paragraphs
            or self.bad_phrases
            or self.terms
            or self.broken_links
            or self.missing_images
            or self.missing_alt
            or self.structural
        )


def sentence_length(text: str) -> int:
    """Count CJK characters plus Latin words; this is a stable proxy."""
    return len(CJK.findall(text)) + len(LATIN_WORD.findall(text))


def strip_markdown(text: str) -> str:
    text = re.sub(r"`[^`]*`", "", text)
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    text = re.sub(r"!\[[^\]]*\]\([^)]+\)", "", text)
    text = re.sub(r"[*_~>#]", "", text)
    return text.strip()


def is_procedure(line: str) -> bool:
    stripped = line.strip()
    if ORDERED.match(stripped) or BULLET.match(stripped):
        stripped = ORDERED.sub("", BULLET.sub("", stripped))
    return any(stripped.startswith(verb) for verb in PROCEDURE_VERBS)


def check_file(path: Path) -> FileReport:
    report = FileReport(path)
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    in_fence = False
    h1_count = 0
    has_next = False
    paragraph: list[str] = []

    for raw in lines:
        line = raw.rstrip()
        if FENCE.match(line):
            in_fence = not in_fence
            paragraph = []
            continue
        if in_fence:
            continue

        if H1.match(line):
            h1_count += 1
            continue
        if H2.match(line):
            if "下一步" in line:
                has_next = True
            paragraph = []
            continue
        if line.startswith("|") or line.startswith(">") or line.startswith("    "):
            paragraph = []
            continue
        if not line.strip():
            paragraph = []
            continue

        # Links and images are checked on the raw line.
        for alt, target in IMAGE.findall(line):
            if not alt.strip():
                report.missing_alt.append(target)
            if not target.startswith(("http://", "https://", "#")):
                candidate = (path.parent / target.split("#")[0]).resolve()
                if not candidate.exists():
                    report.missing_images.append(target)

        for label, target in LINK.findall(line):
            if target.startswith(("http://", "https://", "#", "mailto:")):
                continue
            candidate = (path.parent / target.split("#")[0]).resolve()
            if not candidate.exists():
                report.broken_links.append(target)

        if line.startswith("![") or line.strip().startswith("<"):
            continue

        cleaned = strip_markdown(line)
        if not cleaned:
            continue

        if path.name != "style-guide.md":
            for phrase in BAD_PHRASES:
                if phrase in cleaned:
                    report.bad_phrases.append(f"{phrase} :: {cleaned[:60]}")

            for term in FORBIDDEN_TERMS:
                if term in cleaned:
                    report.terms.append(f"{term} :: {cleaned[:60]}")

        limit = 20 if is_procedure(line) else 25
        parts = [part for part in SENTENCE_SPLIT.split(cleaned) if part.strip()]
        if not parts:
            parts = [cleaned]
        is_list_item = bool(ORDERED.match(line) or BULLET.match(line))
        if not is_list_item:
            paragraph.extend(parts)
        for part in parts:
            report.sentences += 1
            length = sentence_length(part)
            if length > limit:
                report.long_sentences.append(f"{length}/{limit} :: {part.strip()[:70]}")

        if not is_list_item and len(paragraph) > 6:
            report.long_paragraphs.append(" > ".join(paragraph[:7]))

    if h1_count != 1:
        report.structural.append(f"expected 1 H1, found {h1_count}")

    if path.name not in {"README.md", "style-guide.md"}:
        if "读完能做什么" not in text:
            report.structural.append("missing '读完能做什么' section")
        if not has_next:
            report.structural.append("missing '下一步' section")

    return report


def main() -> int:
    reports = [check_file(path) for path in DOCS if path.exists()]
    total_sentences = sum(report.sentences for report in reports)
    long_total = sum(len(report.long_sentences) for report in reports)

    sentence_rate = 0.0 if total_sentences == 0 else (total_sentences - long_total) / total_sentences
    penalties = 0
    for report in reports:
        penalties += len(report.long_paragraphs) * 2
        penalties += len(report.bad_phrases) * 3
        penalties += len(report.terms) * 2
        penalties += len(report.broken_links) * 10
        penalties += len(report.missing_images) * 10
        penalties += len(report.missing_alt) * 2
        penalties += len(report.structural) * 5

    score = round(sentence_rate * 70 + 30 - penalties, 1)
    score = max(0.0, min(100.0, score))

    print("Nook documentation check")
    print("========================")
    for report in reports:
        status = "OK" if report.clean else "ISSUES"
        print(f"\n{report.path.relative_to(ROOT)}  [{status}]  sentences={report.sentences}")
        for item in report.long_sentences:
            print(f"  long sentence {item}")
        for item in report.long_paragraphs:
            print(f"  paragraph {item[:90]}")
        for item in report.bad_phrases:
            print(f"  phrase {item}")
        for item in report.terms:
            print(f"  term {item}")
        for item in report.broken_links:
            print(f"  broken link {item}")
        for item in report.missing_images:
            print(f"  missing image {item}")
        for item in report.missing_alt:
            print(f"  missing alt {item}")
        for item in report.structural:
            print(f"  structure {item}")

    print("\nSummary")
    print(f"  sentences: {total_sentences}")
    print(f"  long sentences: {long_total}")
    print(f"  within-limit rate: {sentence_rate * 100:.1f}%")
    print(f"  score: {score}/100")
    print(f"  threshold: 80")

    return 0 if score >= 80 else 1


if __name__ == "__main__":
    sys.exit(main())
