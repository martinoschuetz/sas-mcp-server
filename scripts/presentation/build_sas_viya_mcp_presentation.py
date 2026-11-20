import os
from PIL import Image, ImageChops
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.util import Inches, Pt

SCRATCH = os.environ.get("PPTX_ASSETS_DIR", os.path.join(os.path.dirname(__file__), "pptx_assets"))
BASE_PPTX = os.environ.get("PPTX_TEMPLATE_PATH", r"C:\Git\sas-mcp-server\SAS_Viya_MCP_Server.pptx")
OUT_PPTX = r"C:\Git\sas-mcp-server\SAS_Viya_MCP_Server.pptx"
FQA_VIDEO = r"C:\Users\germsz\OneDrive - SAS\Solutions\SCI\FQA\FQA_MCP\FQA_MCP_Marketing.mp4"
FQA_POSTER = os.path.join(SCRATCH, "fqa_video_poster.png")
NESTLE_COMP = os.path.join(SCRATCH, "nestle_slide75_composite.png")

# Exact SAS Corporate Palette from SAS_Viya_MCP_Server.pptx
C_NAVY = RGBColor(0x07, 0x2B, 0x55)
C_BLUE = RGBColor(0x03, 0x69, 0xD9)
C_BERRY = RGBColor(0x86, 0x13, 0x4F)
C_ORANGE = RGBColor(0xE6, 0x6C, 0x37)
C_GREEN = RGBColor(0x15, 0xB5, 0x7B)
C_MUTED = RGBColor(0x4A, 0x60, 0x7A)
C_BG_CARD = RGBColor(0xFF, 0xFF, 0xFF)
C_BORDER = RGBColor(0xCB, 0xD5, 0xE1)

# Layout constants (20.00" x 11.25" Widescreen SAS Template)
CARD_TOP = 1.48
CARD_H_STD = 4.65
IMG_TOP_STD = 6.28
IMG_H_STD = 4.15


def autocrop_white_file(img_path: str, pad: int = 8) -> None:
    if not os.path.exists(img_path):
        return
    with Image.open(img_path) as im:
        rgb = im.convert("RGB")
        bg = Image.new("RGB", rgb.size, (255, 255, 255))
        diff = ImageChops.difference(rgb, bg).convert("L").point(lambda v: 255 if v > 8 else 0)
        bbox = diff.getbbox()
        if bbox:
            x0 = max(0, bbox[0] - pad)
            y0 = max(0, bbox[1] - pad)
            x1 = min(rgb.width, bbox[2] + pad)
            y1 = min(rgb.height, bbox[3] + pad)
            cropped = rgb.crop((x0, y0, x1, y1))
            cropped.save(img_path, quality=100)


def clear_all_slides(prs: Presentation) -> None:
    xml_slides = prs.slides._sldIdLst
    for sldId in list(xml_slides):
        rId = sldId.rId
        prs.part.drop_rel(rId)
        xml_slides.remove(sldId)


def set_notes(slide, explanation: str, mermaid_code: str) -> None:
    notes_slide = slide.notes_slide
    tf = notes_slide.notes_text_frame
    tf.text = (
        f"{explanation.strip()}\n\n"
        f"--- Mermaid Source Code ---\n"
        f"```mermaid\n{mermaid_code.strip()}\n```"
    )


def style_placeholder_box(
    ph,
    text: str,
    left: float,
    top: float,
    width: float,
    height: float,
    font_pt: float | None = None,
    color: RGBColor | None = None,
    bold: bool | None = None,
) -> None:
    ph.left = Inches(left)
    ph.top = Inches(top)
    ph.width = Inches(width)
    ph.height = Inches(height)
    tf = ph.text_frame
    tf.clear()
    tf.word_wrap = True
    tf.margin_left = Inches(0)
    tf.margin_right = Inches(0)
    tf.margin_top = Inches(0)
    tf.margin_bottom = Inches(0)
    lines = text.split("\n")
    for idx, line in enumerate(lines):
        p = tf.paragraphs[0] if idx == 0 else tf.add_paragraph()
        p.space_before = Pt(0)
        p.space_after = Pt(2) if len(lines) > 1 else Pt(0)
        r = p.add_run()
        r.text = line
        # Leave font.name = None so PowerPoint inherits Anova Bold / Anova Light from SAS Slide Master
        if font_pt is not None:
            r.font.size = Pt(font_pt)
        if bold is not None:
            r.font.bold = bold
        if color is not None:
            r.font.color.rgb = color


def add_title_and_subtitle(slide, title: str, subtitle: str) -> None:
    phs = sorted(slide.shapes.placeholders, key=lambda p: p.placeholder_format.idx)
    if len(phs) > 0:
        style_placeholder_box(
            phs[0], title, left=0.80, top=0.30, width=18.40, height=0.58, font_pt=27.0, color=C_NAVY, bold=True
        )
    if len(phs) > 1:
        style_placeholder_box(
            phs[1], subtitle, left=0.80, top=0.92, width=18.40, height=0.42, font_pt=15.5, color=C_BLUE, bold=False
        )


def add_card(
    slide,
    left: float,
    top: float,
    width: float,
    height: float,
    title: str,
    tag: str,
    bullets: list[tuple[str, str]],
    accent: RGBColor,
    title_pt: float = 17.5,
    tag_pt: float = 12.0,
    bullet_pt: float = 12.8,
) -> None:
    rect = slide.shapes.add_shape(
        MSO_SHAPE.ROUNDED_RECTANGLE, Inches(left), Inches(top), Inches(width), Inches(height)
    )
    rect.adjustments[0] = 0.02
    rect.fill.solid()
    rect.fill.fore_color.rgb = C_BG_CARD
    rect.line.color.rgb = C_BORDER
    rect.line.width = Pt(1.2)

    bar = slide.shapes.add_shape(
        MSO_SHAPE.ROUNDED_RECTANGLE, Inches(left), Inches(top), Inches(width), Inches(0.10)
    )
    bar.adjustments[0] = 0.02
    bar.fill.solid()
    bar.fill.fore_color.rgb = accent
    bar.line.fill.background()

    tb = slide.shapes.add_textbox(
        Inches(left + 0.18), Inches(top + 0.14), Inches(width - 0.36), Inches(height - 0.20)
    )
    tf = tb.text_frame
    tf.word_wrap = True
    tf.margin_top = Inches(0.02)
    tf.margin_bottom = Inches(0.02)

    p0 = tf.paragraphs[0]
    p0.space_after = Pt(1)
    r0 = p0.add_run()
    r0.text = title
    r0.font.size = Pt(title_pt)
    r0.font.bold = True
    r0.font.color.rgb = C_NAVY

    p1 = tf.add_paragraph()
    p1.space_after = Pt(5)
    r1 = p1.add_run()
    r1.text = tag
    r1.font.size = Pt(tag_pt)
    r1.font.bold = True
    r1.font.color.rgb = accent

    for b_head, b_body in bullets:
        p = tf.add_paragraph()
        p.space_after = Pt(4)
        r_h = p.add_run()
        r_h.text = f"•  {b_head}: "
        r_h.font.size = Pt(bullet_pt)
        r_h.font.bold = True
        r_h.font.color.rgb = C_NAVY

        r_b = p.add_run()
        r_b.text = b_body
        r_b.font.size = Pt(bullet_pt)
        r_b.font.bold = False
        r_b.font.color.rgb = C_NAVY


def add_fitted_image_box(
    slide, img_path: str, left: float, top: float, max_w: float, max_h: float, caption: str = ""
) -> None:
    if not os.path.exists(img_path):
        print("WARNING: missing image:", img_path)
        return
    if os.path.basename(img_path).startswith("m"):
        autocrop_white_file(img_path, pad=8)

    box = slide.shapes.add_shape(
        MSO_SHAPE.ROUNDED_RECTANGLE, Inches(left), Inches(top), Inches(max_w), Inches(max_h)
    )
    box.adjustments[0] = 0.012
    box.fill.solid()
    box.fill.fore_color.rgb = C_BG_CARD
    box.line.color.rgb = C_BORDER
    box.line.width = Pt(1.0)

    pad_x = 0.08
    pad_top = 0.06
    cap_h = 0.26 if caption else 0.06
    avail_w = max_w - 2 * pad_x
    avail_h = max_h - pad_top - cap_h

    with Image.open(img_path) as im:
        iw, ih = im.size
    aspect = iw / max(ih, 1)
    if avail_w / avail_h > aspect:
        draw_h = avail_h
        draw_w = draw_h * aspect
    else:
        draw_w = avail_w
        draw_h = draw_w / aspect

    img_left = left + (max_w - draw_w) / 2.0
    img_top = top + pad_top + (avail_h - draw_h) / 2.0
    slide.shapes.add_picture(img_path, Inches(img_left), Inches(img_top), Inches(draw_w), Inches(draw_h))

    if caption:
        cap_tb = slide.shapes.add_textbox(
            Inches(left + 0.14), Inches(top + max_h - 0.25), Inches(max_w - 0.28), Inches(0.23)
        )
        cp = cap_tb.text_frame.paragraphs[0]
        cr = cp.add_run()
        cr.text = caption
        cr.font.size = Pt(11.0)
        cr.font.bold = True
        cr.font.color.rgb = C_MUTED


def get_mermaid_src(key: str) -> str:
    raw = open(os.path.join(SCRATCH, "..", "render_mermaid.py"), encoding="utf-8").read()
    return raw.split(f'"{key}": """')[1].split('""",')[0]


