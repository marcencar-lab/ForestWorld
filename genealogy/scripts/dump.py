import sys, openpyxl
wb = openpyxl.load_workbook(sys.argv[1], data_only=True)
for ws in wb.worksheets:
    print(f"\n===== SHEET: {ws.title!r}  dims={ws.dimensions} max_row={ws.max_row} max_col={ws.max_column} merged={len(ws.merged_cells.ranges)}")
    n=0
    for row in ws.iter_rows():
        cells=[(c.coordinate, c.value) for c in row if c.value is not None and str(c.value).strip()!=""]
        if cells:
            n+=1
            print(" | ".join(f"{k}={v!r}" for k,v in cells))
    print(f"--- {n} non-empty rows")
