# ============================================================
# tool/diagram_helpers.py
# Shared matplotlib primitives for the UniVerse defense diagrams
# (activity, DFD-0, DFD-1, use-case). Imported by the per-diagram
# scripts in this folder.
# ============================================================
import math
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import (Rectangle, FancyBboxPatch, Ellipse, Polygon,
                                Circle)

INK = "#1a1a1a"
GREY = "#555555"

def canvas(xlim, ylim, figsize, dpi=140):
    fig, ax = plt.subplots(figsize=figsize, dpi=dpi)
    ax.set_xlim(*xlim)
    ax.set_ylim(*ylim)
    ax.set_aspect("equal")
    ax.axis("off")
    return fig, ax

def save(fig, path, dpi=140):
    fig.savefig(path, dpi=dpi, facecolor="white", bbox_inches="tight",
                pad_inches=0.25)
    print("wrote", path)

# ---- shapes -------------------------------------------------
def box(ax, x, y, w, h, text, fc="white", ec=INK, lw=1.6, fs=9,
        rounded=False, dashed=False, bold=False, zorder=4):
    ls = (0, (5, 3)) if dashed else "solid"
    if rounded:
        p = FancyBboxPatch((x - w / 2, y - h / 2), w, h,
                           boxstyle="round,pad=0.02,rounding_size=2.2",
                           fc=fc, ec=ec, lw=lw, ls=ls, zorder=zorder)
    else:
        p = Rectangle((x - w / 2, y - h / 2), w, h, fc=fc, ec=ec, lw=lw,
                      ls=ls, zorder=zorder)
    ax.add_patch(p)
    ax.text(x, y, text, ha="center", va="center", fontsize=fs,
            fontweight="bold" if bold else "normal", color="#111",
            zorder=zorder + 1)
    return (x, y)

def diamond(ax, x, y, text, w=16, h=11, fc="white", ec=INK, lw=1.6, fs=8,
            zorder=4):
    pts = [(x, y + h / 2), (x + w / 2, y), (x, y - h / 2), (x - w / 2, y)]
    ax.add_patch(Polygon(pts, closed=True, fc=fc, ec=ec, lw=lw, zorder=zorder))
    ax.text(x, y, text, ha="center", va="center", fontsize=fs, color="#111",
            zorder=zorder + 1)
    return (x, y)

def ellipse(ax, x, y, w, h, text, fc="white", ec=INK, lw=1.4, fs=9,
            bold=False, zorder=4):
    ax.add_patch(Ellipse((x, y), w, h, fc=fc, ec=ec, lw=lw, zorder=zorder))
    ax.text(x, y, text, ha="center", va="center", fontsize=fs,
            fontweight="bold" if bold else "normal", color="#111",
            zorder=zorder + 1)
    return (x, y)

def process(ax, x, y, r, num, name, fc="white", ec=INK, lw=1.6, fs=9,
            zorder=4):
    """DFD process: circle with a number above a chord and a name below."""
    ax.add_patch(Circle((x, y), r, fc=fc, ec=ec, lw=lw, zorder=zorder))
    chord = y + r * 0.30
    half = math.sqrt(max(r ** 2 - (chord - y) ** 2, 0))
    ax.plot([x - half, x + half], [chord, chord], color=ec, lw=lw * 0.7,
            zorder=zorder + 1)
    ax.text(x, y + r * 0.58, num, ha="center", va="center", fontsize=fs + 1,
            fontweight="bold", zorder=zorder + 1)
    ax.text(x, y - r * 0.22, name, ha="center", va="center", fontsize=fs - 1,
            zorder=zorder + 1)
    return (x, y)

def datastore(ax, x, y, w, h, did, name, fc="white", ec=INK, lw=1.4, fs=8,
              zorder=4):
    """Gane-Sarson data store: open-ended rectangle with an id cell."""
    left, right, top, bot = x - w / 2, x + w / 2, y + h / 2, y - h / 2
    ax.add_patch(Rectangle((left, bot), w, h, fc=fc, ec="none", zorder=zorder))
    ax.plot([left, right], [top, top], color=ec, lw=lw, zorder=zorder + 1)
    ax.plot([left, right], [bot, bot], color=ec, lw=lw, zorder=zorder + 1)
    ax.plot([left, left], [bot, top], color=ec, lw=lw, zorder=zorder + 1)
    idw = min(h, w * 0.30)
    ax.plot([left + idw, left + idw], [bot, top], color=ec, lw=lw,
            zorder=zorder + 1)
    ax.text(left + idw / 2, y, did, ha="center", va="center", fontsize=fs,
            fontweight="bold", zorder=zorder + 1)
    ax.text((left + idw + right) / 2, y, name, ha="center", va="center",
            fontsize=fs, zorder=zorder + 1)
    return (x, y)

