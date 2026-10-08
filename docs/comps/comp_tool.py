import os
import re
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DSL_FILE = os.path.join(SCRIPT_DIR, "comps.dsl")
OUTPUT_FILE = os.path.join(SCRIPT_DIR, "comps.drawio.svg")

MIN_BOX_WIDTH = 180
ROW_HEIGHT = 24
FONT_SIZE = 14
FONT_FAMILY = "Consolas, 'Liberation Mono', Menlo, monospace"

def parse_dsl(filepath):
    if not os.path.exists(filepath):
        print(f"Error: {filepath} not found.")
        return []

    with open(filepath, 'r') as f:
        text = f.read()

    blocks = []
    current_block = None
    
    for line in text.strip().split('\n'):
        line = line.strip()
        if not line or line.startswith('//'): continue
        
        if line.startswith('#'):
            if current_block: blocks.append(current_block)
            current_block = {'name': line[1:].strip(), 'L': [], 'R': [], 'T': [], 'B': [], 'is_mid': True}
        elif line.startswith('@'):
            if current_block: blocks.append(current_block)
            current_block = {'name': line[1:].strip(), 'L': [], 'R': [], 'T': [], 'B': [], 'is_mid': False}
        elif line.startswith('L:'):
            current_block['L'].extend([p.strip() for p in line[2:].split(',') if p.strip()])
        elif line.startswith('R:'):
            current_block['R'].extend([p.strip() for p in line[2:].split(',') if p.strip()])
        elif line.startswith('T:'):
            current_block['T'].extend([p.strip() for p in line[2:].split(',') if p.strip()])
        elif line.startswith('B:'):
            current_block['B'].extend([p.strip() for p in line[2:].split(',') if p.strip()])
            
    if current_block: blocks.append(current_block)
    return blocks

def format_port(port_str):
    port_str = port_str.strip()
    if not port_str: return ""
    
    match = re.match(r'^(.*?)\[(.*?)\]$', port_str)
    if match:
        return f"{escape(match.group(1))}<sub style='font-size:10px;'>{escape(match.group(2))}</sub>"
        
    if ':' in port_str:
        name, width = port_str.split(':', 1)
        return f"{escape(name.strip())}<sub style='font-size:10px;'>{escape(width.strip())}</sub>"
        
    return escape(port_str)

