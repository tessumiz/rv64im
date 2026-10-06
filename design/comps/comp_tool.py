# AI-generated

import os
import re
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DSL_FILE = os.path.join(SCRIPT_DIR, "comps.dsl")
OUTPUT_FILE = os.path.join(SCRIPT_DIR, "comps.drawio.svg")

BOX_WIDTH = 180
HEADER_HEIGHT = 30
ROW_HEIGHT = 24
FONT_SIZE = 14
FONT_FAMILY = "Consolas, 'Liberation Mono', Menlo, monospace"

def parse_dsl(filepath):
    with open(filepath, 'r') as f:
        text = f.read()

    blocks = []
    current_block = None
    
    for line in text.strip().split('\n'):
        line = line.strip()
        if not line or line.startswith('//'): continue
        
        if line.startswith('@'):
            if current_block: blocks.append(current_block)
            current_block = {'name': line[1:].strip(), 'in': [], 'out': []}
        elif line.startswith('in '):
            ports = [p.strip() for p in line[3:].split(',')]
            current_block['in'].extend(ports)
        elif line.startswith('out '):
            ports = [p.strip() for p in line[4:].split(',')]
            current_block['out'].extend(ports)
            
    if current_block: blocks.append(current_block)
    return blocks

def format_port(port_str):
    port_str = port_str.strip()
    
    match = re.match(r'^(.*?)\[(.*?)\]$', port_str)
    if match:
        return f"{match.group(1)}<sub style='font-size:10px;'>{match.group(2)}</sub>"
        
    if ':' in port_str:
        name, width = port_str.split(':', 1)
        return f"{name.strip()}<sub style='font-size:10px;'>{width.strip()}</sub>"
        
    return port_str

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
        in_ports = block['in']
        out_ports = block['out']
        
        max_ports = max(len(in_ports), len(out_ports), 1)
        height = HEADER_HEIGHT + (max_ports * ROW_HEIGHT)

        points = []
        for i in range(len(in_ports)):
            y_offset_px = HEADER_HEIGHT + (i * ROW_HEIGHT) + (ROW_HEIGHT / 2.0)
            points.append(f"[0, {(y_offset_px / height):.4f}]")
            
        for i in range(len(out_ports)):
            y_offset_px = HEADER_HEIGHT + (i * ROW_HEIGHT) + (ROW_HEIGHT / 2.0)
            points.append(f"[1, {(y_offset_px / height):.4f}]")

        points_str = f"points=[{','.join(points)}];" if points else ""

        html = f"<div style='width:100%;height:100%;margin:0;padding:0;box-sizing:border-box;font-family:{FONT_FAMILY};font-size:{FONT_SIZE}px;'>"
        html += f"<div style='box-sizing:border-box;width:100%;height:{HEADER_HEIGHT}px;line-height:{HEADER_HEIGHT}px;text-align:center;font-weight:bold;border-bottom:1px solid currentColor;'>{escape(name)}</div>"
        
        html += "<table style='width:100%;border-collapse:collapse;margin:0;padding:0;table-layout:fixed;'>"
        for i in range(max_ports):
            in_p = format_port(in_ports[i]) if i < len(in_ports) else ""
            out_p = format_port(out_ports[i]) if i < len(out_ports) else ""
            html += f"<tr style='height:{ROW_HEIGHT}px;'>"
            html += f"<td style='box-sizing:border-box;text-align:left;padding:0 8px;vertical-align:middle;overflow:hidden;'>{in_p}</td>"
            html += f"<td style='box-sizing:border-box;text-align:right;padding:0 8px;vertical-align:middle;overflow:hidden;'>{out_p}</td>"
            html += "</tr>"
        html += "</table></div>"

        style = f"html=1;whiteSpace=wrap;rounded=0;spacing=0;verticalAlign=top;overflow=fill;{points_str}portConstraint=eastwest;"
        
        cell = ET.SubElement(root, 'mxCell', id=f"comp_{idx}", value=html, style=style, vertex="1", parent="1")
        ET.SubElement(cell, 'mxGeometry', x=str(x_offset), y=str(y_offset), width=str(BOX_WIDTH), height=str(height), **{"as": "geometry"})
        
        x_offset += BOX_WIDTH + 40

    tree = ET.ElementTree(mx_file)
    tree.write(OUTPUT_FILE, encoding='utf-8', xml_declaration=True)
    print(f"Generated components template file: {OUTPUT_FILE}")

if __name__ == '__main__':
    blocks = parse_dsl(DSL_FILE)
    generate_components_file(blocks)