#!/usr/bin/env python3
"""Generate a multi-page draw.io file (and an SVG preview) for the platform."""
import html, xml.etree.ElementTree as ET

# ---------------------------------------------------------------- palette
P = {
    "region":  ("#F7F9FC", "#5A6B7B"),
    "vpc":     ("#F2FBF3", "#248814"),
    "insp":    ("#FDF2F2", "#C7131F"),
    "ingress": ("#FFF6EC", "#ED7100"),
    "spoke":   ("#F1F7FE", "#147EBA"),
    "tgw":     ("#F5F0FF", "#8C4FFF"),
    "onprem":  ("#F4F4F4", "#4A4A4A"),
    "net":     ("#EEF6FF", "#1F6FEB"),
    "plain":   ("#FFFFFF", "#8C8C8C"),
    "note":    ("#FFFDF0", "#B8A02A"),
}
FONT = "Helvetica"

class Scene:
    def __init__(self, name, w, h):
        self.name, self.w, self.h = name, w, h
        self.nodes, self.edges = [], []
    def box(self, i, label, x, y, w, h, kind="plain", *, dashed=False, fs=12,
            bold=False, align="center", valign="middle", rounded=True):
        self.nodes.append(dict(id=i, label=label, x=x, y=y, w=w, h=h, kind=kind,
                               dashed=dashed, fs=fs, bold=bold, align=align,
                               valign=valign, rounded=rounded))
        return i
    def edge(self, i, s, t, label="", *, dashed=False, color="#3A3A3A", fs=10,
             exit_=None, entry=None, width=1):
        self.edges.append(dict(id=i, s=s, t=t, label=label, dashed=dashed,
                               color=color, fs=fs, exit=exit_, entry=entry, width=width))

def style(n):
    fill, stroke = P[n["kind"]]
    s = [f"rounded={1 if n['rounded'] else 0}", "whiteSpace=wrap", "html=1",
         f"fillColor={fill}", f"strokeColor={stroke}", f"fontSize={n['fs']}",
         f"fontFamily={FONT}", f"align={n['align']}", f"verticalAlign={n['valign']}",
         "arcSize=8", "spacingLeft=6", "spacingRight=6"]
    if n["dashed"]: s.append("dashed=1;dashPattern=6 4")
    if n["bold"]:   s.append("fontStyle=1")
    if n["align"] != "center": s.append("spacingTop=2")
    return ";".join(s) + ";"

def edge_style(e):
    s = ["edgeStyle=orthogonalEdgeStyle", "rounded=1", "html=1", "jettySize=auto",
         "orthogonalLoop=1", f"strokeColor={e['color']}", f"fontSize={e['fs']}",
         f"fontFamily={FONT}", f"strokeWidth={e['width']}", "labelBackgroundColor=#FFFFFF"]
    if e["dashed"]: s.append("dashed=1;dashPattern=6 4")
    if e["exit"]:  s.append(f"exitX={e['exit'][0]};exitY={e['exit'][1]};exitDx=0;exitDy=0")
    if e["entry"]: s.append(f"entryX={e['entry'][0]};entryY={e['entry'][1]};entryDx=0;entryDy=0")
    return ";".join(s) + ";"

def esc(t):
    """Escape for an XML attribute, preserving line breaks as character refs."""
    return (t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
             .replace('"', "&quot;").replace("\n", "&#10;"))

