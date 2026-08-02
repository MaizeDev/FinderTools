from pathlib import Path

from docx import Document
from openpyxl import Workbook
from pptx import Presentation


project_root = Path(__file__).resolve().parent.parent
extension_root = project_root / "FinderToolsExtension"
extension_root.mkdir(parents=True, exist_ok=True)

Document().save(extension_root / "blank.docx")

workbook = Workbook()
workbook.save(extension_root / "blank.xlsx")

Presentation().save(extension_root / "blank.pptx")

print("Created blank.docx, blank.xlsx, and blank.pptx")
