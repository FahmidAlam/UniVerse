# -*- coding: utf-8 -*-
"""
Shared PDF builder for UniVerse defense-prep documents.
Every per-topic script imports `Doc` from here so styling stays consistent.

Usage:
    from defense_pdf_kit import Doc
    d = Doc("Routing & Navigation", "How every screen is reached")
    d.cover(["line 1", "line 2"])
    d.h1("1. Overview")
    d.p("Some **bold** text.")
    d.code("final x = 1;")
    d.save("docs/defense/Routing.pdf")
"""
from fpdf import FPDF

ORANGE = (255, 122, 0)
DARK = (26, 26, 28)
GREY = (110, 114, 120)
CODE_BG = (244, 244, 246)
SOFT = (248, 248, 250)
LINE = (220, 220, 224)
GREEN = (34, 153, 94)
BLUE = (45, 110, 210)


def _clean(s: str) -> str:
    repl = {
        "’": "'", "‘": "'", "“": '"', "”": '"',
        "–": "-", "—": "-", "→": "->", "←": "<-",
        "≤": "<=", "≥": ">=", "…": "...", " ": " ",
        "•": "-", "·": "-", "✅": "[x]", "⛔": "(x)",
        "✓": "v", "×": "x", "↑": "^", "↓": "v",
        "₹": "Rs", "‑": "-", "‚": ",",
    }
    for k, v in repl.items():
        s = s.replace(k, v)
    return s.encode("latin-1", "replace").decode("latin-1")


class _PDF(FPDF):
    doc_title = ""

    def header(self):
        if self.page_no() == 1:
            return
        self.set_font("Helvetica", "", 8)
        self.set_text_color(*GREY)
        self.cell(0, 6, _clean("UniVerse - " + self.doc_title), align="L")
        self.cell(0, 6, "Team Sherlocked", align="R", new_x="LMARGIN", new_y="NEXT")
        self.set_draw_color(*LINE)
        self.line(self.l_margin, self.get_y(), self.w - self.r_margin, self.get_y())
        self.ln(3)

    def footer(self):
        self.set_y(-12)
        self.set_font("Helvetica", "", 8)
        self.set_text_color(*GREY)
        self.cell(0, 6, f"Page {self.page_no()}", align="C")