def to_drawio(scenes, path):
    out = ['<?xml version="1.0" encoding="utf-8"?>',
           '<mxfile host="app.diagrams.net" type="device" agent="terraform-scaffold">']
    for sc in scenes:
        out.append(f'  <diagram name="{esc(sc.name)}">')
        out.append(f'    <mxGraphModel dx="1400" dy="900" grid="1" gridSize="10" '
                   f'guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" '
                   f'pageScale="1" pageWidth="{sc.w}" pageHeight="{sc.h}" math="0" shadow="0">')
        out.append('      <root>')
        out.append('        <mxCell id="0" />')
        out.append('        <mxCell id="1" parent="0" />')
        for n in sc.nodes:
            out.append(f'        <mxCell id="{esc(n["id"])}" value="{esc(n["label"])}" '
                       f'style="{esc(style(n))}" vertex="1" parent="1">')
            out.append(f'          <mxGeometry x="{n["x"]}" y="{n["y"]}" '
                       f'width="{n["w"]}" height="{n["h"]}" as="geometry" />')
            out.append('        </mxCell>')
        for e in sc.edges:
            out.append(f'        <mxCell id="{esc(e["id"])}" value="{esc(e["label"])}" '
                       f'style="{esc(edge_style(e))}" edge="1" parent="1" '
                       f'source="{esc(e["s"])}" target="{esc(e["t"])}">')
            out.append('          <mxGeometry relative="1" as="geometry" />')
            out.append('        </mxCell>')
        out.append('      </root>')
        out.append('    </mxGraphModel>')
        out.append('  </diagram>')
    out.append('</mxfile>')
    open(path, "w").write("\n".join(out) + "\n")

# ------------------------------------------------------------------ SVG
def to_svg(scenes, path):
    pad, gap = 30, 60
    W = max(s.w for s in scenes) + pad * 2
    H = sum(s.h + gap + 40 for s in scenes) + pad
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
           f'viewBox="0 0 {W} {H}" font-family="{FONT},Arial,sans-serif">',
           f'<rect width="{W}" height="{H}" fill="#FFFFFF"/>',
           '<defs><marker id="a" markerWidth="9" markerHeight="9" refX="8" refY="3" '
           'orient="auto"><path d="M0,0 L0,6 L8,3 z" fill="#3A3A3A"/></marker></defs>']
    oy = pad
    for sc in scenes:
        idx = {n["id"]: n for n in sc.nodes}
        out.append(f'<text x="{pad}" y="{oy+18}" font-size="17" font-weight="700" '
                   f'fill="#1A1A1A">{html.escape(sc.name)}</text>')
        oy += 40
        for n in sc.nodes:
            fill, stroke = P[n["kind"]]
            dash = ' stroke-dasharray="6,4"' if n["dashed"] else ''
            out.append(f'<rect x="{n["x"]+pad}" y="{n["y"]+oy}" width="{n["w"]}" '
                       f'height="{n["h"]}" rx="6" fill="{fill}" stroke="{stroke}"{dash}/>')
            lines = n["label"].split("\n")
            fs = n["fs"]; lh = fs + 3
            if n["valign"] == "top":
                ty = n["y"] + oy + fs + 6
            else:
                ty = n["y"] + oy + n["h"]/2 - (len(lines)-1)*lh/2 + fs/3
            tx = n["x"]+pad+8 if n["align"] == "left" else n["x"]+pad+n["w"]/2
            anch = "start" if n["align"] == "left" else "middle"
            for i, ln in enumerate(lines):
                fw = "700" if (n["bold"] and i == 0) else "400"
                out.append(f'<text x="{tx}" y="{ty+i*lh}" font-size="{fs}" '
                           f'font-weight="{fw}" fill="#1A1A1A" text-anchor="{anch}">'
                           f'{html.escape(ln)}</text>')
        for e in sc.edges:
            a, b = idx.get(e["s"]), idx.get(e["t"])
            if not a or not b: continue
            ax0, ay0 = a["x"] + pad, a["y"] + oy
            bx0, by0 = b["x"] + pad, b["y"] + oy
            acx, acy = ax0 + a["w"]/2, ay0 + a["h"]/2
            bcx, bcy = bx0 + b["w"]/2, by0 + b["h"]/2
            dx, dy = bcx - acx, bcy - acy
            # Leave from the box boundary, not its centre, so the line is not
            # hidden under the shape it starts in.
            if abs(dy) >= abs(dx):
                sx, ex = acx, bcx
                sy = ay0 + a["h"] if dy > 0 else ay0
                ey = by0 if dy > 0 else by0 + b["h"]
                mid = (sy + ey) / 2
                d = f"M{sx},{sy} L{sx},{mid} L{ex},{mid} L{ex},{ey}"
                lx, ly = (sx + ex) / 2, mid - 5
            else:
                sy, ey = acy, bcy
                sx = ax0 + a["w"] if dx > 0 else ax0
                ex = bx0 if dx > 0 else bx0 + b["w"]
                mid = (sx + ex) / 2
                d = f"M{sx},{sy} L{mid},{sy} L{mid},{ey} L{ex},{ey}"
                lx, ly = mid, (sy + ey) / 2 - 5
            dash = ' stroke-dasharray="6,4"' if e["dashed"] else ''
            out.append(f'<path d="{d}" fill="none" stroke="{e["color"]}" '
                       f'stroke-width="{e["width"]}"{dash} marker-end="url(#a)" opacity="0.85"/>')
            if e["label"]:
                for i, ln in enumerate(e["label"].split("\n")):
                    t = html.escape(ln)
                    yy = ly + i * 11
                    out.append(f'<text x="{lx}" y="{yy}" font-size="10" fill="none" '
                               f'stroke="#FFFFFF" stroke-width="4" stroke-linejoin="round" '
                               f'text-anchor="middle">{t}</text>')
                    out.append(f'<text x="{lx}" y="{yy}" font-size="10" fill="#2A2A2A" '
                               f'text-anchor="middle">{t}</text>')
        oy += sc.h + gap
    out.append("</svg>")
    open(path, "w").write("\n".join(out))

