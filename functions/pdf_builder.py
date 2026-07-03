"""
Builds a PDF expense report from report header + line item data.
Returns raw PDF bytes — caller decides where to store them.
"""

from io import BytesIO
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle


def build_expense_report_pdf(report: dict, line_items: list[dict]) -> bytes:
    """
    report: { id, user_id, title, period, submitted_at, status }
    line_items: [ { description, category, amount, expense_date }, ... ]
    """
    buffer = BytesIO()
    doc = SimpleDocTemplate(
        buffer, pagesize=A4,
        topMargin=20 * mm, bottomMargin=20 * mm,
        leftMargin=20 * mm, rightMargin=20 * mm,
    )

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "ReportTitle", parent=styles["Heading1"], fontSize=18, spaceAfter=4
    )
    meta_style = ParagraphStyle(
        "Meta", parent=styles["Normal"], textColor=colors.grey, fontSize=10
    )

    elements = []

    elements.append(Paragraph(report["title"], title_style))
    elements.append(Paragraph(
        f"Period: {report['period']} &nbsp;&nbsp;|&nbsp;&nbsp; "
        f"Status: {report['status']} &nbsp;&nbsp;|&nbsp;&nbsp; "
        f"Submitted: {report['submitted_at']}",
        meta_style
    ))
    elements.append(Spacer(1, 12 * mm))

    # Line items table
    table_data = [["Date", "Description", "Category", "Amount (USD)"]]
    total = 0.0
    for item in line_items:
        table_data.append([
            str(item["expense_date"]),
            item["description"],
            item["category"],
            f"{item['amount']:.2f}",
        ])
        total += float(item["amount"])

    table_data.append(["", "", "Total", f"{total:.2f}"])

    table = Table(table_data, colWidths=[28 * mm, 70 * mm, 35 * mm, 35 * mm])
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#2C2C2A")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTSIZE", (0, 0), (-1, -1), 10),
        ("ALIGN", (3, 0), (3, -1), "RIGHT"),
        ("GRID", (0, 0), (-1, -2), 0.5, colors.HexColor("#D3D1C7")),
        ("LINEABOVE", (0, -1), (-1, -1), 1, colors.black),
        ("FONTNAME", (0, -1), (-1, -1), "Helvetica-Bold"),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))

    elements.append(table)
    doc.build(elements)

    return buffer.getvalue()