def generate_components_file(blocks):
    mx_file = ET.Element('mxfile')
    diagram = ET.SubElement(mx_file, 'diagram', name="Components", id="comp_page")
    mx_graph_model = ET.SubElement(diagram, 'mxGraphModel', dx="1200", dy="1200", grid="1", gridSize="10", guides="1", tooltips="1", connect="1", arrows="1", fold="1", page="1", pageScale="1", pageWidth="827", pageHeight="1169", math="0", shadow="0")
    root = ET.SubElement(mx_graph_model, 'root')
    ET.SubElement(root, 'mxCell', id="0")
    ET.SubElement(root, 'mxCell', id="1", parent="0")

    x_offset = 40
    y_offset = 40

    for idx, block in enumerate(blocks):
        name = block['name']
        L_ports = block['L']
        R_ports = block['R']
        T_ports = block['T']
        B_ports = block['B']
        is_mid = block.get('is_mid', False)
        
        # Adjust header height based on style
        header_h = 40 if is_mid else 30
        max_lr_ports = max(len(L_ports), len(R_ports), 1) if (L_ports or R_ports) else 0
        
        # Calculate strict vertical stacking height
        height = header_h
        if T_ports: height += ROW_HEIGHT
        if max_lr_ports > 0: height += (max_lr_ports * ROW_HEIGHT)
        if B_ports: height += ROW_HEIGHT

        max_tb_ports = max(len(T_ports), len(B_ports))
        box_width = max(MIN_BOX_WIDTH, max_tb_ports * 60, len(name) * 11 if is_mid else 0)

        points = []
        
        # Top points: Aligned exactly to the HTML table cell centers (i + 0.5) / length
        for i in range(len(T_ports)):
            x_pos = (i + 0.5) / len(T_ports)
            points.append(f"[{x_pos:.4f}, 0]")
            
        # Bottom points
        for i in range(len(B_ports)):
            x_pos = (i + 0.5) / len(B_ports)
            points.append(f"[{x_pos:.4f}, 1]")
            
        # L/R points account for the space taken by T_ports and the header
        start_y = (ROW_HEIGHT if T_ports else 0) + header_h
        
        for i in range(len(L_ports)):
            y_pos_px = start_y + (i * ROW_HEIGHT) + (ROW_HEIGHT / 2.0)
            points.append(f"[0, {(y_pos_px / height):.4f}]")
            
        for i in range(len(R_ports)):
            y_pos_px = start_y + (i * ROW_HEIGHT) + (ROW_HEIGHT / 2.0)
            points.append(f"[1, {(y_pos_px / height):.4f}]")

        points_str = f"points=[{','.join(points)}];" if points else ""

        # Build clean, sequential HTML without absolute positioning
        html = f"<div style='width:100%;height:100%;margin:0;padding:0;box-sizing:border-box;font-family:{FONT_FAMILY};font-size:{FONT_SIZE}px;'>"
        
        if T_ports:
            html += f"<table style='width:100%;height:{ROW_HEIGHT}px;border-collapse:collapse;margin:0;padding:0;table-layout:fixed;'><tr>"
            for p in T_ports:
                html += f"<td style='text-align:center;vertical-align:middle;overflow:hidden;'>{format_port(p)}</td>"
            html += "</tr></table>"
        
        # Style branching
        if is_mid:
            # Watermark-style center header (Clean, bold, semi-transparent hardware aesthetic)
            html += f"<div style='width:100%;height:{header_h}px;line-height:{header_h}px;text-align:center;font-weight:bold;font-size:16px;opacity:0.6;'>{escape(name)}</div>"
        else:
            # Standard rigid top header
            html += f"<div style='box-sizing:border-box;width:100%;height:{header_h}px;line-height:{header_h}px;text-align:center;font-weight:bold;border-bottom:1px solid currentColor;border-top:1px solid currentColor;background-color:rgba(0,0,0,0.05);'>{escape(name)}</div>"
        
        if max_lr_ports > 0:
            html += "<table style='width:100%;border-collapse:collapse;margin:0;padding:0;table-layout:fixed;'>"
            for i in range(max_lr_ports):
                l_p = format_port(L_ports[i]) if i < len(L_ports) else ""
                r_p = format_port(R_ports[i]) if i < len(R_ports) else ""
                html += f"<tr style='height:{ROW_HEIGHT}px;'>"
                html += f"<td style='box-sizing:border-box;text-align:left;padding:0 8px;vertical-align:middle;overflow:hidden;'>{l_p}</td>"
                html += f"<td style='box-sizing:border-box;text-align:right;padding:0 8px;vertical-align:middle;overflow:hidden;'>{r_p}</td>"
                html += "</tr>"
            html += "</table>"
            
        if B_ports:
            html += f"<table style='width:100%;height:{ROW_HEIGHT}px;border-collapse:collapse;margin:0;padding:0;table-layout:fixed;'><tr>"
            for p in B_ports:
                html += f"<td style='text-align:center;vertical-align:middle;overflow:hidden;'>{format_port(p)}</td>"
            html += "</tr></table>"
            
        html += "</div>"

        style = f"html=1;whiteSpace=wrap;rounded=0;spacing=0;verticalAlign=top;overflow=fill;{points_str}"
        
        cell = ET.SubElement(root, 'mxCell', id=f"comp_{idx}", value=html, style=style, vertex="1", parent="1")
        ET.SubElement(cell, 'mxGeometry', x=str(x_offset), y=str(y_offset), width=str(box_width), height=str(height), **{"as": "geometry"})
        
        x_offset += box_width + 40
        if x_offset > 1000:
            x_offset = 40
            y_offset += height + 40

    tree = ET.ElementTree(mx_file)
    tree.write(OUTPUT_FILE, encoding='utf-8', xml_declaration=True)
    print(f"Done")

if __name__ == '__main__':
    blocks = parse_dsl(DSL_FILE)
    generate_components_file(blocks)