# ============================================================ page 1
def page_overview():
    sc = Scene("1 · Two-Region Overview", 1740, 900)
    sc.box("onprem", "On-Premises\nCH1 / NY4 customer routers\nBGP over transit VIF",
           60, 40, 300, 100, "onprem", bold=True)
    sc.box("dxgw", "Direct Connect Gateway\nallowed_prefixes: static, summarized",
           470, 50, 300, 80, "net", bold=True)

    for tag, x0, asn, sup, role in (
        ("a", 60,  "64512", "10.100.0.0/16", "inspects cross-region"),
        ("b", 900, "64513", "10.200.0.0/16", "bypasses to peering"),
    ):
        reg = "us-east-1" if tag == "a" else "us-east-2"
        sc.box(f"reg{tag}", f"{reg}   {sup}", x0, 230, 780, 520, "region",
               dashed=True, bold=True, fs=14, align="left", valign="top")
        sc.box(f"net{tag}", "Internet", x0 + 250, 165, 280, 44, "net", bold=True, fs=11)
        sc.box(f"ing{tag}", "Ingress VPC  /22\nInternet-facing NLB\nGWLB endpoints + IGW ingress routing",
               x0 + 30, 290, 340, 100, "ingress", bold=True, fs=11)
        sc.box(f"insp{tag}", "Inspection VPC  /22\nGWLB + VM-Series ASG per AZ\nGWLB endpoints + NAT egress",
               x0 + 410, 290, 340, 100, "insp", bold=True, fs=11)
        sc.box(f"tgw{tag}", f"Transit Gateway   ASN {asn}\nspoke · inspection · ingress · peering · hybrid\n({role})",
               x0 + 210, 460, 360, 90, "tgw", bold=True, fs=11)
        sc.box(f"spk{tag}", "Spoke VPCs   /22 each   ·   default route 0.0.0.0/0 to the TGW",
               x0 + 30, 620, 720, 100, "region", dashed=True, fs=11, align="left", valign="top")
        for i in range(6):
            sc.box(f"s{tag}{i}", f"spoke-0{i+1}", x0 + 36 + i * 120, 660, 108, 46, "spoke", fs=10)

    sc.edge("e1", "onprem", "dxgw", "transit VIF", width=2)
    sc.edge("e2", "dxgw", "tgwa", "association\nhybrid RT", width=2)
    sc.edge("e3", "dxgw", "tgwb", "association\nhybrid RT", width=2)
    sc.edge("e4", "tgwa", "tgwb", "TGW peering  ·  inspected once, in us-east-1",
            color="#8C4FFF", width=2)
    for t in ("a", "b"):
        sc.edge(f"e5{t}", f"tgw{t}", f"insp{t}", "0.0.0.0/0", color="#C7131F", width=2)
        sc.edge(f"e6{t}", f"tgw{t}", f"ing{t}", "", color="#ED7100")
        sc.edge(f"e7{t}", f"spk{t}", f"tgw{t}", "", color="#147EBA")
        sc.edge(f"e8{t}", f"net{t}", f"ing{t}", "ingress", color="#ED7100", dashed=True)
        sc.edge(f"e9{t}", f"insp{t}", f"net{t}", "egress via NAT", color="#248814", dashed=True)

    sc.box("n1", "Every spoke default route points at the firewall. Prefixes that must NOT be "
                 "propagated into the spoke table:\non-premises (hybrid domain) and the remote "
                 "region (peering domain) — either would be more specific than 0.0.0.0/0 and would "
                 "route around inspection.",
           60, 780, 1620, 70, "note", fs=11, align="left")
    return sc

