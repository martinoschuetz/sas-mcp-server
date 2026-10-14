import os
import pptx
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import PP_ALIGN

def build_fqa_standard_analyses_deck():
    template_path = r'C:\Git\martinoschuetz\projects\CandF\SAS External  PowerPoint.pptx'
    output_path = r'C:\Users\germsz\OneDrive - SAS\Solutions\SCI\FQA\Training\MAN_FQA_Training\coursematerials_files\Standaard_Analysis.pptx'

    # Ensure parent dir exists
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    prs = pptx.Presentation(template_path)

    # Clear template dummy slides
    for i in range(len(prs.slides) - 1, -1, -1):
        rId = prs.slides._sldIdLst[i].rId
        prs.part.drop_rel(rId)
        del prs.slides._sldIdLst[i]

    layout_title = prs.slide_layouts[0]     # SAS - Title
    layout_content = prs.slide_layouts[3]   # SAS - Title & Subtitle
    layout_closing = prs.slide_layouts[8]   # SAS - Closing

    # SAS Brand Color Palette
    c_navy = RGBColor(1, 32, 54)        # #012036 Slate/Navy
    c_blue = RGBColor(51, 163, 255)     # #33A3FF SAS Blue
    c_teal = RGBColor(41, 214, 205)     # #29D6CD Teal
    c_green = RGBColor(21, 181, 123)    # #15B57B Green
    c_purple = RGBColor(109, 105, 255)  # #6D69FF Purple
    c_amber = RGBColor(255, 204, 50)    # #FFCC32 Amber/Gold
    c_wine = RGBColor(134, 19, 79)      # #86134F Wine/Burgundy
    c_card_bg = RGBColor(250, 252, 254) # Off-white card fill
    c_card_border = RGBColor(215, 225, 235)
    c_gray = RGBColor(85, 100, 115)     # Subdued gray text
    c_dark = RGBColor(20, 30, 42)       # Primary dark body text

    font_family = "Anova Light"

    def set_slide_header(slide, title_text, subtitle_text):
        for sh in slide.shapes:
            if sh.is_placeholder:
                if sh.placeholder_format.idx == 0:
                    sh.text_frame.word_wrap = True
                    p = sh.text_frame.paragraphs[0]
                    p.text = title_text
                    p.font.name = font_family
                    p.font.bold = True
                    p.font.size = Pt(36)
                    p.font.color.rgb = c_navy
                elif sh.placeholder_format.idx == 10:
                    sh.text_frame.word_wrap = True
                    p = sh.text_frame.paragraphs[0]
                    p.text = subtitle_text
                    p.font.name = font_family
                    p.font.size = Pt(17)
                    p.font.color.rgb = c_gray

    def set_slide_notes(slide, notes_text):
        notes_slide = slide.notes_slide
        tf = notes_slide.notes_text_frame
        tf.text = notes_text.strip()

    def add_card(slide, left, top, width, height, accent_color, header_title, items, subtitle=None):
        # Container shape
        card = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, top, width, height)
        card.fill.solid()
        card.fill.fore_color.rgb = c_card_bg
        card.line.color.rgb = c_card_border
        card.line.width = Pt(1.2)

        # Top Accent Ribbon
        ribbon_h = Inches(0.12)
        ribbon = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, top, width, ribbon_h)
        ribbon.fill.solid()
        ribbon.fill.fore_color.rgb = accent_color
        ribbon.line.fill.background()

        # Text Frame
        pad_x = Inches(0.20)
        pad_y = Inches(0.20)
        title_size = Pt(18.5)
        sub_size = Pt(13)
        item_head_size = Pt(13.5)
        item_body_size = Pt(13)
        space_after = Pt(9)
        sub_space = Pt(11)

        tb = slide.shapes.add_textbox(left + pad_x, top + pad_y, width - 2 * pad_x, height - 2 * pad_y)
        tf = tb.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0

        # Card Title
        p_title = tf.paragraphs[0]
        p_title.text = header_title
        p_title.font.name = font_family
        p_title.font.bold = True
        p_title.font.size = title_size
        p_title.font.color.rgb = c_navy
        p_title.space_after = Pt(4)

        if subtitle:
            p_sub = tf.add_paragraph()
            p_sub.text = subtitle
            p_sub.font.name = font_family
            p_sub.font.size = sub_size
            p_sub.font.bold = False
            p_sub.font.color.rgb = accent_color
            p_sub.space_after = sub_space
        else:
            p_title.space_after = Pt(12)

        for heading, body in items:
            p_item = tf.add_paragraph()
            p_item.space_after = space_after

            run_head = p_item.add_run()
            run_head.text = f"•  {heading}: " if heading else "•  "
            run_head.font.name = font_family
            run_head.font.bold = True
            run_head.font.size = item_head_size
            run_head.font.color.rgb = c_navy

            run_body = p_item.add_run()
            run_body.text = body
            run_body.font.name = font_family
            run_body.font.bold = False
            run_body.font.size = item_body_size
            run_body.font.color.rgb = c_dark

        return card

    # 4-card standard layout coordinates across 20-inch widescreen
    margin_x_4 = Inches(1.00)
    card_y = Inches(2.55)
    card_w_4 = Inches(4.20)
    card_h = Inches(7.30)
    gap_4 = Inches(0.40)

    # =========================================================================
    # SLIDE 1: Title Slide
    # =========================================================================
    s1 = prs.slides.add_slide(layout_title)
    for sh in s1.shapes:
        if sh.is_placeholder:
            if sh.placeholder_format.idx == 0:
                p = sh.text_frame.paragraphs[0]
                p.text = "SAS Field Quality Analytics (FQA)"
                p.font.name = font_family
                p.font.bold = True
                p.font.size = Pt(44)
            elif sh.placeholder_format.idx == 10:
                p = sh.text_frame.paragraphs[0]
                p.text = "Standard Analyses Guide: Purpose, Investigation Triggers, Strategic Value & Reliability Guardrails"
                p.font.name = font_family
                p.font.size = Pt(19)
            elif sh.placeholder_format.idx == 11:
                p = sh.text_frame.paragraphs[0]
                p.text = "MAN FQA Training & Engineering Practice Reference | October 2026"
                p.font.name = font_family
                p.font.size = Pt(15)

    set_slide_notes(
        s1,
        "Welcome to the SAS Field Quality Analytics (FQA) Standard Analyses Guide.\n\n"
        "This deck provides a comprehensive reference for quality engineers, reliability analysts, and warranty specialists. "
        "FQA provides a standardized toolbox of 13 analytical procedures designed to take you from a high-level statistical alert to a verified root-cause mechanism and an actionable recall boundary.\n\n"
        "For each analysis, we outline:\n"
        "1. What it does (core mechanism & methodology)\n"
        "2. When to use it (investigation triggers and funnel placement)\n"
        "3. The business and engineering value it delivers\n"
        "4. Non-negotiable reliability guardrails to prevent analytical errors and false conclusions."
    )

    # =========================================================================
    # SLIDE 2: The Investigation Funnel
    # =========================================================================
    s2 = prs.slides.add_slide(layout_content)
    set_slide_header(
        s2,
        "The FQA Guided Investigation Funnel: A Deductive Methodology",
        "Navigating from Statistical Alerts to Root Cause Containment Across Five Structured Phases"
    )

    add_card(
        s2, margin_x_4, card_y, card_w_4, card_h, c_blue,
        "Phase 0 & 1: Triage & Describe",
        [
            ("Phase 0 (Triage)", "Screen Emerging Issues runs. Differentiate calendar shocks from true manufacturing defects using Time of Event & Trend and Control."),
            ("Phase 1 (Descriptive)", "Identify the physical symptoms, failing components, and regional patterns using Pareto, Summary Tables, and Geographic analysis."),
            ("Deductive Question", "Where is the problem concentrated, which parts/labor codes dominate, and does geography play a role?")
        ],
        subtitle="Symptom Identification"
    )

    add_card(
        s2, margin_x_4 + card_w_4 + gap_4, card_y, card_w_4, card_h, c_teal,
        "Phase 4: Normalize (Run Early!)",
        [
            ("Phase 4 (Normalization)", "Mandatory early step before deep modeling. Normalizes claims by Time in Service (TIS) or mileage using Exposure analysis."),
            ("Weibull Physics", "Fits time-to-failure with suspensions to determine Weibull shape (β < 1 infant mortality vs. β > 1 wear-out)."),
            ("Deductive Question", "Is this an inherent manufacturing/supplier quality flaw or expected fleet wear-and-tear?")
        ],
        subtitle="Failure Mode Validation"
    )

    add_card(
        s2, margin_x_4 + 2 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_green,
        "Phase 2: Segment Cohorts",
        [
            ("Phase 2 (Segmentation)", "Screen high-dimensional database attributes using Statistical Drivers to identify the primary failure factors."),
            ("Targeted Recall Scoping", "Generate boolean inclusion/exclusion rules using Decision Tree partitioning to isolate affected VIN ranges."),
            ("Deductive Question", "Which exact vehicle configurations, assembly plants, or supplier batches carry the defect?")
        ],
        subtitle="Boundary Definition"
    )

    add_card(
        s2, margin_x_4 + 3 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_wine,
        "Phase 3 & Planning: Context",
        [
            ("Phase 3 (Context & Causality)", "Mine repair sequences using Failure Relationships. Cluster unstructured technician notes using Text Mining."),
            ("Ground-Truth Verification", "Review unaggregated claim records in Details Table before signing containment notices."),
            ("Operational Planning", "Project future claim volumes, warranty reserves, and spare part quotas using Event Forecasting.")
        ],
        subtitle="Root Cause & Operations"
    )

    set_slide_notes(
        s2,
        "Slide 2 outlines the overarching investigation philosophy.\n\n"
        "Quality analytics is not about randomly clicking through tools. It is a strict deductive funnel.\n"
        "We start broad in Phase 0 and 1: Triaging alerts and describing the dominant parts and geographic regions.\n"
        "Crucially, our best practice is to run Phase 4 (Normalization) EARLY: We calculate exposure-adjusted rates and Weibull distributions before segmenting cohorts. "
        "If Weibull beta is greater than 1, we are dealing with wear-out, which requires maintenance adjustments. If beta is less than 1, it is a manufacturing defect.\n"
        "Phase 2 segments the cohort to define recall boundaries. Phase 3 inspects technician notes and sequential relationships for physical proof. "
        "Finally, Event Forecasting projects financial liability."
    )

    # =========================================================================
    # SLIDE 3: Pareto Analysis
    # =========================================================================
    s3 = prs.slides.add_slide(layout_content)
    set_slide_header(
        s3,
        "Pareto Analysis: Isolating the Vital Few Failure Modes",
        "Phase 1 – Descriptive: Ranking Quality Problems by Frequency, Rate, and Financial Severity"
    )

    add_card(
        s3, margin_x_4, card_y, card_w_4, card_h, c_blue,
        "Core Analytical Mechanism",
        [
            ("Decreasing Order Ranking", "Ranks levels of a categorical reporting variable (labor code, part number, damage code) by an analytical measure."),
            ("Dual Metric Evaluation", "Evaluates normalized failure rates (claims per 1,000 units) alongside absolute claim volume and total warranty cost."),
            ("Cumulative Distribution", "Overlays the 80/20 cumulative percentage line to identify the dominant subset of components."),
            ("Comparative By-Groups", "Supports grouping by alert flag or production period to compare alert cells directly against baseline cohorts.")
        ],
        subtitle="What It Does"
    )

    add_card(
        s3, margin_x_4 + card_w_4 + gap_4, card_y, card_w_4, card_h, c_teal,
        "When to Pull from Toolbox",
        [
            ("First Post-Alert Step", "Run immediately after scoping an alert to discover which specific parts or labor operations drive the excess claims."),
            ("Ambiguous Symptoms", "When an alert fires on a broad vehicle model line or high-level subsystem code."),
            ("Baseline Comparison", "When evaluating whether a component failure is novel or represents the standard historical failure background.")
        ],
        subtitle="Investigation Triggers"
    )

    add_card(
        s3, margin_x_4 + 2 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_green,
        "Business & Strategic Value",
        [
            ("Triage Prioritization", "Prevents engineering teams from spreading resources across hundreds of minor symptoms; isolates top 1–3 failure causes."),
            ("Supplier Accountability", "Provides immediate evidence of which supplier components represent the largest share of warranty financial liability."),
            ("Cost-Impact Visibility", "Contrasts high-frequency/low-cost repairs against low-frequency/catastrophic failures (e.g. engine replacement).")
        ],
        subtitle="Actionable ROI"
    )

    add_card(
        s3, margin_x_4 + 3 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_wine,
        "Reliability Guardrails",
        [
            ("Avoid Pinned Codes", "If data selection already filters to a specific part, move reporting variable down to failure code or labor code to avoid 1-bar charts."),
            ("Poisson Excess Verification", "Verify top bars with a Poisson excess test against baseline share; flat top bars indicate a weak, non-conclusive signal."),
            ("Group High Cardinality", "If reporting variable exceeds 50 levels, aggregate into component groups first to maintain statistical significance.")
        ],
        subtitle="Key Pitfalls to Avoid"
    )

    set_slide_notes(
        s3,
        "Pareto Analysis is the fundamental Phase 1 descriptive tool.\n\n"
        "When an alert fires in FQA, your first question is: 'What is actually breaking?' Pareto ranks parts, labor codes, and damage codes to isolate the vital few.\n\n"
        "Key best practice: Don't just look at claim counts. Always evaluate normalized claim rates (claims per 1,000 units) and total cost. "
        "A component with 50 claims costing $10,000 each is vastly more critical than a clip with 500 claims costing $2 each.\n\n"
        "Guardrail: If your data selection is already pinned to a specific water pump part number, running a Pareto on part number produces a single meaningless bar. "
        "Move the reporting variable down to the damage code or labor operation."
    )

    # =========================================================================
    # SLIDE 4: Exposure Analysis
    # =========================================================================
    s4 = prs.slides.add_slide(layout_content)
    set_slide_header(
        s4,
        "Exposure Analysis: Normalizing by Time in Service and Mileage",
        "Phase 4 – Normalization (Run Early!): Separating Inherent Manufacturing Defects from Field Usage"
    )

    add_card(
        s4, margin_x_4, card_y, card_w_4, card_h, c_blue,
        "Core Analytical Mechanism",
        [
            ("Exposure Normalization", "Normalizes claim occurrences by accumulated Time in Service (TIS), operating hours, or odometer mileage."),
            ("Early-Life Tracking", "Calculates the proportion of units experiencing a failure within fixed early exposure windows (e.g. 30, 60, or 90 days)."),
            ("Production Month Tracking", "Plots 30-day and 90-day early failure rates across successive monthly vehicle production cohorts."),
            ("Baseline Step Detection", "Identifies the exact step-month where early-life failure rates diverge by 3× or more from historical baseline.")
        ],
        subtitle="What It Does"
    )

    add_card(
        s4, margin_x_4 + card_w_4 + gap_4, card_y, card_w_4, card_h, c_teal,
        "When to Pull from Toolbox",
        [
            ("Run Early in Funnel", "Best practice mandates running Exposure immediately after alert scoping, before attempting deep modeling."),
            ("Investigating Production Shifts", "To determine whether an alert represents a factory assembly change vs. heavy customer usage."),
            ("Validating Containment", "To verify that recent production months returned to healthy baseline rates following a countermeasure.")
        ],
        subtitle="Investigation Triggers"
    )

    add_card(
        s4, margin_x_4 + 2 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_green,
        "Business & Strategic Value",
        [
            ("Eliminates Fleet Aging Bias", "Removes the false impression that older vehicles have higher defect rates simply because they accumulated more time on the road."),
            ("Pinpoints Defect Boundary", "Identifies the exact production week or month where manufacturing quality collapsed, defining immediate plant quarantine."),
            ("Early Defect Discovery", "Catches sharp quality degradations within the first 30 days of vehicle operation, long before full warranty lag matures.")
        ],
        subtitle="Actionable ROI"
    )

    add_card(
        s4, margin_x_4 + 3 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_wine,
        "Reliability Guardrails",
        [
            ("The Immature Cohort Trap", "Never use build months with < 90 days of field exposure as evidence of health; reporting lag creates a false drop."),
            ("True Exposure Source", "If the data mart lacks mileage or operating hours, exposure is time-only; do not claim usage was ruled out."),
            ("In-Service vs. Build Date", "Calculate exposure from the vehicle in-service/registration date; units sitting in storage yards accumulate zero field exposure.")
        ],
        subtitle="Key Pitfalls to Avoid"
    )

    set_slide_notes(
        s4,
        "Exposure Analysis is one of the most powerful tools in FQA, and our standard practice is to run it EARLY in Phase 4.\n\n"
        "Why? Because evaluating raw claim counts is deeply misleading. Older vehicles naturally accumulate more warranty claims simply because they have been driven longer.\n\n"
        "Exposure normalizes claims against Time in Service (TIS). By measuring the 30-day and 90-day early-life failure rates per build month, we can immediately see if a quality step-change occurred. "
        "If build months from May through July show a 10× spike in 30-day failures, you have an open-and-shut factory or supplier quality crisis.\n\n"
        "Guardrail: Watch out for immature build months. Vehicles built last month haven't had time to fail or have their claims entered by dealers. "
        "Never misinterpret the artificial drop in recent months as evidence that the defect disappeared."
    )

    # =========================================================================
    # SLIDE 5: Trend and Control
    # =========================================================================
    s5 = prs.slides.add_slide(layout_content)
    set_slide_header(
        s5,
        "Trend and Control: Statistical Process Control Across Cohorts",
        "Phase 1 – Descriptive: Distinguishing Process Variation from Statistically Significant Quality Shifts"
    )

    add_card(
        s5, margin_x_4, card_y, card_w_4, card_h, c_blue,
        "Core Analytical Mechanism",
        [
            ("Time-of-Build Perspective", "Tracks normalized warranty event rates plotted across sequential production periods (months or weeks)."),
            ("Statistical Control Limits", "Calculates Upper Control Limits (UCL) and Lower Control Limits (LCL) based on historical process variance."),
            ("Exposure Horizon Slicing", "Evaluates trends within standardized exposure windows (e.g. 1-month and 3-month TIS) to track infant mortality."),
            ("Special Cause Detection", "Applies Western Electric SPC rules to detect runs, trends, and points exceeding 3-sigma control boundaries.")
        ],
        subtitle="What It Does"
    )

    add_card(
        s5, margin_x_4 + card_w_4 + gap_4, card_y, card_w_4, card_h, c_teal,
        "When to Pull from Toolbox",
        [
            ("Alert Onset Identification", "To verify the precise production month where failure rates breached normal manufacturing tolerance."),
            ("Ongoing Process Monitoring", "As part of the standard Descriptive Triage Template (fqa_template_descriptive_triage_tool)."),
            ("Countermeasure Validation", "To confirm statistically that an engineering change order returned failure rates below the UCL.")
        ],
        subtitle="Investigation Triggers"
    )

    add_card(
        s5, margin_x_4 + 2 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_green,
        "Business & Strategic Value",
        [
            ("Defensible Quality Audit", "Provides quality directors with an objective, mathematically proven timeline of process breakdown."),
            ("Prevents Knee-Jerk Reactions", "Demonstrates when a minor rise in claims is within normal statistical noise, preventing unnecessary recalls."),
            ("Supplier Trend Verification", "Proves to component suppliers that defect rates breached contractual upper control limits during specific production windows.")
        ],
        subtitle="Actionable ROI"
    )

    add_card(
        s5, margin_x_4 + 3 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_wine,
        "Reliability Guardrails",
        [
            ("Sample Size Verification", "Always inspect the denominator (units built per period); an apparent spike on 20 custom vehicles is statistical noise."),
            ("Reporting Lag Distortion", "Recent production months will trend downward as claims filter through dealer networks; do not assume the trend is improving."),
            ("Pair with Exposure", "Standard Trend and Control charts can blend multiple exposure lengths; pair with Trend by Exposure for rigorous infant mortality tracking.")
        ],
        subtitle="Key Pitfalls to Avoid"
    )

    set_slide_notes(
        s5,
        "Trend and Control brings industrial Statistical Process Control (SPC) directly into the warranty domain.\n\n"
        "It tracks claim rates across production periods and calculates upper and lower control limits (UCL/LCL). "
        "This allows quality managers to distinguish between expected random noise and true special-cause variation.\n\n"
        "Value: When meeting with manufacturing plant managers or component suppliers, Trend and Control provides objective mathematical evidence that a specific build period went out of control.\n\n"
        "Guardrail: Always check the volume of units built in each period. A small production run of specialized chassis will have wider natural variance than a mass-production model."
    )

    # =========================================================================
    # SLIDE 6: Time of Event
    # =========================================================================
    s6 = prs.slides.add_slide(layout_content)
    set_slide_header(
        s6,
        "Time of Event: Calendar Time vs. Production Build Dynamics",
        "Phase 0/1 – Triage: Disambiguating Seasonal Shocks from Inherent Assembly Defects"
    )

    add_card(
        s6, margin_x_4, card_y, card_w_4, card_h, c_blue,
        "Core Analytical Mechanism",
        [
            ("Event Timeline Perspective", "Plots claim counts, normalized rates, or financial cost strictly against calendar repair dates (when the failure happened)."),
            ("Calendar Synchronization", "Aggregates events occurring simultaneously across vehicles regardless of their original build year or mileage."),
            ("Multi-Cohort Comparison", "Overlays multiple vehicle model years on a shared calendar timeline to evaluate synchronized behavior."),
            ("Seasonal Periodicity", "Exposes recurring annual peaks (summer overheating, winter cold-start, rainy season corrosion).")
        ],
        subtitle="What It Does"
    )

    add_card(
        s6, margin_x_4 + card_w_4 + gap_4, card_y, card_w_4, card_h, c_teal,
        "When to Pull from Toolbox",
        [
            ("Diagonal Alert Signatures", "When an Emerging Issues alert displays a diagonal band across the build-period vs. event-period matrix."),
            ("Suspected Environmental Triggers", "When failures correlate with severe weather events (sub-zero freezes, heatwaves, heavy salting)."),
            ("Service Workshop Capacity", "When evaluating seasonal service bay workloads and parts distribution spikes across dealer networks.")
        ],
        subtitle="Investigation Triggers"
    )

    add_card(
        s6, margin_x_4 + 2 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_green,
        "Business & Strategic Value",
        [
            ("Prevents Misdirected Recalls", "Prevents multi-million-dollar factory tooling changes when failures are caused by severe seasonal operating environments."),
            ("Seasonal Campaign Targeting", "Enables proactive seasonal maintenance bulletins (e.g. pre-winter coolant checks, fuel heater inspections)."),
            ("Service Action Impact", "Evaluates whether an OEM service campaign caused an artificial surge in reported claims during a specific calendar quarter.")
        ],
        subtitle="Actionable ROI"
    )

    add_card(
        s6, margin_x_4 + 3 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_wine,
        "Reliability Guardrails",
        [
            ("Do Not Use for Defect Onset", "Time of Event cannot identify when a manufacturing defect was introduced; use Time of Build (Trend/Exposure) for root cause."),
            ("Reporting vs Repair Date", "Ensure analysis uses repair/incident date rather than dealer claim submission date, which suffers from administrative batching."),
            ("Examine Cross-Model Year Spread", "If an event spike affects 5 consecutive model years simultaneously in January, the cause is 100% environmental/calendar-driven.")
        ],
        subtitle="Key Pitfalls to Avoid"
    )

    set_slide_notes(
        s6,
        "Time of Event provides the essential counterpart to Time of Build.\n\n"
        "Most quality investigations naturally focus on build date. But Time of Event looks strictly at calendar repair dates.\n\n"
        "Why is this vital? Because environmental and seasonal stressors hit entire fleets at the exact same moment. "
        "If you see a surge in battery failures or air suspension leaks across 2021, 2022, 2023, and 2024 model years simultaneously in January, that is NOT a manufacturing defect. "
        "That is an environmental freeze event. Time of Event prevents companies from recalling factories when the root cause is external climate."
    )

    # =========================================================================
    # SLIDE 7: Geographic Analysis
    # =========================================================================
    s7 = prs.slides.add_slide(layout_content)
    set_slide_header(
        s7,
        "Geographic Analysis: Regional Stressors and Negative Controls",
        "Phase 1 – Descriptive: Mapping Territorial Concentrations and Environmental Dependencies"
    )

    add_card(
        s7, margin_x_4, card_y, card_w_4, card_h, c_blue,
        "Core Analytical Mechanism",
        [
            ("Spatial Rate Mapping", "Plots normalized warranty claim rates, event counts, or total cost on world, continental, or state/provincial maps."),
            ("Choropleth Color Scaling", "Applies statistical color gradients to highlight regional deviation above the national or global average."),
            ("Multi-Level Geographies", "Slices data by customer registration territory, selling dealer country, or repairing workshop location."),
            ("Macro-Territory Grouping", "Enables aggregation by climate zones, emissions regulatory regions, or infrastructure quality bands.")
        ],
        subtitle="What It Does"
    )

    add_card(
        s7, margin_x_4 + card_w_4 + gap_4, card_y, card_w_4, card_h, c_teal,
        "When to Pull from Toolbox",
        [
            ("Suspected Climatic Stress", "Investigating failures related to road salt corrosion, dust ingestion, extreme ambient heat, or altitude."),
            ("Fuel & Fluid Incompatibilities", "When defect reports suspect regional bio-diesel blends, AdBlue quality, or sulfur content variations."),
            ("Negative Control Verification", "Used as a mandatory negative control: a true factory assembly defect should show uniform geographic distribution.")
        ],
        subtitle="Investigation Triggers"
    )

    add_card(
        s7, margin_x_4 + 2 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_green,
        "Business & Strategic Value",
        [
            ("Localized Containment", "Enables geographically bounded field actions (e.g. cold-weather heating kits restricted to Nordic countries), saving 85% vs. global recalls."),
            ("Dealer Fraud & Audit", "Detects abnormal regional clusters indicating dealer billing anomalies or aggressive repair behavior rather than physical defects."),
            ("Market Specification Design", "Informs engineering teams whether regional heavy-duty protection packages should be standard in specific markets.")
        ],
        subtitle="Actionable ROI"
    )

    add_card(
        s7, margin_x_4 + 3 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_wine,
        "Reliability Guardrails",
        [
            ("Always Map Rates, Not Counts", "Never map raw claim counts; count maps simply reflect fleet sales density and show high claims wherever sales are largest."),
            ("Product vs Claim Geography", "Use product-level location (customer/selling dealer); repairing workshop location lacks a valid non-failed vehicle denominator."),
            ("Watch Out for Fleet Routing", "Commercial vehicles registered in one central depot may operate internationally; confirm duty cycle before assuming climate causality.")
        ],
        subtitle="Key Pitfalls to Avoid"
    )

    set_slide_notes(
        s7,
        "Geographic Analysis maps warranty performance across states, provinces, and countries.\n\n"
        "Its primary purpose is twofold:\n"
        "First, detecting environmental and regional duty-cycle stressors. If fuel pump failures cluster heavily in one specific country, you may be dealing with regional fuel contamination or high sulfur content rather than a pump manufacturing defect.\n\n"
        "Second, Geographic Analysis acts as a crucial 'negative control'. If an engineer claims an alternator bracket has a fatal design flaw, but the failure rate is 10× higher in coastal regions and zero inland, you are likely looking at road salt corrosion rather than pure mechanical fatigue.\n\n"
        "Guardrail: Always map claim rates (claims per 1,000 registered units). If you map raw counts, you just produce a population map of where your company sells the most trucks."
    )

    # =========================================================================
    # SLIDE 8: Summary Tables
    # =========================================================================
    s8 = prs.slides.add_slide(layout_content)
    set_slide_header(
        s8,
        "Summary Tables: Multi-Dimensional Cross-Tabulation & Skew Detection",
        "Phase 1 – Descriptive: Uncovering Complex Interactions Across Product and Manufacturing Attributes"
    )

    add_card(
        s8, margin_x_4, card_y, card_w_4, card_h, c_blue,
        "Core Analytical Mechanism",
        [
            ("Multi-Way Tabular Output", "Generates cross-tabulations incorporating up to three nested reporting variables (e.g., Model × Engine × Build Quarter)."),
            ("Dual Numerator & Denominator", "Displays both distinct failing vehicle counts (`PRODUCT_ID`) and total population units to compute exact localized rates."),
            ("Flexible Measure Aggregation", "Summarizes total warranty cost, claim counts, labor hours, and exposure-adjusted failure percentages simultaneously."),
            ("External Result Writeback", "Acts as the platform-compliant UI placeholder node for displaying specialized statistics computed outside FQA.")
        ],
        subtitle="What It Does"
    )

    add_card(
        s8, margin_x_4 + card_w_4 + gap_4, card_y, card_w_4, card_h, c_teal,
        "When to Pull from Toolbox",
        [
            ("Flat or Ambiguous Pareto", "When a Pareto chart shows a broad, flat distribution across parts, requiring multi-attribute slicing to find the pattern."),
            ("Confounding Checks", "To test whether top statistical drivers are confounded with production build periods (e.g. cross-tabulating driver levels vs quarters)."),
            ("Executive Proof Sheets", "When creating detailed tabular briefings for cross-functional quality reviews and supplier accountability meetings.")
        ],
        subtitle="Investigation Triggers"
    )

    add_card(
        s8, margin_x_4 + 2 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_green,
        "Business & Strategic Value",
        [
            ("Exposes Categorical Skew", "Quickly reveals hidden interactions (e.g., 'Failure code 402 appears across all models, but ONLY when paired with Assembly Plant B')."),
            ("Supplier Lot Verification", "Enables side-by-side comparison of competing suppliers delivering the identical component across vehicle platforms."),
            ("Complete Data Visibility", "Provides engineers with an exhaustive, auditable view of vehicle counts and claim volumes across all operating segments.")
        ],
        subtitle="Actionable ROI"
    )

    add_card(
        s8, margin_x_4 + 3 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_wine,
        "Reliability Guardrails",
        [
            ("Cardinality Limits", "Limit reporting variables to < 50 levels per dimension; high-cardinality cross-tabs create sparse, uninterpretable tables."),
            ("Rate vs Volume Balance", "Never evaluate matrix cells based solely on claim counts; a small cell with 5 claims out of 10 vehicles is a 50% failure rate disaster."),
            ("Count Distinct Units", "Ensure multi-claim repairs on the same chassis do not artificially inflate cell percentages; verify unit-level uniqueness.")
        ],
        subtitle="Key Pitfalls to Avoid"
    )

    set_slide_notes(
        s8,
        "Summary Tables provide multi-dimensional cross-tabulation across up to three reporting variables simultaneously.\n\n"
        "When a Pareto chart is inconclusive, Summary Tables allow you to cross-tabulate failure codes against vehicle chassis, engine family, and assembly plant. "
        "This immediately exposes hidden skew: for instance, proving that a steering vibration issue occurs across all vehicle models, but strictly when assembled at Plant 2.\n\n"
        "Value: In supplier reviews and engineering change meetings, Summary Tables provide the definitive, auditable data grid with both numerators and denominators.\n\n"
        "Guardrail: Watch out for cardinality. Slicing 50 part numbers by 30 dealers and 24 months results in 36,000 cells. Aggregate into component groups first."
    )

    # =========================================================================
    # SLIDE 9: Reliability (Weibull Analysis)
    # =========================================================================
    s9 = prs.slides.add_slide(layout_content)
    set_slide_header(
        s9,
        "Reliability (Weibull): Decoding Physical Failure Mechanisms",
        "Phase 4 – Normalization: Hazard Rate Modeling, Suspensions & Physical Defect Physics"
    )

    add_card(
        s9, margin_x_4, card_y, card_w_4, card_h, c_blue,
        "Core Analytical Mechanism",
        [
            ("Parametric Lifetime Modeling", "Fits time-to-first-failure data with right-censored suspensions (non-failed units) to a Weibull statistical distribution."),
            ("Shape Parameter (Beta)", "Estimates β: β < 1 indicates infant mortality (quality/defect); β ≈ 1 indicates random; β > 1 indicates wear-out."),
            ("Characteristic Life (Eta)", "Calculates η (scale parameter): the operating age at which 63.2% of the population is expected to fail."),
            ("B10 / B50 Extrapolation", "Mathematically projects the exact Time in Service or mileage where 10% and 50% of the fleet will experience failure.")
        ],
        subtitle="What It Does"
    )

    add_card(
        s9, margin_x_4 + card_w_4 + gap_4, card_y, card_w_4, card_h, c_teal,
        "When to Pull from Toolbox",
        [
            ("Defect Classification", "To determine whether an alert represents a factory assembly/supplier defect or expected long-term wear and fatigue."),
            ("Comparing Build Cohorts", "Comparing alert build periods vs. historical baseline builds; a lower β in alert builds confirms an assembly change."),
            ("Warranty Reserve Setting", "Projecting cumulative 12-, 24-, and 36-month failure probabilities for actuarial warranty reserves.")
        ],
        subtitle="Investigation Triggers"
    )

    add_card(
        s9, margin_x_4 + 2 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_green,
        "Business & Strategic Value",
        [
            ("Decisive Engineering Mandate", "Beta < 1 legally and contractually proves an assembly or supplier manufacturing defect, driving 100% supplier recovery."),
            ("Prevents Misguided Redesign", "Beta > 1.5 proves fatigue/wear-out, directing engineers to revise maintenance intervals rather than blaming factory assembly."),
            ("Actuarial Precision", "Allows corporate finance to project ultimate lifetime warranty costs based on rigorous lifetime distributions.")
        ],
        subtitle="Actionable ROI"
    )

    add_card(
        s9, margin_x_4 + 3 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_wine,
        "Reliability Guardrails",
        [
            ("Never Omit Suspensions", "You CANNOT fit Weibull only on failed vehicles; surviving units are censored data. Omitting them invalidates the entire fit!"),
            ("Minimum Event Threshold", "Requires ≥ 30 distinct failures and an adequate age spread; fitting on a 1-month-old cohort yields uninterpretable wide intervals."),
            ("Fit from In-Service Date", "Measure time-to-failure from customer in-service date; yard storage time does not accumulate physical component wear.")
        ],
        subtitle="Key Pitfalls to Avoid"
    )

    set_slide_notes(
        s9,
        "Reliability Analysis (Weibull) is the mathematical bedrock of physical failure analysis.\n\n"
        "It fits failure times—incorporating non-failed vehicles as right-censored suspensions—to determine the Weibull shape parameter, Beta (β):\n"
        "- If β < 1: The hazard rate is decreasing with age. This is the classic signature of 'Infant Mortality'. It proves a manufacturing assembly error or defective supplier lot. "
        "Vehicles are failing immediately after leaving the showroom.\n"
        "- If β ≈ 1: The failure rate is constant. This indicates purely random external events (e.g. stone chips, random electrical surges).\n"
        "- If β > 1: The failure rate increases with age. This indicates mechanical wear-out, fatigue, or corrosion.\n\n"
        "Crucial Guardrail: You cannot run Weibull analysis only on failed vehicles! The non-failed vehicles represent the censored survival population. "
        "If you exclude survivors, your calculated hazard rate is mathematically meaningless."
    )

    # =========================================================================
    # SLIDE 10: Statistical Drivers
    # =========================================================================
    s10 = prs.slides.add_slide(layout_content)
    set_slide_header(
        s10,
        "Statistical Drivers: High-Dimensional Attribute Screening",
        "Phase 2 – Segmentation: Isolating Main Effects and Screening Confounded Predictors"
    )

    add_card(
        s10, margin_x_4, card_y, card_w_4, card_h, c_blue,
        "Core Analytical Mechanism",
        [
            ("Multi-Factor Scanning", "Statistically evaluates dozens of categorical attributes simultaneously against elevated warranty claim rates."),
            ("Statistical Significance Ranking", "Ranks candidate variables by Chi-Square test statistics, p-values, and entropy reduction."),
            ("Dimensionality Reduction", "Screens out irrelevant noise variables, passing only verified high-impact predictors to decision tree modeling."),
            ("Stratified Confounding Analysis", "Enables cross-checking within build-quarter strata to detect whether a driver is genuinely causal or confounded by time.")
        ],
        subtitle="What It Does"
    )

    add_card(
        s10, margin_x_4 + card_w_4 + gap_4, card_y, card_w_4, card_h, c_teal,
        "When to Pull from Toolbox",
        [
            ("Post-Descriptive Investigation", "Run immediately after Phase 1 to determine what *kind* of attribute drives the defect (factory, supplier, model, or dealer)."),
            ("High-Dimensional Exploration", "When vehicles have hundreds of optional configuration codes, and engineers have no initial hypothesis."),
            ("Pre-Tree Variable Selection", "To prune collinear and redundant variables before running a decision tree.")
        ],
        subtitle="Investigation Triggers"
    )

    add_card(
        s10, margin_x_4 + 2 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_green,
        "Business & Strategic Value",
        [
            ("Eliminates Human Bias", "Replaces subjective engineering hunches with objective statistical ranking across the entire enterprise vehicle database."),
            ("Rapid Hypothesis Generation", "Surfaces unexpected root-cause factors (e.g., discovering that alternator failure correlates with a specific dual-compressor AC option)."),
            ("Accelerates Triage Time", "Reduces feature exploration from days of manual SQL querying to a 2-minute automated statistical scan.")
        ],
        subtitle="Actionable ROI"
    )

    add_card(
        s10, margin_x_4 + 3 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_wine,
        "Reliability Guardrails",
        [
            ("Prune Collinear Variables", "Keep only ONE time attribute (drop engine build date, delivery date, registration date if vehicle build date is included)."),
            ("Drop Post-Repair Attributes", "Exclude 'current engine code' or post-repair odometer; these reflect post-repair state and leak the outcome!"),
            ("Check Production Confounding", "Always verify that a top driver (e.g. software version) is not simply confounded with the alert build months.")
        ],
        subtitle="Key Pitfalls to Avoid"
    )

    set_slide_notes(
        s10,
        "Statistical Drivers is our Phase 2 dimensionality-reduction engine.\n\n"
        "In modern automotive and industrial manufacturing, each vehicle has hundreds of build codes, option packages, supplier identifiers, and plant codes. "
        "Quality engineers cannot manually query every possible combination.\n\n"
        "Statistical Drivers evaluates every candidate variable against the elevated claim rate, ranking them by statistical divergence. "
        "It tells you immediately whether the issue is driven by a supplier code, an assembly plant, a transmission type, or a dealer territory.\n\n"
        "Guardrail: Watch out for 'outcome leakage'. If your dataset contains 'Current Engine Type', that field may reflect what the dealer installed *after* the failure. "
        "Always use as-built manufacturing variables."
    )

    # =========================================================================
    # SLIDE 11: Decision Tree
    # =========================================================================
    s11 = prs.slides.add_slide(layout_content)
    set_slide_header(
        s11,
        "Decision Tree: Targeted Recall Scoping and Boundary Rules",
        "Phase 2 – Segmentation: High-Purity Boolean Partitioning for Defect Containment"
    )

    add_card(
        s11, margin_x_4, card_y, card_w_4, card_h, c_blue,
        "Core Analytical Mechanism",
        [
            ("Recursive Partitioning", "Builds a shallow classification tree (3–4 levels deep) segmenting failed units from non-failed units."),
            ("Multi-Variable Interaction", "Discovers complex non-linear attribute interactions (e.g. Chassis Series X + Plant Y + Supplier Lot Z)."),
            ("High-Purity Leaf Isolation", "Identifies specific terminal leaves exhibiting extreme failure rate concentration (>50% claim rates)."),
            ("Explicit Boolean Rules", "Outputs explicit boolean filter rules that can be directly applied to vehicle registries to generate recall VIN lists.")
        ],
        subtitle="What It Does"
    )

    add_card(
        s11, margin_x_4 + card_w_4 + gap_4, card_y, card_w_4, card_h, c_teal,
        "When to Pull from Toolbox",
        [
            ("Recall & Service Campaign Scoping", "When preparing an official safety recall or technical service bulletin (TSB) and needing exact vehicle boundaries."),
            ("Interacting Root Causes", "When single-factor Pareto or Drivers cannot explain the defect, indicating an interaction between components."),
            ("Supplier Liability Demarcation", "When isolating the exact production date cutoff where a supplier's defective component lot was introduced and purged.")
        ],
        subtitle="Investigation Triggers"
    )

    add_card(
        s11, margin_x_4 + 2 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_green,
        "Business & Strategic Value",
        [
            ("Massive Cost Avoidance", "Narrows recall scope from 500,000 general vehicles down to the exact 12,000 defective units, saving tens of millions in recall parts/labor."),
            ("Regulatory Defensibility", "Provides vehicle safety regulators (NHTSA, KBA) with mathematical proof that un-recalled vehicles are unaffected."),
            ("Immediate Plant Action", "Allows plant quality managers to immediately quarantine specific vehicle configurations still on factory property.")
        ],
        subtitle="Actionable ROI"
    )

    add_card(
        s11, margin_x_4 + 3 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_wine,
        "Reliability Guardrails",
        [
            ("The Censoring Trap", "Restrict training population to units that reached target exposure; immature units enter as false negatives and invert the model!"),
            ("Keep Trees Shallow", "Limit depth to 3–4 levels; deep trees overfit small claim counts and produce un-executable rules in vehicle databases."),
            ("Minimum Leaf Event Count", "Ensure target leaves contain ≥ 15–20 actual failed units, not just a high percentage on 2 vehicles.")
        ],
        subtitle="Key Pitfalls to Avoid"
    )

    set_slide_notes(
        s11,
        "Decision Tree is the premier tool for Phase 2 Segmentation and Recall Scoping.\n\n"
        "Its ultimate business deliverable is a Boolean rule: 'Recall vehicles where Model = TGX AND Plant = Munich AND Supplier = Lot_42 AND Build_Date BETWEEN May_1 AND July_15.'\n\n"
        "Value: In modern manufacturing, a full fleet recall can bankrupt a program. Decision Tree isolates the exact multi-attribute interaction, narrowing a recall from 500,000 vehicles down to the 12,000 actually affected. "
        "That single analysis can save $40M in unnecessary parts and dealer labor.\n\n"
        "Guardrail: Beware of the 'Censoring Trap'! If newly built vehicles (which haven't had time to fail yet) enter the tree, the algorithm will see them as healthy and create a rule saying 'Recent builds are safe!' "
        "Always restrict the population to vehicles that have reached maturity."
    )

    # =========================================================================
    # SLIDE 12: Failure Relationships
    # =========================================================================
    s12 = prs.slides.add_slide(layout_content)
    set_slide_header(
        s12,
        "Failure Relationships: Chronological Sequences & Association Mining",
        "Phase 3 – Context & Causality: Distinguishing Root Cause Failures from Collateral Damage"
    )

    add_card(
        s12, margin_x_4, card_y, card_w_4, card_h, c_blue,
        "Core Analytical Mechanism",
        [
            ("Sequential Association Mining", "Mines chronological repair sequences across multiple repairs on the same unique vehicle (`PRODUCT_ID`)."),
            ("Time-Lag Windows", "Evaluates cross-code associations occurring within defined time windows (e.g. Repair A followed by Repair B within 30 days)."),
            ("Statistical Lift & Confidence", "Calculates Lift and Confidence metrics to prove that two repair codes occur together far more often than chance."),
            ("Multi-Domain Linking", "Links primary labor operations to secondary replaced parts, diagnostic trouble codes (DTCs), and damage codes.")
        ],
        subtitle="What It Does"
    )

    add_card(
        s12, margin_x_4 + card_w_4 + gap_4, card_y, card_w_4, card_h, c_teal,
        "When to Pull from Toolbox",
        [
            ("Surprising Pareto Findings", "When Pareto ranks a component that seems physically improbable as the primary failure mode."),
            ("Repeat Repair Investigations", "When vehicles return to dealer workshops multiple times for the identical customer complaint."),
            ("Suspected Consequential Damage", "To determine whether a catastrophic component failure (e.g. blown turbocharger) was caused by an upstream failure (oil line clog).")
        ],
        subtitle="Investigation Triggers"
    )

    add_card(
        s12, margin_x_4 + 2 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_green,
        "Business & Strategic Value",
        [
            ("Identifies the True Root Cause", "Prevents redesigning the wrong component; proves that replacing Part B is merely treating a symptom caused by Part A."),
            ("Supplier Recovery Protection", "Defends against supplier disputes by proving that their component failure was triggered by upstream failure of another vendor's part."),
            ("Technician Repair Guidelines", "Generates updated workshop repair instructions (e.g. 'Whenever replacing Component X, mandatory inspection of Valve Y is required').")
        ],
        subtitle="Actionable ROI"
    )

    add_card(
        s12, margin_x_4 + 3 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_wine,
        "Reliability Guardrails",
        [
            ("Do Not Restrict to Alert Part", "Mine across the full vehicle population; if the dataset is filtered strictly to the alert part, cross-code sequences cannot be discovered."),
            ("Do Not Condition on Outcome", "Never condition on 100% failed units; base rates collapse and Lift statistics become mathematically invalid."),
            ("Elapsed Time Requirement", "Requires vehicles with sufficient field operating time; a fleet at 1 month in service has had only one claim and no chronology.")
        ],
        subtitle="Key Pitfalls to Avoid"
    )

    set_slide_notes(
        s12,
        "Failure Relationships is our Phase 3 chronological sequence engine.\n\n"
        "In complex machinery, parts don't fail in isolation. An upstream component fails, which starves a secondary component of oil or coolant, causing a catastrophic breakdown.\n\n"
        "If technicians always replace the secondary part, the Pareto chart will blame the secondary part! "
        "Failure Relationships mines the chronological repair history of individual vehicles. It calculates statistical Lift to prove: "
        "'Repair A precedes Repair B within 14 days with a Lift of 25.0.'\n\n"
        "Value: It prevents your engineering team from redesigning Part B when Part A was the culprit all along.\n\n"
        "Guardrail: You cannot run this on a dataset pre-filtered to Part B! If only Part B claims exist in your table, there are no other codes to sequence against. "
        "Mine across the broader model population."
    )

    # =========================================================================
    # SLIDE 13: Text Mining
    # =========================================================================
    s13 = prs.slides.add_slide(layout_content)
    set_slide_header(
        s13,
        "Text Mining: Unstructured Technician Notes & Symptom Clustering",
        "Phase 3 – Context & Causality: Mining Unstructured Narratives to Uncover Hidden Defect Themes"
    )

    add_card(
        s13, margin_x_4, card_y, card_w_4, card_h, c_blue,
        "Core Analytical Mechanism",
        [
            ("Natural Language Processing", "Applies tokenization, lemmatization, stop-word filtering, and synonym resolution to free-text warranty narratives."),
            ("Singular Value Decomposition", "Extracts underlying mathematical text dimensions (SVD) and performs k-means clustering to form symptom topics."),
            ("Term & Concept Mapping", "Surfaces top terms, key phrases, and concept clouds associated with each distinct failure cluster."),
            ("Cluster Assignment", "Assigns a dominant cluster topic ID to each warranty record, allowing text themes to be cross-tabulated with structured attributes.")
        ],
        subtitle="What It Does"
    )

    add_card(
        s13, margin_x_4 + card_w_4 + gap_4, card_y, card_w_4, card_h, c_teal,
        "When to Pull from Toolbox",
        [
            ("Generic Diagnostic Codes", "When warranty claims are logged under vague bucket codes (e.g. 'Electrical Fault', 'Unspecified Noise', 'Oil Leak')."),
            ("Early Symptom Emergence", "When tracking new failure modes before official diagnostic trouble codes (DTCs) exist in dealership software."),
            ("Customer vs. Technician Disconnect", "When needing to compare what the driver reported vs. what the mechanic physically repaired.")
        ],
        subtitle="Investigation Triggers"
    )

    add_card(
        s13, margin_x_4 + 2 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_green,
        "Business & Strategic Value",
        [
            ("Discovers Hidden Failure Modes", "Differentiates multiple failure mechanisms hidden under a single part code (e.g. separating 'leak at fitting' from 'hose burst')."),
            ("Weeks Faster Discovery", "Extracts emerging quality signals weeks before standardized warranty coding rules are updated across dealer networks."),
            ("Informs Engineering Redesign", "Provides mechanical engineers with specific physical descriptions (cracking, seizing, stripped threads, burning).")
        ],
        subtitle="Actionable ROI"
    )

    add_card(
        s13, margin_x_4 + 3 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_wine,
        "Reliability Guardrails",
        [
            ("Separate Tech from Customer", "Always run text mining separately on TECH_COMMENT vs CSTMR_COMMENT; mechanics describe parts, drivers describe sounds."),
            ("Keep Topic Count Low", "Limit clusters to 3–5 topics; high cluster counts fragment genuine mechanical themes into statistical noise."),
            ("Cross-Tab Against Build Months", "Cross-tabulate text clusters against build quarters; a cluster appearing only in recent builds proves a new physical failure mode.")
        ],
        subtitle="Key Pitfalls to Avoid"
    )

    set_slide_notes(
        s13,
        "Text Mining unlocks the goldmine of unstructured dealership narratives.\n\n"
        "Structured warranty codes are often coarse: a dealership technician might select a generic code like 'Engine Oil Leak'. "
        "That code tells you nothing about the physical failure mechanism.\n\n"
        "Text Mining processes the technician's notes using NLP and k-means clustering. It groups claims into distinct physical themes: "
        "Cluster 1: 'crimp fitting leak at cooler line'; Cluster 2: 'gasket porosity'; Cluster 3: 'stripped drain plug threads'.\n\n"
        "Value: You instantly discover that 90% of the leak claims are driven by a defective supplier crimp fitting on recent builds.\n\n"
        "Guardrail: Keep topic counts low (3 to 5). Never mix customer comments and technician comments in the same run—technicians use mechanical vocabulary, while drivers use sensory terms."
    )

    # =========================================================================
    # SLIDE 14: Details Table (Detail Report)
    # =========================================================================
    s14 = prs.slides.add_slide(layout_content)
    set_slide_header(
        s14,
        "Details Table: Granular Ground-Truth Verification",
        "Phase 3 – Context & Ground Truth: Unaggregated Claim Audits and Engineering Reality Checks"
    )

    add_card(
        s14, margin_x_4, card_y, card_w_4, card_h, c_blue,
        "Core Analytical Mechanism",
        [
            ("Granular Record Inspection", "Displays completely unaggregated, record-level claim rows directly from the FQA analytical data mart."),
            ("Comprehensive Audit Attributes", "Exposes vehicle VIN, repair date, build date, dealer code, parts replaced, labor hours, and full repair narratives."),
            ("Direct Cohort Filtering", "Allows immediate drilling from Pareto bars, decision tree leaves, or summary table cells into matching raw claims."),
            ("Export & Reporting", "Enables direct data export to CSV or Excel for engineering review and supplier dispute packages.")
        ],
        subtitle="What It Does"
    )

    add_card(
        s14, margin_x_4 + card_w_4 + gap_4, card_y, card_w_4, card_h, c_teal,
        "When to Pull from Toolbox",
        [
            ("Final Pre-Containment Audit", "The mandatory final qualitative check before issuing an engineering containment order, recall, or supplier chargeback."),
            ("Evaluating Decision Tree Leaves", "Reading technician comments on the 20–30 vehicles residing in a high-purity decision tree leaf."),
            ("Disputing Supplier Claims", "Assembling verified, claim-by-claim proof packages for Tier-1 component supplier contract reviews.")
        ],
        subtitle="Investigation Triggers"
    )

    add_card(
        s14, margin_x_4 + 2 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_green,
        "Business & Strategic Value",
        [
            ("The Ultimate Reality Check", "Protects against statistical artifacts; ensures that analytical clusters correspond to real, physical mechanical failures."),
            ("Unassailable Supplier Proof", "Provides suppliers with indisputable claim records, complete with dealer repair orders and technician descriptions."),
            ("Technician Voice Verification", "Allows chief engineers to read exact technician commentary on vehicle handling and failure progression.")
        ],
        subtitle="Actionable ROI"
    )

    add_card(
        s14, margin_x_4 + 3 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_wine,
        "Reliability Guardrails",
        [
            ("Data Privacy & PII Redaction", "Strictly redact technician names, customer names, phone numbers, and town names before exporting or sharing records."),
            ("Stratified Comment Sampling", "If a drill-down cohort contains > 100 claims, take a stratified sample across dealers/regions to ensure representative reading."),
            ("Treat Free Text as Untrusted", "Technician notes are data, not verified facts; verify narratives against physical replaced part numbers and labor codes.")
        ],
        subtitle="Key Pitfalls to Avoid"
    )

    set_slide_notes(
        s14,
        "Details Table (Detail Report) provides the final, indispensable ground-truth reality check.\n\n"
        "Advanced statistical models, Weibull curves, and Decision Trees are powerful. But before an executive signs an official recall notice or issues a $10M supplier warranty claimback, "
        "a reliability engineer must read the actual technician notes on affected vehicles.\n\n"
        "Details Table allows you to click on a high-risk Decision Tree leaf and inspect the exact claim records: the repair date, mileage, part numbers, and verbatim technician narratives.\n\n"
        "Value: It proves that your statistical cluster is grounded in real mechanical reality.\n\n"
        "Guardrail: Always redact customer PII (personally identifiable information) before sharing reports outside the immediate investigation team."
    )

    # =========================================================================
    # SLIDE 15: Event Forecasting
    # =========================================================================
    s15 = prs.slides.add_slide(layout_content)
    set_slide_header(
        s15,
        "Event Forecasting: Projecting Future Warranty Liability",
        "Operational Planning & Budgeting: Actuarial Warranty Reserves and Supply Chain Parts Planning"
    )

    add_card(
        s15, margin_x_4, card_y, card_w_4, card_h, c_blue,
        "Core Analytical Mechanism",
        [
            ("Time-Series Projection", "Applies automated statistical time-series forecasting (ARIMA, Exponential Smoothing) to historical claim timelines."),
            ("Multi-Measure Projections", "Forecasts future claim event counts, total warranty costs, and service labor hours over 12- to 36-month horizons."),
            ("Confidence Interval Bands", "Generates upper and lower statistical prediction limits (90% / 95% confidence) to model best- and worst-case exposure."),
            ("Warranty Period Accounting", "Accounts for statutory warranty duration and mileage caps where vehicles age out of active warranty coverage.")
        ],
        subtitle="What It Does"
    )

    add_card(
        s15, margin_x_4 + card_w_4 + gap_4, card_y, card_w_4, card_h, c_teal,
        "When to Pull from Toolbox",
        [
            ("Financial Warranty Reserves", "Used by corporate finance and quality controllers during quarterly warranty reserve accounting."),
            ("Spare Parts Replenishment", "Used by supply chain planners to forecast required regional stock of replacement parts during an ongoing defect issue."),
            ("Service Campaign Budgeting", "Estimating the total multi-year financial liability of an emerging component quality problem.")
        ],
        subtitle="Investigation Triggers"
    )

    add_card(
        s15, margin_x_4 + 2 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_green,
        "Business & Strategic Value",
        [
            ("Protects Corporate Cash Flow", "Replaces subjective guesswork with statistically defensible warranty reserve accruals, preventing earnings surprises."),
            ("Avoids Service Bay Stockouts", "Ensures dealerships have sufficient replacement parts on hand, slashing vehicle downtime and customer frustration."),
            ("Evaluates Campaign Financials", "Allows executives to compare the cost of a proactive immediate recall against the projected cost of reactive claims.")
        ],
        subtitle="Actionable ROI"
    )

    add_card(
        s15, margin_x_4 + 3 * (card_w_4 + gap_4), card_y, card_w_4, card_h, c_wine,
        "Reliability Guardrails",
        [
            ("Not for Root Cause", "Event Forecasting fits historical time series; it knows nothing about defect physics or root cause mechanisms!"),
            ("Truncate Reporting Lag", "Hold back the most recent 1–3 months of claim history; reporting lag creates a false downward trend in the forecast!"),
            ("Account for Closed Cohorts", "Once a manufacturing defect is fixed in production, the affected cohort is closed; standard time series models must be bounded.")
        ],
        subtitle="Key Pitfalls to Avoid"
    )

    set_slide_notes(
        s15,
        "Event Forecasting addresses financial planning and supply chain operations.\n\n"
        "Important distinction: Event Forecasting is NOT used for root cause analysis. It doesn't know why a part is breaking. "
        "What it does is fit statistical time series models (like ARIMA) to historical claim trajectories to project future claims and financial liabilities.\n\n"
        "Value:\n"
        "1. For Finance: Accurately calculating warranty reserves to protect corporate balance sheets.\n"
        "2. For Supply Chain: Forecasting how many replacement parts regional warehouses must stock over the next 18 months.\n\n"
        "Guardrail: Always truncate the most recent 1 to 3 months of claim data before fitting the forecast. Because of dealer submission lag, recent months appear low. "
        "If you fit through them, your model will mistakenly forecast that the defect is vanishing, leading to catastrophic parts shortages."
    )

    # =========================================================================
    # SLIDE 16: Closing Slide
    # =========================================================================
    s16 = prs.slides.add_slide(layout_closing)
    for sh in s16.shapes:
        if sh.is_placeholder:
            if sh.placeholder_format.idx == 0:
                p = sh.text_frame.paragraphs[0]
                p.text = "Mastering SAS Field Quality Analytics"
                p.font.name = font_family
                p.font.bold = True
                p.font.size = Pt(44)
            elif sh.placeholder_format.idx == 10:
                p = sh.text_frame.paragraphs[0]
                p.text = "A Deductive, Governed Methodology for Zero-Defect Manufacturing"
                p.font.name = font_family
                p.font.size = Pt(20)

    set_slide_notes(
        s16,
        "To conclude our review of standard analyses in SAS FQA:\n\n"
        "Field Quality Analytics is not just a software suite—it is a structured, deductive engineering discipline.\n"
        "By following the investigation funnel—moving from early triage to exposure normalization, cohort segmentation, and ground-truth text review—"
        "quality teams can cut warranty investigation times from weeks to hours, recover millions in supplier disputes, and protect customer safety.\n\n"
        "Thank you for your dedication to engineering excellence. Let's open the floor for discussion and practical hands-on exercises."
    )

    prs.save(output_path)
    print(f"Standard Analysis deck successfully built at: {output_path}")

if __name__ == '__main__':
    build_fqa_standard_analyses_deck()