class Doc:
    def __init__(self, title, subtitle=""):
        self.title = title
        self.subtitle = subtitle
        self.pdf = _PDF()
        self.pdf.doc_title = title
        self.pdf.set_auto_page_break(auto=True, margin=15)
        self.pdf.set_margins(18, 16, 18)
        self.epw = self.pdf.w - self.pdf.l_margin - self.pdf.r_margin

    # ---- low level ----
    def _need(self, h):
        if self.pdf.get_y() > self.pdf.h - h:
            self.pdf.add_page()

    # ---- cover ----
    def cover(self, meta_lines):
        p = self.pdf
        p.add_page()
        p.ln(26)
        p.set_font("Helvetica", "B", 28)
        p.set_text_color(*ORANGE)
        p.cell(0, 13, "UniVerse", align="C", new_x="LMARGIN", new_y="NEXT")
        p.set_font("Helvetica", "", 12)
        p.set_text_color(*DARK)
        p.cell(0, 7, "A Campus Companion", align="C", new_x="LMARGIN", new_y="NEXT")
        p.ln(8)
        p.set_font("Helvetica", "B", 18)
        p.set_text_color(*DARK)
        for ln in _clean(self.title).split("\n"):
            p.cell(0, 10, ln, align="C", new_x="LMARGIN", new_y="NEXT")
        if self.subtitle:
            p.set_font("Helvetica", "", 12)
            p.set_text_color(*GREY)
            p.multi_cell(self.epw, 6, _clean(self.subtitle), align="C")
        p.ln(10)
        p.set_draw_color(*ORANGE)
        p.set_line_width(0.6)
        cx = p.w / 2
        p.line(cx - 22, p.get_y(), cx + 22, p.get_y())
        p.set_line_width(0.2)
        p.ln(8)
        p.set_font("Helvetica", "", 10.5)
        p.set_text_color(*GREY)
        for ln in meta_lines:
            p.cell(0, 6.5, _clean(ln), align="C", new_x="LMARGIN", new_y="NEXT")
        p.add_page()

    # ---- section header (does NOT force a page) ----
    def h1(self, text, new_page=False):
        p = self.pdf
        if new_page:
            p.add_page()
        else:
            self._need(34)
            p.ln(3)
        p.set_font("Helvetica", "B", 14.5)
        p.set_text_color(*DARK)
        p.multi_cell(self.epw, 8, _clean(text))
        p.set_draw_color(*ORANGE)
        p.set_line_width(0.7)
        p.line(p.l_margin, p.get_y() + 0.5, p.l_margin + 32, p.get_y() + 0.5)
        p.set_line_width(0.2)
        p.ln(4)

    def h2(self, text):
        p = self.pdf
        self._need(20)
        p.ln(1.5)
        p.set_font("Helvetica", "B", 11.5)
        p.set_text_color(*ORANGE)
        p.multi_cell(self.epw, 6, _clean(text))
        p.ln(1)

    def p(self, text):
        p = self.pdf
        p.set_font("Helvetica", "", 10.3)
        p.set_text_color(40, 40, 42)
        p.multi_cell(self.epw, 5.3, _clean(text), markdown=True)
        p.ln(1)

    def bullet(self, text):
        p = self.pdf
        p.set_font("Helvetica", "", 10.3)
        p.set_text_color(40, 40, 42)
        x = p.get_x()
        p.set_text_color(*ORANGE)
        p.cell(5, 5.3, "-", new_x="RIGHT", new_y="TOP")
        p.set_text_color(40, 40, 42)
        p.multi_cell(self.epw - 5, 5.3, _clean(text), markdown=True)
        p.set_x(x)

    def code(self, text):
        p = self.pdf
        self._need(10 + 5 * (text.count("\n") + 1))
        p.ln(0.5)
        p.set_font("Courier", "", 8.7)
        p.set_fill_color(*CODE_BG)
        p.set_text_color(20, 20, 22)
        x0 = p.l_margin
        for ln in text.split("\n"):
            p.set_x(x0)
            p.cell(self.epw, 4.7, "  " + _clean(ln), fill=True, new_x="LMARGIN", new_y="NEXT")
        p.ln(1.5)

    def tip(self, text, label="Say this"):
        p = self.pdf
        self._need(14)
        y0 = p.get_y()
        p.set_fill_color(255, 247, 237)
        p.set_draw_color(*ORANGE)
        p.set_font("Helvetica", "BI", 9.8)
        # measure height by writing into a temp? simpler: draw text then bar
        p.set_xy(p.l_margin + 4, y0 + 1.5)
        p.set_text_color(*ORANGE)
        p.multi_cell(self.epw - 8, 5, _clean(label + ": " + text))
        y1 = p.get_y()
        # left accent bar
        p.set_fill_color(*ORANGE)
        p.rect(p.l_margin, y0, 1.4, y1 - y0 + 1.5, "F")
        p.ln(2)
        p.set_text_color(40, 40, 42)

    def kv(self, rows, c1="Item", c2="What it does", w1=46):
        p = self.pdf
        self._need(16)
        p.set_font("Helvetica", "B", 9.3)
        p.set_fill_color(*ORANGE)
        p.set_text_color(255, 255, 255)
        p.cell(w1, 6.6, "  " + _clean(c1), fill=True, new_x="RIGHT", new_y="TOP")
        p.cell(self.epw - w1, 6.6, "  " + _clean(c2), fill=True, new_x="LMARGIN", new_y="NEXT")
        fill = False
        for a, b in rows:
            # compute wrapped height of column 2
            p.set_font("Helvetica", "", 9.0)
            lines = p.multi_cell(self.epw - w1, 5.0, _clean(b), dry_run=True, output="LINES")
            h = max(6.2, 5.0 * len(lines) + 1.2)
            self._need(h + 2)
            y0 = p.get_y()
            x0 = p.l_margin
            p.set_fill_color(*(SOFT if fill else (255, 255, 255)))
            p.rect(x0, y0, self.epw, h, "F")
            p.set_xy(x0, y0 + 0.6)
            p.set_font("Courier", "B", 8.7)
            p.set_text_color(*ORANGE)
            p.multi_cell(w1, 5.0, "  " + _clean(a))
            p.set_xy(x0 + w1, y0 + 0.6)
            p.set_font("Helvetica", "", 9.0)
            p.set_text_color(40, 40, 42)
            p.multi_cell(self.epw - w1, 5.0, _clean(b))
            p.set_y(y0 + h)
            fill = not fill
        p.ln(2)

    def flow(self, steps, title=None):
        """Vertical numbered flow with arrows between steps."""
        p = self.pdf
        if title:
            self.h2(title)
        for i, step in enumerate(steps):
            self._need(14)
            y0 = p.get_y()
            # number bubble
            p.set_fill_color(*ORANGE)
            p.set_text_color(255, 255, 255)
            p.set_font("Helvetica", "B", 9)
            p.ellipse(p.l_margin, y0, 6, 6, "F")
            p.set_xy(p.l_margin, y0 + 0.6)
            p.cell(6, 5, str(i + 1), align="C")
            # text
            p.set_xy(p.l_margin + 9, y0)
            p.set_font("Helvetica", "", 9.8)
            p.set_text_color(40, 40, 42)
            p.multi_cell(self.epw - 9, 5.0, _clean(step), markdown=True)
            yend = p.get_y()
            if i < len(steps) - 1:
                p.set_draw_color(*ORANGE)
                p.set_line_width(0.4)
                p.line(p.l_margin + 3, y0 + 6, p.l_margin + 3, yend + 1.5)
                p.set_line_width(0.2)
                p.ln(1.5)
        p.ln(2)

    def divider(self):
        p = self.pdf
        p.ln(1)
        p.set_draw_color(*LINE)
        p.line(p.l_margin, p.get_y(), p.w - p.r_margin, p.get_y())
        p.ln(3)

    def save(self, path):
        self.pdf.output(path)
        return path