# ============================================================ page 2
def page_paths():
    sc = Scene("2 · Region Detail and Traffic Paths", 1560, 1000)
    sc.box("inet", "Internet", 660, 30, 240, 54, "net", bold=True)

    sc.box("ingvpc", "Ingress landing zone VPC   10.100.4.0/22", 60, 120, 600, 300,
           "ingress", dashed=True, bold=True, fs=12, align="left", valign="top")
    sc.box("igw", "IGW", 100, 170, 120, 50, "net")
    sc.box("edgert", "IGW ingress route table\nNLB subnet prefix → GWLBE", 250, 165, 260, 60, "note", fs=10)
    sc.box("gwlbe_i", "GWLB endpoint\n(per AZ)", 100, 265, 180, 60, "insp", fs=10)
    sc.box("nlb", "Network Load Balancer\ntarget_type = ip, AZ = all", 330, 265, 250, 60, "ingress", fs=10)
    sc.box("ingtgw", "TGW attachment subnets", 100, 350, 480, 44, "plain", fs=10)

    sc.box("ivpc", "Inspection VPC   10.100.0.0/22", 900, 120, 600, 470,
           "insp", dashed=True, bold=True, fs=12, align="left", valign="top")
    sc.box("itgw", "TGW attachment subnets\nRT: 0.0.0.0/0 → AZ-local GWLBE", 940, 170, 520, 56, "plain", fs=10)
    sc.box("gwlbe_e", "GWLB endpoints  (one per AZ)", 940, 250, 520, 44, "insp", fs=10)
    sc.box("gwlb", "Gateway Load Balancer\nGENEVE 6081 · cross-zone off", 940, 320, 250, 60, "insp", fs=10)
    sc.box("vms", "VM-Series ASG per AZ\nmgmt-interface-swap: eth0 = data", 1210, 320, 250, 60, "insp", fs=10)
    sc.box("nat", "NAT gateway per AZ", 940, 415, 250, 44, "net", fs=10)
    sc.box("iigw", "IGW", 1210, 415, 250, 44, "net", fs=10)
    sc.box("gwrt", "GWLBE RT: supernets → TGW, 0.0.0.0/0 → NAT   ·   Public RT: supernets → GWLBE",
           940, 490, 520, 44, "note", fs=10)

    sc.box("tgw", "Transit Gateway\nappliance mode on the inspection attachment",
           580, 640, 400, 80, "tgw", bold=True, fs=11)
    sc.box("spoke", "Spoke VPC   workload subnets\nRT: 0.0.0.0/0 → TGW", 180, 790, 320, 70, "spoke", fs=11)
    sc.box("dx", "Direct Connect gateway\nhybrid RT: supernet → inspection", 1060, 790, 340, 70, "net", fs=11)

    sc.edge("p1", "inet", "igw", "1  inbound", color="#ED7100", width=2)
    sc.edge("p2", "igw", "gwlbe_i", "2  edge route", color="#ED7100", width=2)
    sc.edge("p3", "gwlbe_i", "gwlb", "3  GENEVE", color="#C7131F", width=2, dashed=True)
    sc.edge("p4", "gwlb", "vms", "", color="#C7131F")
    sc.edge("p5", "gwlbe_i", "nlb", "4  post-inspection", color="#ED7100", width=2)
    sc.edge("p6", "nlb", "ingtgw", "5  to spoke target", color="#ED7100")
    sc.edge("p7", "ingtgw", "tgw", "", color="#ED7100")
    sc.edge("p8", "spoke", "tgw", "east-west + egress\n0.0.0.0/0", color="#147EBA", width=2)
    sc.edge("p9", "tgw", "itgw", "", color="#147EBA", width=2)
    sc.edge("p10", "itgw", "gwlbe_e", "", color="#C7131F", width=2)
    sc.edge("p11", "gwlbe_e", "gwlb", "", color="#C7131F")
    sc.edge("p12", "gwlbe_e", "nat", "egress", color="#248814")
    sc.edge("p13", "nat", "iigw", "", color="#248814")
    sc.edge("p14", "dx", "tgw", "on-prem → inspection", color="#1F6FEB", width=2)
    return sc