def actor(ax, x, y, label, s=3.2, zorder=4):
    ax.add_patch(Circle((x, y + s * 1.7), s * 0.55, fc="white", ec="black",
                        lw=1.5, zorder=zorder))
    ax.plot([x, x], [y + s * 1.15, y - s * 0.3], color="black", lw=1.5,
            zorder=zorder)
    ax.plot([x - s * 0.9, x + s * 0.9], [y + s * 0.65, y + s * 0.65],
            color="black", lw=1.5, zorder=zorder)
    ax.plot([x, x - s * 0.7], [y - s * 0.3, y - s * 1.3], color="black",
            lw=1.5, zorder=zorder)
    ax.plot([x, x + s * 0.7], [y - s * 0.3, y - s * 1.3], color="black",
            lw=1.5, zorder=zorder)
    ax.text(x, y - s * 1.9, label, ha="center", va="top", fontsize=11,
            fontweight="bold", zorder=zorder)
    return (x, y)

def node(ax, x, y, r=1.7, end=False, zorder=5):
    ax.add_patch(Circle((x, y), r, fc="black", ec="black", zorder=zorder))
    if end:
        ax.add_patch(Circle((x, y), r * 1.9, fc="none", ec="black", lw=1.6,
                            zorder=zorder))
    return (x, y)

# ---- connectors ---------------------------------------------
def arrow(ax, p1, p2, text=None, fs=7.5, color=GREY, lw=1.2, rad=0.0,
          off=(0, 0), tpos=0.5, double=False, bbox=True, zorder=2,
          dashed=False):
    style = "<->" if double else "-|>"
    ax.annotate("", xy=p2, xytext=p1, zorder=zorder,
                arrowprops=dict(arrowstyle=style, color=color, lw=lw,
                                shrinkA=3, shrinkB=3, mutation_scale=12,
                                linestyle="--" if dashed else "-",
                                connectionstyle=f"arc3,rad={rad}"))
    if text:
        mx = p1[0] + (p2[0] - p1[0]) * tpos + off[0]
        my = p1[1] + (p2[1] - p1[1]) * tpos + off[1]
        bb = dict(boxstyle="round,pad=0.15", fc="white", ec="none",
                  alpha=0.9) if bbox else None
        ax.text(mx, my, text, ha="center", va="center", fontsize=fs,
                color="#111", zorder=zorder + 2, bbox=bb)

def line(ax, p1, p2, color=GREY, lw=1.2, zorder=2, dashed=False):
    ax.plot([p1[0], p2[0]], [p1[1], p2[1]], color=color, lw=lw,
            ls=(0, (5, 3)) if dashed else "solid", zorder=zorder)

def elbow(ax, p1, p2, text=None, fs=7.5, color=GREY, lw=1.2, hmid=None,
          arrow_end=True, zorder=2):
    """Orthogonal (right-angle) connector p1 -> p2 via a horizontal-ish route."""
    x1, y1 = p1
    x2, y2 = p2
    my = hmid if hmid is not None else (y1 + y2) / 2
    pts = [(x1, y1), (x1, my), (x2, my), (x2, y2)]
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    ax.plot(xs, ys, color=color, lw=lw, zorder=zorder, solid_capstyle="round")
    if arrow_end:
        ax.annotate("", xy=(x2, y2), xytext=(x2, my),
                    arrowprops=dict(arrowstyle="-|>", color=color, lw=lw,
                                    mutation_scale=12, shrinkA=0, shrinkB=2),
                    zorder=zorder)
    if text:
        ax.text((x1 + x2) / 2, my + 1.2, text, ha="center", va="bottom",
                fontsize=fs, color="#111", zorder=zorder + 1)