def build_deck() -> None:
    prs = Presentation(BASE_PPTX)
    clear_all_slides(prs)

    layout_title = prs.slide_layouts[0]      # SAS - Title (SAS Blue bg2, White/Light-Blue theme text)
    layout_content = prs.slide_layouts[3]    # SAS - Title & Subtitle (White master + SAS logo)
    layout_closing = prs.slide_layouts[8]    # SAS - Closing (SAS Blue bg2, White/Light-Blue theme text)

    # =========================================================================
    # SLIDE 1: Title Slide (Exact Native SAS - Title Layout Colors & Fonts)
    # =========================================================================
    s1 = prs.slides.add_slide(layout_title)
    phs1 = sorted(s1.shapes.placeholders, key=lambda p: p.placeholder_format.idx)
    if len(phs1) > 0:
        style_placeholder_box(
            phs1[0],
            "Autonomous Analytics on SAS Viya via MCP",
            left=1.370,
            top=3.050,
            width=17.600,
            height=1.200,
            font_pt=52.0,
            color=None,  # Inherits SAS - Title White (bg1)
            bold=None,
        )
    if len(phs1) > 1:
        style_placeholder_box(
            phs1[1],
            "Extending the Open-Source SAS Viya MCP Server across\n"
            "SAS AIoT, Field Quality (FQA), Custom Analysis Framework (CAF),\n"
            "SAS Optimizer for IoT, Event Stream Processing (ESP) & Visual Forecasting",
            left=1.370,
            top=4.480,
            width=17.600,
            height=2.850,
            font_pt=31.0,
            color=None,  # Inherits SAS - Title Light Blue (accent3 #C4DEFD)
            bold=None,
        )
    if len(phs1) > 2:
        style_placeholder_box(
            phs1[2],
            "Martin Schütz & Manfred Kügel",
            left=1.370,
            top=9.052,
            width=13.259,
            height=1.157,
            font_pt=None,  # Native SAS - Title author size (28pt)
            color=None,    # Native SAS - Title Light Blue (accent3)
            bold=None,
        )
    set_notes(
        s1,
        """Welcome everyone. In this 45-minute session (35–40 minutes walkthrough plus 5–10 minutes Q&A), we present our work extending the SAS Viya Model Context Protocol (MCP) Server and SAS Retrieval Agent Manager (RAM) ecosystem across six core industrial and enterprise tracks:
1. SAS Viya MCP Server (v1.20.2, 249 tools across 17 tiers, 10 MCP Apps views, 7 domain skills in knowledge/)
2. SAS Field Quality Analytics (FQA) & Headless SAS RAM Operations (C:\\Git\\Manfred\\FQA & C:\\Git\\Manfred\\ram-mcp-server)
3. SAS Event Stream Processing (ESP) Bioreactor & District Cooling Streaming (C:\\Git\\martinoschuetz\\projects\\CandF & Qatar_Cool)
4. SAS AIoT Custom Analysis Framework (CAF) Vibe-Coding Factory, 12-Package Anomaly Suite & 6-Package FQA Custom Suite (C:\\Git\\martinoschuetz\\AIoT\\custom_analysis)
5. SAS Optimizer for IoT — formerly Energy Cost Optimizer (C:\\Git\\martinoschuetz\\IOT\\AIoT_Optimizer)
6. SAS Visual Forecasting Hybrid ATSM / EXTLANG / MP-CONNECT Tournament (C:\\Git\\martinoschuetz\\Forecasting)""",
        """flowchart LR
    A["Frontier Coding Agents<br/>(Claude / Gemini / SAS RAM)"] --> B["SAS Viya MCP (249 Tools)<br/>+ SAS RAM MCP (63 Tools)<br/>+ 7 Domain Skillsets"]
    B --> C["SAS FQA & RAM Agent v40"]
    B --> D["SAS ESP Streaming"]
    B --> E["SAS AIoT CAF (16 Suites)"]
    B --> F["SAS Optimizer for IoT"]
    B --> G["SAS Visual Forecasting"]""",
    )

    # =========================================================================
    # SLIDE 2: HIDDEN SLIDE — Presenter Live Demo, Video & Workspace Cue Sheet
    # =========================================================================
    s_cue = prs.slides.add_slide(layout_content)
    s_cue._element.set("show", "0")
    add_title_and_subtitle(
        s_cue,
        "[HIDDEN PRESENTER GUIDE] Live Demo, Video & Workspace Cue Sheet",
        "Reference Guide for Live Asset Switching Across All Six Repositories (Skipped in Slide Show)",
    )
    cards_cue_top = [
        (
            "Block 1 (Min 00–09): Slides 3–7",
            "Platform, API Sync & Updated Skills",
            [
                ("Slide 4 (333 API Specs)", "Show scripts/download_specs.py and docs/APIs/ (333 YAML specs across 14 Viya categories)."),
                ("Slide 5 (Expanded Skills)", "Open knowledge/caf (v2.1, 13 rules + 7 refs) and knowledge/fqa (v0.6, 17 models + API traps)."),
                ("Slide 6 (v1.20.2+ Tiers 0–16)", "Show 251 tools, 115 fail-closed read-only gates (_access.py), and 10 MCP Apps HTML views."),
            ],
            C_BLUE,
        ),
        (
            "Block 2 (Min 09–19): Slides 8–12",
            "SAS FQA, RAM MCP & Champion v40",
            [
                ("Slide 8–10 (FQA & Video)", "Show Playwright docs, %afi_dataload guide, and play FQA_MCP_Marketing.mp4 on Slide 10."),
                ("Slide 11 (ram-mcp-server)", "Show C:\\Git\\Manfred\\ram-mcp-server (63 headless RAM tools on :8135 + run-evals.mjs)."),
                ("Slide 12 (FQA Agent 3f-msz)", "Show C:\\Git\\Manfred\\FQA (Template v40, 47 intents, 558 tests, 4.8/5.0 SME certification)."),
            ],
            C_BERRY,
        ),
        (
            "Block 3 (Min 19–31): Slides 13–17",
            "SAS ESP & AIoT CAF Factory",
            [
                ("Slide 13–14 (ESP Chains)", "Show CandF_UNS_BMC2.xml + dual-clock audit in projects\\CandF and Qatar Cool Grafana."),
                ("Slide 15–16 (Anomaly Suite)", "Show custom_analysis\\Custom: 12 live ASSET CAFs + 4-step ANOMALY_ENSEMBLE (SSDO)."),
                ("Slide 17 (FQA PRODUCT CAFs)", "Show 6 live FQA custom analysis types (RF Drivers, Subgroup, Weibull, Cox, CAPA, Precursor)."),
            ],
            C_ORANGE,
        ),
        (
            "Block 4 (Min 31–45): Slides 18–22",
            "Optimizer for IoT, Forecasting & Loop",
            [
                ("Slide 18 (Optimizer for IoT)", "Open IOT\\AIoT_Optimizer: 5 VA reports + React 19 DDC, UniMeMo tournament & 1.5s OPTLSO."),
                ("Slide 19–20 (Forecasting)", "Show Forecasting 3-tier ATSM + EXTLANG + MP-CONNECT pipeline & 8-view HTML5/VA dashboard."),
                ("Slide 21–22 (5-Solution Loop)", "Walk through the closed-loop ESP -> CAF -> Optimizer -> FQA -> Forecasting chain & Q&A."),
            ],
            C_GREEN,
        ),
    ]
    for i, (t, tag, b, acc) in enumerate(cards_cue_top):
        add_card(s_cue, 0.80 + i * 4.65, CARD_TOP, 4.45, 4.20, t, tag, b, acc)

    add_fitted_image_box(
        s_cue,
        os.path.join(SCRATCH, "m04_skill_flywheel.png"),
        0.80,
        5.85,
        18.40,
        4.55,
        "Presenter Workflow: Slide Narrative ↔ Antigravity / Claude CLI ↔ SAS RAM (:8135) & Viya MCP (:8134) ↔ Live SAS Viya UI",
    )
    set_notes(
        s_cue,
        """HIDDEN PRESENTER CUE SHEET — Exact Local Repositories & Assets:
1. Core SAS Viya MCP Server (v1.20.2, 249 tools, 7 skills): C:\\Git\\sas-mcp-server
2. SAS RAM MCP Server (63 tools) & Production FQA Agent (3f-msz / v2.22.0 / Template v40): C:\\Git\\Manfred\\ram-mcp-server & C:\\Git\\Manfred\\FQA
3. SAS ESP Bioreactor & District Cooling Chains: C:\\Git\\martinoschuetz\\projects\\CandF & C:\\Git\\martinoschuetz\\projects\\Qatar_Cool
4. SAS AIoT Custom Analysis Framework (CAF) Factory (12 Anomaly + 6 FQA CAFs): C:\\Git\\martinoschuetz\\AIoT\\custom_analysis
5. SAS Optimizer for IoT (rebranded & rebuilt from Energy Cost Optimizer): C:\\Git\\martinoschuetz\\IOT\\AIoT_Optimizer
6. SAS Visual Forecasting Hybrid Tournament: C:\\Git\\martinoschuetz\\Forecasting""",
        get_mermaid_src("m04_skill_flywheel"),
    )

    # =========================================================================
    # SLIDE 3: From Public Open-Source MCP to Full-Spectrum Solution Engine
    # =========================================================================
    s3 = prs.slides.add_slide(layout_content)
    add_title_and_subtitle(
        s3,
        "From Public Open-Source MCP to Full-Spectrum Solution Engine",
        "Extending sassoftware/sas-mcp-server (v1.20.2) & SAS RAM Across Six Industrial Workstreams",
    )
    cards_s3 = [
        (
            "The Official Open-Source Baseline",
            "github.com/sassoftware/sas-mcp-server",
            [
                ("Core Viya Foundation (Tiers 0–11)", "Provides 137 foundational tools for SAS Compute, CAS tables, Information Catalog, VA reports, AutoML, Decisioning, and Glossary."),
                ("Missing Deep Solution APIs", "Industrial solutions—SAS FQA, AIoT CAF, Optimizer for IoT, ESP Studio, and Visual Forecasting—rely on internal REST contracts."),
                ("The LLM Hallucination Trap", "Without typed solution tools and live-verified domain playbooks, frontier LLMs invent payloads, break BIRD XML, or guess statistics."),
            ],
            C_BERRY,
        ),
        (
            "Three-Pillar Extension Methodology",
            "APIs + Live-Verified Skills + Dual MCP",
            [
                ("1. Monthly OpenAPI Harvesting", "Automated Playwright crawler (scripts/download_specs.py) refreshes 333 public & internal Viya YAML specs on every monthly cadence."),
                ("2. Deep Domain Skillsets (knowledge/)", "Distilled Gemini Notebooks, Playwright docs, and live Viya/UI forensics into 7 playbooks—led by sas-caf v2.1 and sas-fqa v0.6."),
                ("3. Dual MCP Server Ecosystem", "Paired sas-mcp-server (:8134, 251 Viya tools) with Manfred's ram-mcp-server (:8135, 63 headless SAS RAM lifecycle & eval tools)."),
            ],
            C_BLUE,
        ),
        (
            "Deterministic Solution Execution",
            "Numbers from SAS, Words from the Agent",
            [
                ("251 Viya Tools + 10 MCP Apps", "137 core + 114 solution tools across Tiers 0–16, plus 10 interactive HTML views (Data grids, colour-coded SAS logs, Glossary UI)."),
                ("18 Live Custom CAF Packages", "Enabled vibe-coding 12 industrial Anomaly Detection CAFs (incl. 8-engine Ensemble) and 6 live FQA PRODUCT CAFs with zero SAS errors."),
                ("CLI to SAS RAM Production", "Runs identically in Antigravity / Claude Code, M365 Copilot, and containerized champion agents (FQA_msz v40) on SAS RAM."),
            ],
            C_GREEN,
        ),
    ]
    for i, (t, tag, b, acc) in enumerate(cards_s3):
        add_card(s3, 0.80 + i * 6.20, CARD_TOP, 6.00, CARD_H_STD, t, tag, b, acc)
    add_fitted_image_box(
        s3,
        os.path.join(SCRATCH, "m02_mcp_extension.png"),
        0.80,
        IMG_TOP_STD,
        18.40,
        IMG_H_STD,
        "Evolution Flow: Upstream Tiers 0–11 (137 Tools) → 333 OpenAPI Specs + 7 Live-Verified Skills → 251-Tool Viya MCP + 63-Tool RAM MCP",
    )
    set_notes(
        s3,
        """Slide 3 sets the stage for our expanded ecosystem:
- Upstream `sassoftware/sas-mcp-server` supplies 137 core tools in Tiers 0–11 plus 10 interactive MCP Apps HTML views.
- Our extended `C:\\Git\\sas-mcp-server` (`v1.20.2`) adds 112 specialized solution tools across Tiers 12–16 (249 total tools), 333 monthly-harvested OpenAPI specs, and 7 battle-tested domain skillsets in `knowledge/`.
- Alongside `sas-mcp-server` (port 8134), `C:\\Git\\Manfred\\ram-mcp-server` (port 8135) adds 63 MCP tools giving coding agents full headless control over SAS Retrieval Agent Manager (RAM).""",
        get_mermaid_src("m02_mcp_extension"),
    )

    # =========================================================================
    # SLIDE 4: Monthly Cadence API Overhaul (scripts/download_specs.py -> docs/APIs)
    # =========================================================================
    s4 = prs.slides.add_slide(layout_content)
    add_title_and_subtitle(
        s4,
        "Monthly Cadence API Overhaul: scripts/download_specs.py",
        "Automated Harvesting of 333 Public & Internal SAS Viya OpenAPI Specs into docs/APIs",
    )
    cards_s4 = [
        (
            "Why Monthly API Scraping Matters",
            "Keeping Pace with SAS Viya Cadence",
            [
                ("Continuous Viya Evolution", "SAS Viya and its industry solutions ship updates monthly (LTS 2024.09 through Stable 2026.10); static wrappers quickly drift."),
                ("Internal Solution Endpoints", "Critical endpoints for FQA data selections, AIoT launchers, CAF model ETags, and VA BIRD operations live in internal specs."),
                ("Single Source of Truth", "Storing machine-readable OpenAPI YAML/JSON specs locally gives coding agents exact request, header, and media-type schemas."),
            ],
            C_NAVY,
        ),
        (
            "How scripts/download_specs.py Works",
            "Playwright + SSO + Next.js Extraction",
            [
                ("Authenticated Playwright Session", "Uses persistent browser state (auth_state.json) and exponential backoff with random jitter to navigate corporate SSO and WAF limits."),
                ("Three-Stage Spec Extractor", "Extracts raw OpenAPI YAML from Next.js __NEXT_DATA__ payloads, direct download links, or full DOM markdown reconstruction."),
                ("Incremental Force-Refresh", "Supports --force and category filters to overhaul the entire API catalog on every monthly SAS Viya release."),
            ],
            C_BLUE,
        ),
        (
            "333 Specs Powering 251 Tools",
            "Stored in docs/APIs/ (14 Categories)",
            [
                ("Complete Platform Coverage", "333 YAML specifications across 14 folders: AIoT (13), Data Management (60), Core Platform (58), Analytics (42), BI (24), and more."),
                ("Unlocked Recent Breakthroughs", "Directly powered Launcher CRUD, standalone Data Selections, filter picklists, recursive Folders, and CAF If-Match ETag PUT updates."),
                ("Zero-Hallucination Tool Synthesis", "Agents inspect docs/APIs/ first, then generate typed FastMCP tools, _access.py classifications, and pytest suites automatically."),
            ],
            C_ORANGE,
        ),
    ]
    for i, (t, tag, b, acc) in enumerate(cards_s4):
        add_card(s4, 0.80 + i * 6.20, CARD_TOP, 6.00, CARD_H_STD, t, tag, b, acc)
    add_fitted_image_box(
        s4,
        os.path.join(SCRATCH, "m03_download_specs.png"),
        0.80,
        IMG_TOP_STD,
        18.40,
        IMG_H_STD,
        "Automated Monthly Overhaul Pipeline: developer.sas.com + Internal Specs → scripts/download_specs.py → docs/APIs (333 YAML Specs)",
    )
    set_notes(
        s4,
        """Slide 4 explains `C:\\Git\\sas-mcp-server\\scripts\\download_specs.py`:
- Harvests all 333 public and internal OpenAPI specs across 14 solution directories into `C:\\Git\\sas-mcp-server\\docs\\APIs`.
- Recent `v1.20.1`–`v1.20.2` additions—standalone `create_data_selection_tool`, full Launcher CRUD, `@myFolder` member management, vendor `Accept` + `If-Match` ETag headers on CAF `PUT`, and `steps[0]` step parameter updates—were all verified directly against these specs.""",
        get_mermaid_src("m03_download_specs"),
    )

    # =========================================================================
    # SLIDE 5: Dynamic Skill Extraction & Expanded Domain Playbooks (knowledge/)
    # =========================================================================
    s5 = prs.slides.add_slide(layout_content)
    add_title_and_subtitle(
        s5,
        "Dynamic Skill Extraction & Expanded Playbooks (knowledge/)",
        "Major Knowledge Upgrades Across CAF (v2.1), FQA (v0.6), ESP, Forecasting & SAS Standards",
    )
    cards_s5 = [
        (
            "Multi-Source Knowledge Distillation",
            "7 Domain Skillsets in C:\\Git\\sas-mcp-server\\knowledge",
            [
                ("Literature + Runtime Forensics", "Combines Gemini Notebooks, Playwright help docs, customer ETL macros, and client JS bundle inspection (app.js / 4983.bundle.js)."),
                ("7 Structured Skill Repositories", "sas-fqa, sas-caf, sas-esp, sas-forecasting, sas-api, sas-core, and sas-standards—each with SKILL.md, rules, references, and evals."),
                ("Universal Agent Sync", "scripts/install_agent_skills.py links all 7 skills into Claude Code, Antigravity/Gemini, Cursor, and Codex automatically."),
            ],
            C_ORANGE,
        ),
        (
            "Deep CAF v2.1 & FQA v0.6 Upgrades",
            "Turning Silent Viya Traps into Hard Rules",
            [
                ("sas-caf v2.1.0 (13 Live Rules + 7 Refs)", "Encodes RESOLVEONUI=true strictly on STABLEPERIOD, empty <Condition> cascades, <=32-char CRC32 CAS tables, and Rule 11 BIRD XML hardening."),
                ("CAF Templates & Case Studies", "Ships deterministic build_package.py, Gen-2 & multi-step STABLEPERIOD SAS skeletons, Anomaly patterns, and Isolation Forest walkthrough."),
                ("sas-fqa v0.6.0 (18 Reference Guides)", "Adds all 17 STANDARD/ALERTS model contracts, non-FQA domain guards, Launcher 11-col payloads, @myFolder ACLs, and 423 wait rules."),
            ],
            C_BLUE,
        ),
        (
            "Tier 16 On-Demand Runtime Delivery",
            "Zero Context Bloat for Local & RAM Agents",
            [
                ("1. list_knowledge_domains()", "Agents inspect available skill domains and trigger rules at runtime without pre-loading hundreds of pages into prompts."),
                ("2. read_knowledge_topic() & search", "Loads SKILL.md, mcp_execution_rules.md, or regex-matched reference sections on demand (plus MCP skill://<domain> URIs)."),
                ("3. Continuous Co-Evolution Loop", "Every bug solved in custom_analysis, Manfred/FQA, Optimizer, or Forecasting is immediately codified back into knowledge/."),
            ],
            C_GREEN,
        ),
    ]
    for i, (t, tag, b, acc) in enumerate(cards_s5):
        add_card(s5, 0.80 + i * 6.20, CARD_TOP, 6.00, CARD_H_STD, t, tag, b, acc)
    add_fitted_image_box(
        s5,
        os.path.join(SCRATCH, "m04_skill_flywheel.png"),
        0.80,
        IMG_TOP_STD,
        18.40,
        IMG_H_STD,
        "Closed-Loop Skill Flywheel: Notebooks & UI/Log Forensics → knowledge/ (CAF v2.1 & FQA v0.6) → Tier 16 On-Demand Load → Zero-Error Execution",
    )
    set_notes(
        s5,
        """Slide 5 highlights the major expansion of `C:\\Git\\sas-mcp-server\\knowledge\\`:
- **`knowledge/caf/` (`sas-caf` v2.1.0):** Expanded with 13 live-verified rules, 7 deep reference files (`aiot_platform_and_etl.md`, `anomaly_caf_design_and_patterns.md`, `ui_lookups_and_interactions.md`, `sas_cas_plumbing.md`, `va_output_templates.md`, `troubleshooting.md`, `case_study_isolation_forest.md`), and reusable templates (`build_package.py`). Almost every CAF bug imports with HTTP 200/202 and fails silently in the React UI or VA BIRD XML—reverse-engineering `app.js` and 38 live models eliminated those traps permanently.
- **`knowledge/fqa/` (`sas-fqa` v0.6.0):** Expanded with `standard-models-caf.md` and `object-lifecycle-and-api-traps.md` from the Stage 3–5 RAM FQA Agent program.""",
        get_mermaid_src("m04_skill_flywheel"),
    )

    # =========================================================================
    # SLIDE 6: Modular 17-Tier Architecture (v1.20.2 — 249 Tools & MCP Apps)
    # =========================================================================
    s6 = prs.slides.add_slide(layout_content)
    add_title_and_subtitle(
        s6,
        "SAS Viya MCP Server: Modular 17-Tier Architecture (251 Tools)",
        "251 Tools Across Tiers 0–16, 115 Fail-Closed Read-Only Gates & 10 Interactive MCP Apps Views",
    )
    cards_s6 = [
        (
            "Tiers 0–11: Core Viya & MCP Apps",
            "137 Upstream Tools + Sandboxed HTML Views",
            [
                ("Tiers 0–3 (Compute, Data & VA)", "Warm per-user Compute sessions with automatic ODS HTML5 result links, Catalog NLP profiling, unified FedSQL query_data, and VA BIRD ops."),
                ("Tiers 4–11 (ML, Decisioning & Gov)", "Async batch jobs, AutoML, MAS & CAS scoring, Intelligent Decisioning flows, Business Glossary, and SAS Model Manager lifecycle."),
                ("10 Interactive MCP Apps Views", "Inline sortable Data grids, colour-coded SAS Log + Results viewers, and Glossary tree/form editors in Claude, ChatGPT, Copilot & VS Code."),
            ],
            C_NAVY,
        ),
        (
            "Tiers 12–16: 114 Solution Tools",
            "IoT/FQA, Forecasting, GenAI, ESP, CAF & Skills",
            [
                ("Tier 12 (IoT, FQA & Forecasting)", "85+ tools: Emerging Issues, 14 standard analyses, bundled RCA templates, standalone DS + filter picklists, Launchers, Folders & Forecasting."),
                ("Tiers 13–15 (GenAI, ESP & CAF)", "SAS GenAI agents (13), ESP Studio XML deployment (14), and 14 CAF schema, contract, VA templatization & ETag lifecycle tools (15)."),
                ("Tier 16 (Knowledge Engine)", "On-demand domain discovery, topic reading, and regex search across all 7 domain skill playbooks."),
            ],
            C_BLUE,
        ),
        (
            "Fail-Closed Governance & Deployment",
            "src/sas_mcp_server/tools/_access.py",
            [
                ("Strict Read/Write + Tool Annotations", "Fail-closed _access.py withholds 136 write/compute tools when MCP_READ_ONLY=true (115 read tools) and advertises MCP safety hints."),
                ("Flexible Auth & Tier Scoping", "Supports OAuth2 PKCE, cached CLI login, ALLOW_RAW_BEARER JWKS validation, MCP_TIERS scoping, and Copilot Studio tool-prefix renaming."),
                ("Stdio, HTTP, Docker & Kubernetes", "Deploys locally via uv, as sas-mcp-server-msz on SAS RAM, or cluster-wide via Helm (Contour / ingress-nginx)."),
            ],
            C_GREEN,
        ),
    ]
    for i, (t, tag, b, acc) in enumerate(cards_s6):
        add_card(s6, 0.80 + i * 6.20, CARD_TOP, 6.00, CARD_H_STD, t, tag, b, acc)
    add_fitted_image_box(
        s6,
        os.path.join(SCRATCH, "m05_tiers_arch.png"),
        0.80,
        IMG_TOP_STD,
        18.40,
        IMG_H_STD,
        "17-Tier Architecture: AI Clients & SAS RAM → FastMCP Access & Annotation Layer → Core Tiers 0–11 (137) + Solution Tiers 12–16 (114)",
    )
    set_notes(
        s6,
        """Slide 6 details the `v1.20.2` engineering architecture of `C:\\Git\\sas-mcp-server`:
- **249 tools across 17 tiers (`0–16`):** 137 in Tiers 0–11 synced with upstream `sassoftware/sas-mcp-server` (including the 10 interactive `@modelcontextprotocol/ext-apps` HTML views and automatic `ods html5` results links) + 112 specialized tools in Tiers 12–16.
- **Fail-closed security (`_access.py`):** 113 tools are proven side-effect-free (`READ_ONLY_TOOLS`); CI tests (`test_read_only.py`, `test_tier_selection.py`) guarantee no unclassified tool can ever slip through.""",
        get_mermaid_src("m05_tiers_arch"),
    )

    # =========================================================================
    # SLIDE 7: Deterministic Reliability: The Agent Governance Contract
    # =========================================================================
    s7 = prs.slides.add_slide(layout_content)
    add_title_and_subtitle(
        s7,
        "Deterministic Reliability: The Agent Governance Contract",
        "Zero Mental Math, Unit-Level Counting, Preflight Gates & #approve Write-Back Safety",
    )
    cards_s7 = [
        (
            "Zero Mental Math & Unit-Level Rigor",
            "Eliminating Hallucinations by Design",
            [
                ("No LLM Arithmetic", "Every rate, lift, p-value, Weibull β/η, Shapley value, or MinT forecast comes strictly from SAS Compute or CAS execution."),
                ("Count Units, Never Claim Pairs", "All cohort rates and Failure Relationships enforce COUNT(DISTINCT PRODUCT_ID) so multi-line claims never inflate confidence."),
                ("Single-Call Preflight Gate", "run_fqa_preflight_checks_tool verifies unit volume, distinct levels (>=2), cardinality (<=500), and verbatim count (>=50) upfront."),
            ],
            C_BERRY,
        ),
        (
            "Self-Healing & Domain Guards",
            "Autonomous Recovery Without Infinite Loops",
            [
                ("Automated SAS Log Diagnostics", "When a step fails, get_iot_analysis_step_log_tool extracts exact ERROR: lines; CAF smoke tests require 0 runtime ERRORs."),
                ("Non-FQA Domain & Cardinality Guards", "Blocks running FQA product tools on ASSET/EVENTS selections and invokes remediate_high_cardinality_tool when levels exceed caps."),
                ("Hard 3-Strikes & Budget Caps", "Caps retries at 3 attempts and enforces strict wall-clock turn budgets (200s soft / 240s hard) with deterministic fallbacks."),
            ],
            C_ORANGE,
        ),
        (
            "PII Redaction & Governed Write-Back",
            "Enterprise Safety & Full Reproducibility",
            [
                ("Untrusted Text & PII Masking", "Wraps free-text comments in <data> tags and redacts VINs, emails, phones, and customer names before LLM or user output."),
                ("Explicit #approve & #undo Gates", "Mutations and deletions require explicit #approve tokens (free-text 'yes' never deletes) and store snapshots for #undo reconstruction."),
                ("Persistent SAS Viya UI Artifacts", "Investigations materialize clean Projects, Data Selections, Launchers, and Custom CAF views directly inside the SAS Viya UI."),
            ],
            C_BLUE,
        ),
    ]
    for i, (t, tag, b, acc) in enumerate(cards_s7):
        add_card(s7, 0.80 + i * 6.20, CARD_TOP, 6.00, CARD_H_STD, t, tag, b, acc)
    add_fitted_image_box(
        s7,
        os.path.join(SCRATCH, "m06_governance.png"),
        0.80,
        IMG_TOP_STD,
        18.40,
        IMG_H_STD,
        "Execution Governance Pipeline: Domain Skill & Schema Guard → Single-Call CAS Preflight → Unit-Level SAS Compute → PII-Redacted & Reversible UI Output",
    )
    set_notes(
        s7,
        """Slide 7 summarizes the governance invariants shared across `C:\\Git\\sas-mcp-server\\knowledge` and `C:\\Git\\Manfred\\FQA`:
- Numbers come exclusively from SAS/CAS; unit-level `COUNT(DISTINCT PRODUCT_ID)` prevents claim-pair inflation.
- Free-text comments and stale descriptions are treated as untrusted `<data>` and redacted for PII.
- Destructive or mutating actions require explicit human sign-off (`#approve`) and support full topological `#undo` / `#rollback`.""",
        get_mermaid_src("m06_governance"),
    )

    # =========================================================================
    # SLIDE 8: SAS Field Quality Analytics (FQA) — Knowledge, Playwright Docs & ETL
    # =========================================================================
    s8 = prs.slides.add_slide(layout_content)
    add_title_and_subtitle(
        s8,
        "SAS Field Quality Analytics (FQA): Knowledge & Automated Docu",
        "Warranty Gemini Notebook, 180 Playwright Docs, %afi_dataload Guide & Live REST Lifecycle Rules",
    )
    cards_s8 = [
        (
            "Warranty & Reliability Context",
            "Gemini Notebook + Reliability Metrics",
            [
                ("Warranty Gemini Notebook", "Curated warranty and reliability engineering literature in a dedicated Gemini Notebook grounding sas-fqa v0.6.0."),
                ("Weibull & B-Life Mastery", "Encoded Weibull shape (β < 1 infant, β ≈ 1 random, β > 1 wear-out), 95% CI overlap tests, η = B63.2, and T01–T25 B-lives."),
                ("3rd Time Dimension (Sales Lag)", "Uses the Sales Lag Details Chart (C_ijk = Claim_j - Build_i - TIS_k) to separate factory batch defects from pre-delivery lot-rot."),
            ],
            C_BLUE,
        ),
        (
            "Automated Product Docu via Playwright",
            "180 Markdown Files + 341 Images",
            [
                ("Offline-Ready AIoT Doc Corpus", "Extracted and validated 180 Markdown files and 341 images across 14 SAS AIoT/FQA doc sets in AIoT/FQA/sas-analytics-for-iot-md."),
                ("17 Standard & Alert CAF Contracts", "Documented exact modelName mappings, visual caps (MAXREPORTLEVEL, NUMBARS), and SpEL locks across all 14 STANDARD + 3 ALERTS types."),
                ("Live Viya API & ACL Trap Catalog", "Codified /copy EIENTERPRISE rules, 11-col Launcher payloads, @myFolder vs. IoTProjects 403 traps, and 423 dependency waits."),
            ],
            C_ORANGE,
        ),
        (
            "Reverse-Engineered Data Load Docu",
            "Automated Customer ETL Documentation",
            [
                ("Solving Missing ETL Documentation", "Pointed the agent at raw customer (MAN) %afi_dataload scripts, Data Elements Workbooks (DEW), and SAS macro overrides."),
                ("Complete 14-Section Reference", "Generated fqa_load_documentation.md covering 15 staging tables, ~480 variables, 6-stage SYSPARM loads, and sequential BOM logic."),
                ("Parallel FQA + APA Co-Existence", "Solved and documented TABLE_META_PG deduplication (afi_save_metatables) so FQA and APA models run side-by-side without conflict."),
            ],
            C_GREEN,
        ),
    ]
    for i, (t, tag, b, acc) in enumerate(cards_s8):
        add_card(s8, 0.80 + i * 6.20, CARD_TOP, 6.00, CARD_H_STD, t, tag, b, acc)
    add_fitted_image_box(
        s8,
        os.path.join(SCRATCH, "m07_fqa_doc_etl.png"),
        0.80,
        IMG_TOP_STD,
        18.40,
        IMG_H_STD,
        "FQA Knowledge Engineering: Warranty Notebook + 180 Playwright Docs + %afi_dataload ETL + 17 Model Specs → knowledge/fqa/ (v0.6.0)",
    )
    set_notes(
        s8,
        """Slide 8 covers FQA knowledge engineering across `C:\\Git\\sas-mcp-server\\knowledge\\fqa`, `C:\\Git\\martinoschuetz\\AIoT\\FQA`, and `C:\\Users\\germsz\\OneDrive - SAS\\Solutions\\SCI\\FQA\\Documents`:
- Combines the Warranty Gemini Notebook, `FQA_MCP_Users_Guide.md`, 180 Playwright-converted AIoT docs, the reverse-engineered MAN `%afi_dataload` reference, and the newly verified `standard-models-caf.md` & `object-lifecycle-and-api-traps.md` playbooks.""",
        get_mermaid_src("m07_fqa_doc_etl"),
    )

    # =========================================================================
    # SLIDE 9: FQA Guided 4-Phase Investigation Funnel & Bundled MCP Tools
    # =========================================================================
    s9 = prs.slides.add_slide(layout_content)
    add_title_and_subtitle(
        s9,
        "FQA Guided Investigation Funnel & Bundled Single-Call Tools",
        "Encoding Warranty Best Practices into High-Speed Single-Call CAS & FQA Orchestration Tools",
    )
    cards_s9 = [
        (
            "Phase 0: Triage & Common Cause",
            "Special Cause vs. 4-Quadrant Common Cause",
            [
                ("triage_emerging_issue_runs_tool", "Evaluates all EI runs in one CAS call, tie-breaks by newest lastRunDate, separates creator vs. DS lineage, and returns Top-10 lists."),
                ("4-Question Alert Context Triage", "inspect_emerging_issue_alert_context_tool reads _ALERTS_, _DETAILS_ (Sales Lag C_ijk), _WUMKR_, and _BASELINE_ simultaneously."),
                ("Common Cause Screening", "screen_common_cause_candidates_tool classifies chronic warranty drains into 4 Pareto × Weibull β quadrants with T01–T25 B-lives."),
            ],
            C_BERRY,
        ),
        (
            "Phase 1, 4 & 2: Weibull & Dilution",
            "Early Normalization + >=25% Coverage Gate",
            [
                ("Normalize Early (Phase 4 Before 2)", "fqa_template_descriptive_triage runs Pareto, Geo, Exposure, and Weibull β CI overlap tests before tree segmentation."),
                ("Algorithmic Segmentation", "fqa_template_algorithmic_segmentation pairs stratified Statistical Drivers (ANOM) with Decision Trees on mature units."),
                ("4-Year Denominator Dilution Audit", "evaluate_subpopulation_lift_and_coverage_tool contrasts active-build cohort lift vs. diluted 4-yr fleet rates and prunes pinned cols."),
            ],
            C_BLUE,
        ),
        (
            "Phase 3: Widening & 1-DS Synthesis",
            "Preventing Leaf Pinning + UI Verification",
            [
                ("Phase 3 Population Widening Rule", "Automatically widens narrow Phase-2 leaves back to the parent cohort before Text Mining or Failure Relationships so levels contrast."),
                ("One Consolidated Root-Cause DS", "synthesize_root_cause_data_selection_tool builds ONE pruned multi-domain Data Selection (PRODUCT/CLAIM/LABOR/PART) in CAS."),
                ("Immediate FQA UI Mirroring", "Launches verification Detail (DETAIL_PRODUCT) and Pareto (PARETO_PRODUCT) nodes inside the project so engineers see exact units."),
            ],
            C_GREEN,
        ),
    ]
    for i, (t, tag, b, acc) in enumerate(cards_s9):
        add_card(s9, 0.80 + i * 6.20, CARD_TOP, 6.00, CARD_H_STD, t, tag, b, acc)
    add_fitted_image_box(
        s9,
        os.path.join(SCRATCH, "m08_fqa_funnel.png"),
        0.80,
        IMG_TOP_STD,
        18.40,
        IMG_H_STD,
        "FQA Autonomous Investigation Funnel: Phase 0 Single-Call Triage → Phase 1/4 Weibull Normalization → Phase 2 Lift/Dilution → Phase 3 Widened Synthesis",
    )
    set_notes(
        s9,
        """Slide 9 shows how `sas-fqa` best practices are compiled into single-call composite tools in `src/sas_mcp_server/tools/iot.py`:
- Collapses 25–35 exploratory API calls into 6 deterministic single-call CAS/FQA tools while enforcing the >=25% alert-coverage root-cause gate, 4-year denominator dilution audit, Phase 3 population widening, and the Top-10 list presentation rule.""",
        get_mermaid_src("m08_fqa_funnel"),
    )

    # =========================================================================
    # SLIDE 10: FQA Live Case Study & Embedded Marketing Video
    # =========================================================================
    s10 = prs.slides.add_slide(layout_content)
    add_title_and_subtitle(
        s10,
        "FQA Live Showcase: Autonomous Root-Cause Analysis Video",
        "End-to-End Voice-Driven FQA Investigation & Multimodal Workshop-Photo Extensions",
    )
    add_card(
        s10,
        0.80,
        CARD_TOP,
        7.30,
        4.35,
        "Live RCA on SAS Viya AIoT / FQA",
        "Run: Emerging_Issues_Prod_Last4Years_US_2",
        [
            ("Rank #1 Alert Triage", "Selected top-scored alert (Score 12.16, p = 2.58e-34): Claim Type 1189 × Model 1181 (78 claims / 348 units = 22.41% vs. 13.79% baseline)."),
            ("Cohort Lift vs. 4-Yr Dilution", "Active Jul–Sep 2016 build window revealed a 45.24% claim rate (2.38x lift) for Supplier 1347 + Part 1495 + Transmission 1219."),
            ("Weibull Wear-Out Confirmation", "Reliability modeling proved steep mechanical wear-out (β = 2.09 > 1.0, η = 327.6d TIS) with non-overlapping 95% CIs."),
            ("Single Consolidated Data Selection", "Materialized MCP_Test_Final_Affected_Population (38.89% rate, 1.74x lift, 26.92% alert coverage) + UI Detail Table."),
        ],
        C_BERRY,
    )
    add_card(
        s10,
        0.80,
        6.00,
        7.30,
        4.40,
        "Agent-Built Video & Multimodal Extensions",
        "Automated Video Pipeline + HPE / AWS Showcases",
        [
            ("Automated Dead-Time Condensation", "Agent aligned raw Antigravity CLI screen recordings with Storyboard.md to cut backend polling waits while keeping every insight."),
            ("Polished Narration & Voiceover", "Transcribed, refined technical phrasing without altering numbers, and synthesized a studio voiceover into a 9.5-min showcase."),
            ("Multimodal Workshop Photo Evidence", "Extended with HPE Alletra X10000 Data Intelligence (and AWS stack variant) extracting structured defect metadata from shop photos."),
            ("Playable Right Here on Slide 10", "Click the embedded video on the right to play the full autonomous FQA MCP investigation."),
        ],
        C_BLUE,
    )

    vid_box = s10.shapes.add_shape(
        MSO_SHAPE.ROUNDED_RECTANGLE, Inches(8.35), Inches(CARD_TOP), Inches(10.85), Inches(8.92)
    )
    vid_box.adjustments[0] = 0.015
    vid_box.fill.solid()
    vid_box.fill.fore_color.rgb = C_BG_CARD
    vid_box.line.color.rgb = C_BORDER
    vid_box.line.width = Pt(1.2)

    if os.path.exists(FQA_VIDEO) and os.path.exists(FQA_POSTER):
        s10.shapes.add_movie(
            FQA_VIDEO,
            Inches(8.55),
            Inches(1.68),
            Inches(10.45),
            Inches(8.10),
            poster_frame_image=FQA_POSTER,
            mime_type="video/mp4",
        )
    cap_v = s10.shapes.add_textbox(Inches(8.55), Inches(9.92), Inches(10.45), Inches(0.38))
    cp_v = cap_v.text_frame.paragraphs[0]
    cr_v = cp_v.add_run()
    cr_v.text = "Embedded Video: FQA_MCP_Marketing.mp4 (9m 31s) — Voice Prompt → Antigravity CLI → SAS Viya FQA Root-Cause Synthesis"
    cr_v.font.size = Pt(12.0)
    cr_v.font.bold = True
    cr_v.font.color.rgb = C_NAVY

    set_notes(
        s10,
        """Slide 10 showcases the embedded `FQA_MCP_Marketing.mp4` (`C:\\Users\\germsz\\OneDrive - SAS\\Solutions\\SCI\\FQA\\FQA_MCP\\FQA_MCP_Marketing.mp4`) plus the multimodal workshop-photo evidence showcase (`FQA_HPE_Marketing_4m.mp4` / `fqa-demo-hpe` in `C:\\Git\\Manfred\\FQA`).""",
        """flowchart LR
    A["Raw Antigravity CLI Recordings<br/>+ Storyboard.md"] --> B["Agent Video & Audio Pipeline<br/>Trim Waits + Studio Voiceover"]
    B --> C["FQA_MCP_Marketing.mp4 (9m 31s)<br/>+ HPE/AWS Photo Evidence Demo"]
    C --> D["1 Consolidated Root-Cause DS<br/>+ Persistent FQA UI Detail Table"]""",
    )

    # =========================================================================
    # SLIDE 11: Headless SAS RAM Operations: ram-mcp-server (C:\Git\Manfred\ram-mcp-server)
    # =========================================================================
    s11 = prs.slides.add_slide(layout_content)
    add_title_and_subtitle(
        s11,
        "Headless SAS RAM DevOps: ram-mcp-server (63 MCP Tools)",
        "Full Agent, Template, Pod & Staged-Evaluation Lifecycle Control in C:\\Git\\Manfred\\ram-mcp-server",
    )
    cards_s11 = [
        (
            "ram-mcp-server (63 Headless Tools)",
            "Stdio & Streamable HTTP (:8135) + Node SDK",
            [
                ("Side-by-Side MCP Topology", "Runs on port 8135 right beside sas-mcp-server (:8134), launched via identical uv run app / app-stdio / ram-mcp-login commands."),
                ("Keycloak OAuth2 + 30-Day Keepalive", "Headless Device-Code + PKCE login (~/.sas-ram/token.json), single-flight token refresh mutex, secret redaction, and 20 KB size cap."),
                ("Hardened Programmatic Client", "Exports ram-mcp-server/client for Node/Python orchestrators; stress-tested across all 63 tools & 50 concurrent stateless RPCs."),
            ],
            C_BLUE,
        ),
        (
            "Autonomous RAM Pod & Template Ops",
            "Eliminating Manual Studio Click-Ops",
            [
                ("1-File Template & Tool Sync", "Clones, edits, and publishes Code Agent templates (push_template_dir) and declaratively syncs 71-tool allow-lists in one call."),
                ("Race-Protected Pod Restarts", "restart_dev_server, restart_prod_server, and wait_servers prevent pod race conditions while streaming filtered container logs."),
                ("Staged Gate & Champion Promotion", "run-evals.mjs grades numeric/SQL/trace assertions per stage and promotes verified staging experiments via promote_staging_to_champion."),
            ],
            C_ORANGE,
        ),
        (
            "Seamless Claude ↔ Gemini Continuity",
            "Zero-Loss Multi-Agent Engineering Protocol",
            [
                ("Synchronized Agent Entrypoints", "Maintains aligned AGENTS.md, CLAUDE.md, GEMINI.md, CONTEXT.md, and _docs/HANDOFF.md across both Manfred/ram-mcp-server and Manfred/FQA."),
                ("Instant Quota / Model Switching", "When one frontier model hits quota or session limits, the next agent reads _docs/HANDOFF.md and resumes at the exact gate."),
                ("Shared Tool Server Lifecycle", "tool-server.mjs manages sas-mcp-server-msz container versions (v1.20.2) live on SAS RAM without disrupting active users."),
            ],
            C_GREEN,
        ),
    ]
    for i, (t, tag, b, acc) in enumerate(cards_s11):
        add_card(s11, 0.80 + i * 6.20, CARD_TOP, 6.00, CARD_H_STD, t, tag, b, acc)
    add_fitted_image_box(
        s11,
        os.path.join(SCRATCH, "m10a_ram_mcp_server.png"),
        0.80,
        IMG_TOP_STD,
        18.40,
        IMG_H_STD,
        "Headless SAS RAM Engineering Stack: Claude / Gemini + _docs/HANDOFF.md → ram-mcp-server (63 Tools, :8135) → Staged Gates & Champion Promotion",
    )
    set_notes(
        s11,
        """Slide 11 highlights `C:\\Git\\Manfred\\ram-mcp-server`:
- Originating from the SAS RAM VS Code extension API client and hardened into a 63-tool MCP server (`stdio` + Streamable HTTP on `127.0.0.1:8135`), `ram-mcp-server` gives Claude Code, Antigravity/Gemini, and Python/Node scripts full headless control over SAS Retrieval Agent Manager: Keycloak PKCE auth, template publishing, race-safe dev/prod pod restarts, trace inspection, staged evaluation gates (`run-evals.mjs`), and champion promotion.""",
        get_mermaid_src("m10a_ram_mcp_server"),
    )

    # =========================================================================
    # SLIDE 12: Production FQA Agent on SAS RAM (C:\Git\Manfred\FQA — 3f-msz / v40)
    # =========================================================================
    s12 = prs.slides.add_slide(layout_content)
    add_title_and_subtitle(
        s12,
        "Production FQA Agent on SAS RAM: Champion 3f-msz (Template v40)",
        "Deterministic FSMs, 71 Governed Tools, 558 Unit Tests & 4.8/5.0 SME Certification in C:\\Git\\Manfred\\FQA",
    )
    cards_s12 = [
        (
            "Deterministic FSM + Typed Decisions",
            "fqa_agent 2.22.0 (1-File PEP 621 Wheel Bundle)",
            [
                ("Multi-Turn Driver & 47 Intents", "Zero-LLM fast path for #approve/#undo/#mode, plus DRIVE@v5 session memory, INTERPRET@v14 assist, and ROUTE@v19 across 47 intents."),
                ("AlertFlow & DSFlow State Machines", "Python owns control flow, dual narrow/wide cohort scoping (2m), and 200s/240s budgets; LLMs only answer schema-validated D1–D11 prompts."),
                ("Drastic Token & Latency Savings", "Domain rules, UI catalogs, and bundled CAS queries live inside the RAM + sas-mcp-server-msz:v1.20.2 boundary instead of raw LLM loops."),
            ],
            C_BLUE,
        ),
        (
            "Governed 71-Tool Lifecycle & #undo",
            "31 Read + 40 Strictly Gated Write Tools",
            [
                ("Full FQA Object CRUD (Stages 3–5)", "Creates/deletes scratch & copy Data Selections, 11-col Launchers, 14 Standard + 3 EW Analyses, Projects, and @myFolder members."),
                ("Hard Write-Back & Delete Guards", "writeback.py allow-list blocks free-text 'yes' mutations, restricts deletes to FQAAGENT_ scope, and reconstructs snapshots via #undo."),
                ("Guided Co-Pilot & UI Handbook", "Translates 79 FQA UI variables ↔ DOMAIN.COLUMN, runs option preflight, estimates runtimes, and switches #mode concise/verbose."),
            ],
            C_BERRY,
        ),
        (
            "Certified Champion Quality on RAM",
            "Promoted on FQA_msz (fqa-2h-msz v40)",
            [
                ("558 Offline Tests + 76 Gate Cases", "557/558 unit tests PASS (~35s), DEC-EVAL 46/46 (100% schema & decision agreement), and 34/34 cross-stage live smoke cases PASS."),
                ("4.8 / 5.0 Multi-Persona SME Score", "Passed 5-persona Minimum-Context SME Certification (allHardPass=true, 5/5 personas, 0 raw DB/CAF code leaks) with 0 Viya leftovers."),
                ("4-Quadrant, Launch & CAPA Flows", "Covers Early Warning 3rd time dim (2j), Common Cause screening (2k), Proactive Launch Monitoring & 4-view CAPA verification (2l)."),
            ],
            C_GREEN,
        ),
    ]
    for i, (t, tag, b, acc) in enumerate(cards_s12):
        add_card(s12, 0.80 + i * 6.20, CARD_TOP, 6.00, CARD_H_STD, t, tag, b, acc)
    add_fitted_image_box(
        s12,
        os.path.join(SCRATCH, "m10b_fqa_ram_agent.png"),
        0.80,
        IMG_TOP_STD,
        18.40,
        IMG_H_STD,
        "Champion FQA_msz Architecture on SAS RAM: 47-Intent Router + FSMs + D1–D11 Typed Decisions → 71 Viya MCP Tools → 4.8/5.0 SME Certified Output",
    )
    set_notes(
        s12,
        """Slide 12 showcases the production evolution of `C:\\Git\\Manfred\\FQA` (Manfred Kügel & Martin Schütz, active branch `germsz`, `fqa_agent` `3f-msz` / `v2.22.0`, `fqa-agent-template_msz` **v40** live on champion `fqa-2h-msz` over `sas-mcp-server-msz:v1.20.2`):
- Evolved from an initial 24-tool read-only prototype into a 71-tool governed analytical co-pilot with 47 deterministic intents, `AlertFlow` & `DSFlow` state machines, typed `D1`–`D11` decisions with 100% rule fallbacks, topological `#undo`/`#rollback`, 558 unit tests, 76 smoke gate cases, and a `4.8/5.0` 5-persona SME Certification score.""",
        get_mermaid_src("m10b_fqa_ram_agent"),
    )

    # =========================================================================
    # SLIDE 13: SAS Event Stream Processing (ESP) — C&F Bioreactor UNS Chain
    # =========================================================================
    s13 = prs.slides.add_slide(layout_content)
    add_title_and_subtitle(
        s13,
        "SAS Event Stream Processing (ESP): C&F Bioreactor UNS Chain",
        "Streaming Dual-Clock Biopharma Kafka Telemetry into CAS & Visual Analytics (projects/CandF)",
    )
    cards_s13 = [
        (
            "1. Dual-Clock UNS Bioreactor Edge",
            "Celivion (C&F) CHO Fed-Batch Simulation",
            [
                ("Sequential 3-Reactor Fleet", "Models bio01 & bio02 (2,000 L) and bio03 (5,000 L, exclusive foam-det signal) publishing 14 tags across 10 fed-batch phases + turnaround."),
                ("Compressed Time Scale Reality", "Compresses a 10–14 day biological cycle into ~8–10 min wall-clock (1 real hr ≈ 1.8s; ~1,050 events/batch) with point, DO & glucose anomalies."),
                ("Confluent Cloud Kafka Topic", "Streams CloudEvents + TelemetryEvent JSON to uns.dev.uns.clv.gbl.sas (7-day retention, ~56k msgs/wk; missing specversion tolerated)."),
            ],
            C_ORANGE,
        ),
        (
            "2. CandF_UNS_BMC2 ESP Pipeline",
            "w_source → w_flatten → w_to_cas",
            [
                ("w_source (Kafka Publisher)", "Ingests raw CloudEvents strings via SASL_SSL, kafkatype=opaquestring, disableespmetaconsumer=true, kafkainitialoffset=smallest, blocksize=1000."),
                ("w_flatten (Python Window)", "Parses nested CloudEvent + data payloads in-stream into 18 typed EAV columns, converting ISO-8601 timestamps to µs ESP stamps."),
                ("w_to_cas (CAS Adapter)", "Appends micro-batches every commitblocks=10 directly into in-memory PUBLIC.BMC_RAW (90,635 verified rows, 100% tag_quality='True')."),
            ],
            C_BLUE,
        ),
        (
            "3. Event-Resolution ABT & VA Models",
            "Agent Audit Findings & /Public/BMC Storyboard",
            [
                ("Critical Time-Grid Audit", "Agent review proved 10-min bins averaged away 8–10m batches and mixed JacketTemperature—specifying 15–30s in-batch grids & ce_id dedupe."),
                ("Hysteresis Batch Detection", "Unambiguous 15s run-start signature (TEMP 19.6→36.7 °C + glucose 0→8.9 g/L) with hysteresis prevents mid-run glucose spike splits."),
                ("Three Biopharma VA Use Cases", "Powers /Public/BMC in SAS VA: Cell Viability drop RCA (<70% floor), GAM Time-to-Harvest RUL (<2 g/L), and bio03 Foam-Out trees."),
            ],
            C_GREEN,
        ),
    ]
    for i, (t, tag, b, acc) in enumerate(cards_s13):
        add_card(s13, 0.80 + i * 6.20, CARD_TOP, 6.00, CARD_H_STD, t, tag, b, acc)
    add_fitted_image_box(
        s13,
        os.path.join(SCRATCH, "m11_bioreactor_arch.png"),
        0.80,
        IMG_TOP_STD,
        18.40,
        IMG_H_STD,
        "C&F Bioreactor Streaming Chain: Dual-Clock UNS Simulator → Confluent Kafka → CandF_UNS_BMC2 (SAS ESP) → CAS BMC_RAW / BMC_ABT → SAS VA",
    )
    set_notes(
        s13,
        """Slide 13 reflects the verified state and audit findings in `C:\\Git\\martinoschuetz\\projects\\CandF` (`README.md` & `SESSION_CONTEXT.md`):
- Running ESP project `src/CandF_UNS_BMC2.xml` (`90,635` verified rows in `PUBLIC.BMC_RAW.sashdat`).
- Highlights the compressed dual-clock physics (`10–14` real days ≈ `8–10` min wall-clock) and the forensic code review of `generate_abt.sas` (why 10-min bucketing masked batch resets and `tag_name='temp'` vs. `JacketTemperature`, leading to event-resolution hysteresis run tracking + 15–30s grids).""",
        get_mermaid_src("m11_bioreactor_arch"),
    )

    # =========================================================================
    # SLIDE 14: ESP Breakthroughs: Kafka Replay, CAS Adapter & District Cooling
    # =========================================================================
    s14 = prs.slides.add_slide(layout_content)
    add_title_and_subtitle(
        s14,
        "ESP Breakthroughs: Kafka Replay, CAS Adapter & District Cooling",
        "Distilling knowledge/esp From Official Examples & Scaling to 30 District Cooling Assets (Qatar Cool)",
    )
    cards_s14 = [
        (
            "ESP Skillset & Studio v4 REST API",
            "knowledge/esp/ + Tier 14 MCP Tools",
            [
                ("ESP Notebook + 2026.08 Manuals", "Combined the ESP Gemini Notebook, full grep-able ESP 2026.08 manuals, and sassoftware/esp-studio-examples in knowledge/esp/."),
                ("Bypassing Unconfigured Git", "Built Tier 14 esp_deploy_project & esp_get_project_xml wrapping POST /SASEventStreamProcessingStudio/v4/projects XML payloads."),
                ("Pod-Level Log Diagnostics", "Codified troubleshooting rules directing agents to ESP server pod logs rather than silent Kubernetes operator logs."),
            ],
            C_ORANGE,
        ),
        (
            "Solving Kafka Replay & CAS Drops",
            "Hard-Won Confluent & CAS Adapter Rules",
            [
                ("Confluent Meta-Consumer Bypass", "Set disableespmetaconsumer=true + urlhostport=localhost_31415 with explicit consumer groups to pass Confluent Cloud authorization."),
                ("Deterministic 7-Day History Replay", "Paired opaquestring raw JSON ingestion with low-watermark consumer-group offset resets to replay complete 7-day streams."),
                ("Zero-Drop CAS Appender", "Aligned BIGINT keys and tuned blocksize=1000 + commitblocks=10 to eliminate java.io.EOFException drops after 17.5k events."),
            ],
            C_BERRY,
        ),
        (
            "Scaling to District Cooling (Qatar Cool)",
            "projects/Qatar_Cool (Batch APA + Live ESP)",
            [
                ("30 Assets & 31.52M Measurements", "Hardened shell-free SAS ZIP + %afi_dataload APA pipeline across York YK chillers & cooling towers alongside FQA in QASMartStore."),
                ("Real-Time Chiller & CT ESP Streams", "dcs_chiller runs Python DQ rules + Chiller 18B SVDD ASTORE scoring; dcs_ct computes Range, Approach, Effectiveness & Capability."),
                ("4 Live Grafana Monitoring Boards", "Streams real-time chiller & cooling-tower anomaly alerts directly into 4 operational Grafana dashboards via sasesp-plugin."),
            ],
            C_GREEN,
        ),
    ]
    for i, (t, tag, b, acc) in enumerate(cards_s14):
        add_card(s14, 0.80 + i * 6.20, CARD_TOP, 6.00, CARD_H_STD, t, tag, b, acc)
    add_fitted_image_box(
        s14,
        os.path.join(SCRATCH, "m12_esp_pipeline.png"),
        0.80,
        IMG_TOP_STD,
        18.40,
        IMG_H_STD,
        "Reusable Streaming Blueprint: knowledge/esp Playbooks → Confluent Kafka Replay & CAS Adapter → C&F Bioreactors & Qatar Cool Grafana",
    )
    set_notes(
        s14,
        """Slide 14 connects `C:\\Git\\sas-mcp-server\\knowledge\\esp`, `C:\\Git\\martinoschuetz\\projects\\CandF`, and the recently updated `C:\\Git\\martinoschuetz\\projects\\Qatar_Cool` (commits through `2026-11-16`):
- Shows all 6 chronological ESP fixes from `CandF` plus how the parallel batch AIoT APA (`31.52M` rows, `afi_save_metatables` Postgres deduplication) and real-time ESP (`dcs_chiller` SVDD ASTORE + `dcs_ct` KPIs → 4 Grafana boards) operate in `Qatar_Cool`.""",
        get_mermaid_src("m12_esp_pipeline"),
    )

    # =========================================================================
    # SLIDE 15: SAS AIoT Custom Analysis Framework (CAF) — Vibe-Coding Factory
    # =========================================================================
    s15 = prs.slides.add_slide(layout_content)
    add_title_and_subtitle(
        s15,
        "SAS AIoT Custom Analysis Framework (CAF): Vibe-Coding Factory",
        "Single-Folder Architecture, 12 Live Runtime Rules & 55×–207× Faster VA Templates (AIoT/custom_analysis)",
    )
    cards_s15 = [
        (
            "One-Folder-Per-CAF Factory",
            "C:\\Git\\martinoschuetz\\AIoT\\custom_analysis",
            [
                ("Clean Separation of Concerns", "Authors pure SAS in steps/*.sas, clean UI/SpEL JSON in spec.json, and BIRD templates in output/—never hand-patching 3,500-line XML."),
                ("Zero-Drift Compiler (build_package.py)", "Validates contracts via caf_helpers.validate_spec(), emits ~300-line input_layer.xml for fast diffing, and builds <NAME>.zip."),
                ("Complete Reference Corpus", "Unpacked all 14 SAS STANDARD and 3 ALERTS analysis types into single-folder format alongside 18 live Custom CAFs and Docu/CAF_documentation.md."),
            ],
            C_NAVY,
        ),
        (
            "12 Hard-Won Live Viya CAF Rules",
            "Eliminating Silent UI & Runtime Failures",
            [
                ("RESOLVEONUI & SpEL #ctx Guards", "Restricts RESOLVEONUI=true strictly to STABLEPERIOD (preventing wiped dropdowns) and avoids #ctx.getCurrentStep() on step-open loads."),
                ("<=32-Char CRC32 CAS Table Contract", "Enforces uppercase <=32-char QASAnlOut names ending strictly in _&g_instance_nm plus Step 1 remACs=true self-healing pre-cleanup."),
                ("Tier 15 ETag & steps[0] Plumbing", "Automates If-Match ETag PUT updates (bypassing HTTP 423 locks), display-string sanitization, and steps[0] parameter persistence."),
            ],
            C_BLUE,
        ),
        (
            "Plan A+B+C UI & BIRD Hardening",
            "55×–207× Visual Table Size Reduction",
            [
                ("Rule 11 BIRD XML Rendering", "Replaces discrete <LineChart> with continuous <SeriesPlot> + <TimeOpts>, resets <SASReportState>, and enforces strict alphanumeric BI IDs."),
                ("Lossless High-Frequency Compression", "Uses 600-bucket Min-Max envelopes (~2k rows/asset vs. 732k) and top-250 anomaly-first TreeSHAP rows (<=3,750 rows vs. 778k)."),
                ("Mandatory Zero-Error Smoke Gate", "Every CAF is live-tested end-to-end via Tier 12/15 MCP tools confirming 0 SAS ERROR: lines and clean hydrated VA PDF exports."),
            ],
            C_GREEN,
        ),
    ]
    for i, (t, tag, b, acc) in enumerate(cards_s15):
        add_card(s15, 0.80 + i * 6.20, CARD_TOP, 6.00, CARD_H_STD, t, tag, b, acc)
    add_fitted_image_box(
        s15,
        os.path.join(SCRATCH, "m14a_caf_factory.png"),
        0.80,
        IMG_TOP_STD,
        18.40,
        IMG_H_STD,
        "Vibe-Coding CAF Pipeline: spec.json + steps/*.sas + VA Template → build_package.py --check → Tier 15 ETag Deploy → 0-Error Live Viya Smoke Gate",
    )
    set_notes(
        s15,
        """Slide 15 presents the transformed CAF engineering factory in `C:\\Git\\martinoschuetz\\AIoT\\custom_analysis` (`AGENTS.md`, `Docu/CAF_documentation.md`, and `C:\\Git\\sas-mcp-server\\knowledge\\caf` v2.1.0):
- Shows how the canonical single-folder standard + `build_package.py --check` + 12 live-Viya runtime rules + Plan A+B+C visual compression (`55×–207×` smaller VA tables) allowed us to scale from 1 rewritten SVDD package to **16 live, zero-error production Custom Analysis Types** in days.""",
        get_mermaid_src("m14a_caf_factory"),
    )

    # =========================================================================
    # SLIDE 16: CAF Industrial Anomaly Intelligence Suite & ANOMALY_ENSEMBLE
    # =========================================================================
    s16 = prs.slides.add_slide(layout_content)
    add_title_and_subtitle(
        s16,
        "CAF Anomaly Intelligence Suite & Active Ensemble (KeyGroup = ASSET)",
        "12 Live Single-Folder Anomaly CAFs on Chiller 18B — CoMuT Coupling, Honest Benchmarks & 3-Way SSDO Feedback",
    )
    cards_s16 = [
        (
            "11 Individual Multi-Lens Detectors",
            "Uniform 3-Step UX Live in SAS AIoT (QC)",
            [
                ("Hardened Core (4 Live CAFs)", "SVDD_ASSET (6/6 QC runs), ISOLATION_FOREST (multi-window STABLE_PERIOD + VARSCREEN), 5-step MTS, and ridge-stabilized 3-step MTS_SIMPLE."),
                ("Baseline, Subspace & Drift (3)", "UNIVARIATE_BASE (Wenig MAX_AFTER n=1 anchor), ROBUST_PCA (73.7% Minor-Axis CoMuT share), and KT_MWPCA (Drift a vs. Volatility R²)."),
                ("Nonlinear, Regime, Graph & STFT (4)", "AUTOENCODER (R²=0.93–0.997), GMM_REGIME (K=5 load states), SENSOR_GRAPH_GDN (broken link LCWT→DST), and CAS 2-step SPECTROGRAM."),
            ],
            C_BLUE,
        ),
        (
            "Flagship 4-Step ANOMALY_ENSEMBLE",
            "Fault-Tolerant 8-Engine CAS Committee",
            [
                ("Zero-Crash Multivariate Wrapper", "Eliminates Wenig et al.'s 36% multivariate crash rate via VARCLUS/ridge guards; calibrates all 8 engines onto POT-GPD tail probabilities."),
                ("MAX_AFTER vs. CoMuT & F1–F6 Forms", "Measures Anomaly Arity (n/m), flags pure correlation breaks while tags look normal, and classifies episodes into 6 shop-floor forms."),
                ("Wilcoxon + Keogh–Wu Honest Audit", "Weights engines by Spearman diversity, extracts TreeSHAP + white-box rules, and bans flawed PA-F1 in favor of VUS-PR & triviality checks."),
            ],
            C_ORANGE,
        ),
        (
            "Step 4 Active 3-Way SSDO Feedback",
            "Human-in-the-Loop Learning on Chiller 18B",
            [
                ("3 Distinct Operator Verdicts", "Persists durable episode labels in ANOM_FDBK_<KEY8>: +1 Actionable Fault, 0 Sensor Noise glitch, and -1 Verified Novelty (new normal)."),
                ("Novelty Reject Option Preserved", "Suppresses verified seasonal/load transitions while preserving 100% unsupervised sensitivity outside labeled RBF neighborhoods."),
                ("Verified Live Impact (-53.6% Alarms)", "Across 2 feedback cycles on Chiller 18B: reduced alert episodes 28 → 13 (-53.6%) with +9.25% precision lift, 100% recall & ASTORE export."),
            ],
            C_GREEN,
        ),
    ]
    for i, (t, tag, b, acc) in enumerate(cards_s16):
        add_card(s16, 0.80 + i * 6.20, CARD_TOP, 6.00, CARD_H_STD, t, tag, b, acc)
    add_fitted_image_box(
        s16,
        os.path.join(SCRATCH, "m14b_caf_anomaly_suite.png"),
        0.80,
        IMG_TOP_STD,
        18.40,
        IMG_H_STD,
        "Industrial Anomaly Suite (ANOMALY_SUITE_PLAN.md): 11 Orthogonal ASSET CAFs → 8-Engine POT-GPD Ensemble → Step 4 SSDO (-53.6% False Alarms)",
    )
    set_notes(
        s16,
        """Slide 16 details Phases 0–4 of `C:\\Git\\martinoschuetz\\AIoT\\custom_analysis\\ANOMALY_SUITE_PLAN.md`:
- All 12 `ASSET` CAF packages (`SVDD`, `Isolation_Forest`, `MTS`, `MTS_simple`, `Univariate_Baseline`, `Robust_PCA`, `KT_Chart`, `Autoencoder`, `GMM_Regime`, `Sensor_Graph_GDN`, `Spectrogram`, and 4-step `Anomaly_Ensemble` `revision_no=2`) are built (`blocking_errors=0`), active in Viya Analysis Types, and verified end-to-end on Qatar Cool (`QC` / Chiller 18B) with `0` SAS `ERROR:` lines and verified VA PDFs.""",
        get_mermaid_src("m14b_caf_anomaly_suite"),
    )

    # =========================================================================
    # SLIDE 17: CAF FQA Custom Analysis Suite (KeyGroup = PRODUCT)
    # =========================================================================
    s17 = prs.slides.add_slide(layout_content)
    add_title_and_subtitle(
        s17,
        "CAF FQA Custom Analysis Suite: Bridging Agent RCA into the FQA UI",
        "Closing Six Standard FQA Blind Spots with 1-Click PRODUCT Analysis Types (FQA_SUITE_PLAN.md)",
    )
    cards_s17 = [
        (
            "Native KeyGroup = PRODUCT Bridge",
            "Why CAF Transforms SAS Field Quality",
            [
                ("Closing 6 Standard FQA Blind Spots", "Standard 1D ANOM & greedy trees suffer build-period confounding, <=100-level drops, 4-yr dilution, manual Weibull clicks, and hidden lot-rot."),
                ("1-Click Zero-Config Tenant UX", "Single-step (order=1) PRODUCT CAFs reuse native DATADOMAIN & /tableColumns pickers and auto-tag active EIENTERPRISE alert cells."),
                ("Unit-Level & Censoring Hygiene", "Decodes QASMartStore *_RK surrogates in CAS, guards unsold-unit TIS=0 traps, and aggregates strictly to mature PRODUCT_IDs."),
            ],
            C_BERRY,
        ),
        (
            "Phase 1 Live: Drivers & Recall Scope",
            "Verified in MCP Test (0 SAS Errors/Warnings)",
            [
                ("FQA_RF_DRIVERS (order_no = 30)", "4-learner CAS committee (FOREST + GRADBOOST TreeSHAP + LASSO + Tree) with Wilcoxon CV (AUC = 0.989), CMH de-confounding & BUILDOPTIONS."),
                ("FQA_SUBGROUP_RULES (order_no = 31)", "Non-hierarchical 1/2/3-way Empirical-Bayes beam search enforcing the >=25% alert coverage gate and orthogonal filter pruning."),
                ("Quantified Dilution & Lorenz Gains", "Proved 2.32× 4-year window dilution and 6.46× recall efficiency on Alert Galacto × 9-040 (capturing 50% of claims in 17% of fleet)."),
            ],
            C_BLUE,
        ),
        (
            "Phase 2–3 Live: Weibull, Cox & CAPA",
            "All 6/6 PRODUCT CAFs Live & Verified in Viya",
            [
                ("FQA_COMMON_CAUSE & SURVIVAL_COX", "200-code Weibull MLE 4-Quadrant Matrix ($53M H2) + Cox/LASSO Lot-Rot survival (C = 0.905, HR = 1.82×, $14.9M warranty reserve)."),
                ("FQA_LAUNCH_CAPA (order_no = 34)", "Mart date-hygiene audit + Page's CUSUM / Binomial LR step-change detector (detected Oct-2019 surge Z = 7.82 & β shift 0.82 → 1.21)."),
                ("FQA_PRECURSOR_LINK (order_no = 35)", "Auto-widened vehicle precursor chains (1,517 → 18,099 units), unit-level EB lift (4.14×), First-Time-Fix (92.4%) & $13.7M repeat cost."),
            ],
            C_GREEN,
        ),
    ]
    for i, (t, tag, b, acc) in enumerate(cards_s17):
        add_card(s17, 0.80 + i * 6.20, CARD_TOP, 6.00, CARD_H_STD, t, tag, b, acc)
    add_fitted_image_box(
        s17,
        os.path.join(SCRATCH, "m15_caf_fqa_suite.png"),
        0.80,
        IMG_TOP_STD,
        18.40,
        IMG_H_STD,
        "Next-Gen FQA Custom Suite (KeyGroup = PRODUCT): All 6 Live CAFs Verified in MCP Test (RF Drivers • Subgroup • Weibull • Cox • Launch CAPA • Precursors)",
    )
    set_notes(
        s17,
        """Slide 17 presents `C:\\Git\\martinoschuetz\\AIoT\\custom_analysis\\FQA_SUITE_PLAN.md` (Phases 1 & 2 live & verified `2026-11-20` in project `MCP Test` across both `Alert1_Galacto_9040_DS` and `Production Last 4y in USA` with `0` SAS `ERROR:`/`WARNING:` lines and multi-page VA PDFs):
- Realizes the strategic vision from our earlier deck: complex multi-learner, Empirical-Bayes, portfolio Weibull, and multivariable Cox Lot-Rot analyses are now 1-click native `PRODUCT` Analysis Types inside the FQA UI!""",
        get_mermaid_src("m15_caf_fqa_suite"),
    )

    # =========================================================================
    # SLIDE 18: SAS Optimizer for IoT (C:\Git\martinoschuetz\IOT\AIoT_Optimizer)
    # =========================================================================
    s18 = prs.slides.add_slide(layout_content)
    add_title_and_subtitle(
        s18,
        "SAS Optimizer for IoT: Surrogate & Setpoint Optimization",
        "Rebranded & Re-Architected in IOT/AIoT_Optimizer — UniMeMo Tournament, 163× Faster OPTLSO & React 19 UI",
    )
    cards_s18 = [
        (
            "Rebranded Multi-User Architecture",
            "/Products/SAS Optimizer For IoT (72.6% WPs Done)",
            [
                ("New Product Name & Repo Structure", "Evolved from Energy Cost Optimizer (eco) into SAS Optimizer for IoT under IOT/AIoT_Optimizer (45/62 Work Packages DONE & live)."),
                ("Multi-User Registry & CAS Isolation", "AIOT_META project locks/shares (Demo, Brick WB, Paving VDS) promote .sashdat snapshots into isolated CASUSER sessions in 0.6s."),
                ("7-Pillar Governance DQ & CO₂ Rates", "Profiles ABTs via SASDataGovernance (97.5 DQ score) and enriches shifts with daily TTF/THE Gas & EU ETS CO₂ certificate rates (0 leakage)."),
            ],
            C_NAVY,
        ),
        (
            "Cliques & UniMeMo Surrogate Models",
            "No Free Lunch Verified Live on DEMO & VDS",
            [
                ("Maximal Clique Collinearity Filter", "Runs Kreher–Stinson network.clique (271 cliques), PCA inherent dimension, and 4-selector consensus voting before modeling."),
                ("4-Learner UniMeMo Tournament", "Benchmarks GRADBOOST, FOREST, REGSELECT, and SVMACHINE under time-blocked 5-fold CV with paired Wilcoxon signed-rank tests."),
                ("Quality Gate & Parallel TreeSHAP", "All 4 learner families won live group championships; enforces opt_eligible (R²_CV >= 0.60) and computes target + constraint SHAP."),
            ],
            C_ORANGE,
        ),
        (
            "163× Faster Solver & 5-Report UI",
            "~1.5s/Shift OPTLSO + React 19 DDC Cockpit",
            [
                ("In-Memory FCMP + PROC OPTLSO", "Compiles champion ASTOREs into PROC FCMP inside PROC OPTMODEL over integer MIES PID step lattices (Δx_j) & coupled zone ΔT bounds (~1.5s vs. 270s)."),
                ("5 Restructured VA Reports + React 19", "01 Overview → 02 Project & Metadata SVG Layout → 03 Status/SPC → 04 Ranked Profiler → 05 Full-Width Optimizer with uniform nav footers."),
                ("5-Layer Automated Verification", "Guarded by 94/94 local pytest + Playwright iframe E2E tests and 8 live Viya SAS/CAS/math/security audit suites (79/79 job guards PASS)."),
            ],
            C_GREEN,
        ),
    ]
    for i, (t, tag, b, acc) in enumerate(cards_s18):
        add_card(s18, 0.80 + i * 6.20, CARD_TOP, 6.00, CARD_H_STD, t, tag, b, acc)
    add_fitted_image_box(
        s18,
        os.path.join(SCRATCH, "m16_aiot_optimizer.png"),
        0.80,
        IMG_TOP_STD,
        18.40,
        IMG_H_STD,
        "SAS Optimizer for IoT (IOT/AIoT_Optimizer): AIOT_META & DQ → Clique + 4-Learner UniMeMo → 1.5s FCMP/OPTLSO Solver → 5-Report React 19 Cockpit",
    )
    set_notes(
        s18,
        """Slide 18 introduces the newly rebranded and re-architected **SAS Optimizer for IoT** (`C:\\Git\\martinoschuetz\\IOT\\AIoT_Optimizer`, deployed to `/Products/SAS Optimizer For IoT`):
- 45 of 62 Work Packages (`72.6%`) completed and verified live on `https://iot.viya-azure-gpu.unx.sas.com`.
- Highlights: multi-user `AIOT_META` registry (`Demo`, `Brick Manufacturer`, `Paving Manufacturer`), `SASDataGovernance` 7-pillar DQ, Kreher–Stinson `network.clique` filtering, `UniMeMo` 4-learner Wilcoxon tournament (`GRADBOOST`/`FOREST`/`REGSELECT`/`SVMACHINE`), `163×` speedup via in-memory `PROC FCMP` ASTORE + `PROC OPTLSO` (`~1.5s`/shift), model-vs-model daily Gas/EU ETS $\\text{CO}_2$ savings accounting, and single-file React 19 + Vite DDC bundles across 5 VA reports.""",
        get_mermaid_src("m16_aiot_optimizer"),
    )

    # =========================================================================
    # SLIDE 19: SAS Visual Forecasting — Hybrid 3-Tier Tournament & Auto-Pilot
    # =========================================================================
    s19 = prs.slides.add_slide(layout_content)
    add_title_and_subtitle(
        s19,
        "SAS Visual Forecasting: Hybrid 3-Tier Tournament & Auto-Pilot",
        "Code-First ATSM + EXTLANG + MP-CONNECT Orchestration, Borda Ranking & Dual MinT (Forecasting/)",
    )
    cards_s19 = [
        (
            "Auto-Pilot Profiler & K8s Resilience",
            "4-Parameter CLI (pricedata • m5_subset • m5_full)",
            [
                ("4 Orthogonal CLI Controls", "submit_viya_extlang.py & run_all.py govern --dataset, --hierarchy-level (leaf/dept/cat), --ml-engine, and --foundation-engine."),
                ("01_data_profiler.sas Guardrails", "Auto-switches >20% sparse hierarchies to semi-global department panels and >1,000 series to MP-CONNECT grid workers to prevent 32Gi OOMs."),
                ("WAF-Safe Chunked Ingestion", "Streams 100k-row SWAT chunks and binary ZIP + fcopy (RECFM=N) archives while logging per-series OUTSCALAR runtime telemetry."),
            ],
            C_BLUE,
        ),
        (
            "3-Tier SAS ATSM + OSS Tournament",
            "Push Compute to CAS, EXTLANG & Grid",
            [
                ("1. Native CAS PROC TSMODEL (ATSM)", "Parallel C++ execution of ESM, Auto-ARIMA, ARIMAX (price/cost/discount), UCM, IDM (Croston/SBA), and ATSM_AUTO ensemble."),
                ("2. Distributed CAS EXTLANG (Python)", "Pushes multiplicative Meta Prophet (with promo regressors) and Nixtla StatsForecast AutoARIMA directly onto CAS worker BY-groups."),
                ("3. Global PROC PYTHON / MP-CONNECT", "Runs cross-series MLForecast LightGBM, AutoETS/Theta, NeuralForecast TFT, zero-shot Amazon Chronos-T5, and Bass Diffusion."),
            ],
            C_ORANGE,
        ),
        (
            "9-Metric Borda & Dual MinT",
            "Accuracy, Coherence & Low Nervousness",
            [
                ("9-Metric Borda Count (SUM_rk)", "Ranks leak-free rolling-origin backtests across Bias, WAPE, FA, MASE, RMSSE, MAPE, sMAPE, RMSE & MAE against a SNAIVE FVA floor."),
                ("Cross-Sectional Shrinkage MinT", "PROC IML Schäfer–Strimmer covariance shrinkage reconciles LEAF → LINE → REGION → TOTAL hierarchies coherently."),
                ("Cross-Temporal MinT & Stability", "70_stability.sas reconciles Monthly + Quarterly + Semi-Annual horizons via temporal MinT and audits multi-origin revision nervousness."),
            ],
            C_GREEN,
        ),
    ]
    for i, (t, tag, b, acc) in enumerate(cards_s19):
        add_card(s19, 0.80 + i * 6.20, CARD_TOP, 6.00, CARD_H_STD, t, tag, b, acc)
    add_fitted_image_box(
        s19,
        os.path.join(SCRATCH, "m17_forecasting.png"),
        0.80,
        IMG_TOP_STD,
        18.40,
        IMG_H_STD,
        "11-Stage Forecasting Pipeline (00_setup_cas → 70_stability): Auto-Pilot Profiler → 3-Tier ATSM/EXTLANG/MP-CONNECT → Borda & Dual MinT",
    )
    set_notes(
        s19,
        """Slide 19 reflects the complete 11-stage architecture documented in `C:\\Git\\martinoschuetz\\Forecasting\\README.md` & `AGENT_CONTEXT.md`:
- Highlights the 4 CLI orchestration flags, `01_data_profiler.sas` auto-pilot sparsity/scale routing onto `MP-CONNECT`, 3-tier execution (`ATSM` + `EXTLANG` + `PROC PYTHON`/`MP-CONNECT`), 9-metric Borda `SUM_rk` champion selection vs. `SNAIVE` `FVA`, and both cross-sectional and cross-temporal Schäfer–Strimmer `MinT` reconciliation in `PROC IML`.""",
        get_mermaid_src("m17_forecasting"),
    )

    # =========================================================================
    # SLIDE 20: Visual Forecasting Output Showcase (8-View VA & Unified HTML5)
    # =========================================================================
    s20 = prs.slides.add_slide(layout_content)
    add_title_and_subtitle(
        s20,
        "Agent Build Performance: Tournament Results & Unified Dashboards",
        "8 Automated Diagnostic Views Across SAS Visual Analytics & Multi-Dataset Interactive HTML5 Reports",
    )
    add_card(
        s20,
        0.80,
        CARD_TOP,
        5.80,
        8.95,
        "8-View Diagnostic Output Cascade",
        "SAS VA + Unified Plotly HTML5 + Excel Matrices",
        [
            ("1. ADI / CV² & Champion Mix", "Syntetos–Boylan quadrant split plus node-level breakdown showing where SAS ARIMAX/ATSM vs. LightGBM/Prophet/Chronos win."),
            ("2. 9-Metric Borda Leaderboard", "Top-3 models per hierarchy node ranked by SUM_rk across FA, WAPE, Bias, MASE, RMSSE, sMAPE, and FVA vs. Seasonal Naive."),
            ("3. Staggered Backtest Matrices", "6-cycle rolling out-of-time trajectories exported both to interactive charts and Backtest region.xlsx diagonal matrices."),
            ("4 & 5. Nervousness & Pareto Plot", "Measures multi-origin forecast revision % (70_stability.sas) and plots Accuracy Rank vs. Instability to prevent bullwhip oscillation."),
            ("6 & 7. Convergence & Runtime", "Tracks error convergence as horizon shortens alongside per-series CAS/EXTLANG/Python OUTSCALAR runtime telemetry."),
            ("8. Dual MinT & Automated QC Gate", "Quantifies cross-sectional & temporal MinT impact and enforces automated non-negativity, SNAIVE floor, and metric-parity QC gates."),
        ],
        C_BLUE,
    )
    add_fitted_image_box(
        s20,
        NESTLE_COMP,
        6.85,
        CARD_TOP,
        12.35,
        8.95,
        "Agent Build Performance Output: 8-View Tournament, Stability, MinT Reconciliation & Automated Quality-Control Gate",
    )
    set_notes(
        s20,
        """Slide 20 showcases the 8-part diagnostic output cascade generated in `C:\\Git\\martinoschuetz\\Forecasting\\output\\` (`forecasting_report.html` across `pricedata`, `m5_subset`, `m5_full`, `unified_report.html` with dynamic dataset switching, and the Workshop Slide 75 SAS VA storyboard).""",
        """flowchart LR
    A["11-Stage Viya Execution<br/>(pricedata • m5_subset • m5_full)"] --> B["8 Diagnostic Views<br/>ADI/CV² • Borda Leaderboard • Backtests<br/>Nervousness • Pareto • Convergence"]
    B --> C["Cross-Level & Temporal MinT<br/>+ Automated QC Gate & Unified HTML5"]""",
    )

    # =========================================================================
    # SLIDE 21: The Unified Industrial AI Loop — Chaining All Five Solutions
    # =========================================================================
    s21 = prs.slides.add_slide(layout_content)
    add_title_and_subtitle(
        s21,
        "The Unified Industrial AI Loop: Chaining All Five Solutions",
        "One Shared SAS Viya + SAS RAM MCP Backbone Connecting Edge, Anomaly, Optimization, Quality & Supply",
    )
    cards_s21 = [
        (
            "1. Edge Stream (ESP)",
            "Tier 14 • CandF & QC",
            [
                ("Live UNS Ingestion", "Confluent Kafka + Python flatten + CAS adapter stream plant & chiller tags in sub-seconds."),
                ("Edge Scoring", "Runs online SVDD ASTOREs & Cooling Tower KPIs into CAS and Grafana."),
            ],
            C_ORANGE,
        ),
        (
            "2. Anomaly CAF (ASSET)",
            "Tier 15 • 12 Live CAFs",
            [
                ("8-Engine Ensemble", "Flags single-arity spikes (MAX_AFTER) and hidden CoMuT link breaks (GDN/RPCA)."),
                ("3-Way SSDO Memory", "Captures +1 Fault, 0 Noise, -1 Novelty (-53.6% false alarms)."),
            ],
            C_BLUE,
        ),
        (
            "3. Optimizer for IoT",
            "Tier 0–6 • AIoT_Optimizer",
            [
                ("UniMeMo Surrogates", "Clique-filtered 4-learner Wilcoxon tournament + parallel TreeSHAP."),
                ("1.5s OPTLSO Solver", "Optimizes MIES PID setpoints for daily Gas & EU ETS CO₂ savings."),
            ],
            C_NAVY,
        ),
        (
            "4. FQA + RAM + CAF",
            "Tier 12/15 • v40 + 6 CAFs",
            [
                ("Champion FQA_msz", "47-intent FSM on SAS RAM + 6 live PRODUCT CAFs (AUC=0.989, Cox, CAPA)."),
                ("1 Root-Cause DS", "Quantifies 2.32× dilution, Weibull β & recall scope with #undo safety."),
            ],
            C_BERRY,
        ),
        (
            "5. Visual Forecasting",
            "Tier 12 • 3-Tier + MinT",
            [
                ("ATSM + OSS Grid", "Auto-routes ATSM, EXTLANG & MP-CONNECT ranked by 9-metric Borda."),
                ("Dual MinT Plan", "Reconciles regional & temporal spare-part and energy demand."),
            ],
            C_GREEN,
        ),
    ]
    for i, (t, tag, b, acc) in enumerate(cards_s21):
        add_card(
            s21,
            0.80 + i * 3.72,
            CARD_TOP,
            3.52,
            CARD_H_STD,
            t,
            tag,
            b,
            acc,
            title_pt=15.5,
            tag_pt=11.2,
            bullet_pt=12.0,
        )
    add_fitted_image_box(
        s21,
        os.path.join(SCRATCH, "m21_unified_loop.png"),
        0.80,
        IMG_TOP_STD,
        18.40,
        IMG_H_STD,
        "Closed-Loop Industrial Intelligence: SAS ESP → AIoT Anomaly CAFs → SAS Optimizer for IoT → SAS FQA & RAM v40 → SAS Visual Forecasting",
    )
    set_notes(
        s21,
        """Slide 21 brings all five solution pillars together over our dual MCP backbone (`sas-mcp-server` `v1.20.2` + `ram-mcp-server`):
1. **SAS ESP** ingests high-velocity UNS Kafka & SCADA streams into CAS.
2. **AIoT Anomaly CAFs (`KeyGroup = ASSET`)** isolate multivariate `CoMuT` coupling faults and learn from operator `SSDO` feedback.
3. **SAS Optimizer for IoT** adjusts controllable plant setpoints (`1.5s`/shift `OPTLSO`) to minimize energy & $\\text{CO}_2$ under quality constraints.
4. **SAS FQA + RAM `FQA_msz` (`v40`) + FQA `PRODUCT` CAFs** connect asset/build anomalies to fleet warranty claims, Lot-Rot survival, and recall scope.
5. **SAS Visual Forecasting** feeds Weibull hazard & energy curves into the 3-tier `ATSM` + `OSS` + `MinT` hierarchy to align spares and energy procurement.""",
        get_mermaid_src("m21_unified_loop"),
    )

    # =========================================================================
    # SLIDE 22: Closing & Q&A Slide (Exact Native SAS - Closing White/Light-Blue Theme!)
    # =========================================================================
    s22 = prs.slides.add_slide(layout_closing)
    phs22 = sorted(s22.shapes.placeholders, key=lambda p: p.placeholder_format.idx)
    if len(phs22) > 0:
        style_placeholder_box(
            phs22[0],
            "With Claude, Gemini, SAS RAM & SAS Viya MCP,\nThe Sky Is the Limit — Q&A",
            left=1.370,
            top=3.900,
            width=15.800,
            height=2.300,
            font_pt=46.0,
            color=None,  # Inherits SAS - Closing crisp White (bg1) on SAS Blue bg2!
            bold=None,
        )
    if len(phs22) > 1:
        style_placeholder_box(
            phs22[1],
            "251 Viya MCP + 63 RAM MCP Tools  |  333 OpenAPI Specs  |  7 Live-Verified Skillsets\n"
            "SAS FQA & RAM v40  •  AIoT CAF (18 Live Suites)  •  SAS Optimizer for IoT  •  SAS ESP  •  Visual Forecasting",
            left=1.370,
            top=8.720,
            width=14.100,
            height=1.250,
            font_pt=19.5,
            color=None,  # Inherits SAS - Closing Light Blue (accent3 #C4DEFD) beside white SAS logo!
            bold=None,
        )
    set_notes(
        s22,
        """Closing & Q&A (5–10 minutes):
Recap of what we built and verified live on SAS Viya & SAS RAM:
- **249 Viya MCP Tools (`v1.20.2`) + 63 SAS RAM MCP Tools** backed by **333 OpenAPI specs** and **7 expanded domain skillsets** (`sas-caf` v2.1, `sas-fqa` v0.6, `sas-esp`, `sas-forecasting`, `sas-api`, `sas-core`, `sas-standards`).
- **Production FQA Agent (`3f-msz` / Template `v40`)** on SAS RAM: 47 intents, 71 governed tools, `#undo` safety, 558 unit tests, and `4.8/5.0` 5-persona SME Certification.
- **16 Live Single-Folder Custom Analysis Types** in `custom_analysis` (12 `ASSET` Anomaly detectors incl. 8-engine `ANOMALY_ENSEMBLE` with `SSDO` + 4 live `PRODUCT` FQA Custom Analysis Types).
- **SAS Optimizer for IoT** (`IOT/AIoT_Optimizer`): `UniMeMo` 4-learner tournament, `163×` faster `OPTLSO` setpoint optimization, and 5-report React 19 cockpit.
- **SAS ESP** (`CandF` & `Qatar_Cool`) & **SAS Visual Forecasting** (3-tier `ATSM` + `EXTLANG` + `MP-CONNECT`, 9-metric Borda & Cross-Temporal `MinT`).""",
        """flowchart LR
    A["333 OpenAPI Specs +<br/>7 Live-Verified Skills"] --> D["249 Viya MCP Tools (:8134)<br/>+ 63 RAM MCP Tools (:8135)"]
    C["Claude • Gemini • Antigravity<br/>• SAS RAM Champion Agents"] --> D
    D --> E["FQA • CAF (16 Suites) • Optimizer for IoT<br/>• SAS ESP • Visual Forecasting"]""",
    )

    prs.save(OUT_PPTX)
    print(f"Successfully generated {OUT_PPTX} ({len(prs.slides)} slides)")


if __name__ == "__main__":
    build_deck()