# ============================================================ page 3
def page_routing():
    sc = Scene("3 · Transit Gateway Route Domains", 1500, 780)
    rts = [
        ("spoke", "spoke", "spoke-01 … spoke-06",
         "STATIC  0.0.0.0/0 → inspection attachment\nPROP    ingress VPC prefix\n\n"
         "Nothing else. Any propagated prefix here\nis more specific than the default and\nskips the firewall."),
        ("insp", "inspection", "inspection VPC",
         "PROP    all spoke prefixes\nPROP    ingress VPC prefix\nPROP    on-premises (via DXGW)\n"
         "STATIC  remote supernet → peering\n            (inspecting region only)"),
        ("ing", "ingress", "ingress VPC",
         "PROP    all spoke prefixes\nSTATIC  0.0.0.0/0 → inspection\n\n"
         "Lets landing-zone workloads egress\nthrough the same firewall as a spoke."),
        ("peer", "peering", "TGW peering attachment",
         "Inspecting region:\n  STATIC local supernet → inspection\n\n"
         "Bypass region:\n  PROP  local prefixes"),
        ("hyb", "hybrid", "Direct Connect gateway",
         "STATIC  local supernet → inspection\n\nOn-prem prefixes are propagated OUT of\n"
         "here into the inspection table, never\ninto the spoke table."),
    ]
    x = 40
    for i, (k, title, attach, body) in enumerate(rts):
        kind = {"spoke": "spoke", "insp": "insp", "ing": "ingress",
                "peer": "tgw", "hyb": "net"}[k]
        sc.box(f"a_{k}", attach, x, 60, 260, 46, kind, fs=11, bold=True)
        sc.box(f"rt_{k}", f"{title} route table", x, 170, 260, 40, "tgw", fs=12, bold=True)
        sc.box(f"b_{k}", body, x, 220, 260, 220, "plain", fs=10, align="left", valign="top")
        sc.edge(f"e_{k}", f"a_{k}", f"rt_{k}", "associated", fs=9)
        x += 290

    sc.box("legend",
           "PROP = aws_ec2_transit_gateway_route_table_propagation      "
           "STATIC = aws_ec2_transit_gateway_route\n\n"
           "default_route_table_association and default_route_table_propagation are both disabled on the TGW. "
           "That switches off the implicit\nbehaviour only — every attachment above is placed in its domain "
           "explicitly, which is what makes the routing auditable.",
           40, 480, 1420, 100, "note", fs=11, align="left")
    sc.box("warn",
           "The single rule that holds the whole design together: the spoke table contains exactly one route out, "
           "and it points at the firewall.\nEvery other domain exists so that some prefix — ingress, remote region, "
           "on-premises — can be reachable without being propagated into it.",
           40, 610, 1420, 80, "insp", fs=11, align="left")
    return sc

if __name__ == "__main__":
    import sys
    scenes = [page_overview(), page_paths(), page_routing()]
    to_drawio(scenes, sys.argv[1])
    to_svg(scenes, sys.argv[2])
    print(f"pages: {len(scenes)}")
    for s in scenes:
        print(f"  {s.name}: {len(s.nodes)} nodes, {len(s.edges)} edges")
