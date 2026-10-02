from PIL import Image, ImageDraw, ImageFont
F="/usr/share/fonts/truetype/dejavu/"
def f(n,s): return ImageFont.truetype(F+n,s)
BG=(15,18,26); FG=(236,239,244); MUTED=(150,160,178); PANEL=(26,31,43); LINE=(55,63,80)
C={"diff":(255,159,67),"rules":(171,128,255),"interface":(64,200,200),"callSite":(88,214,141),"file":(94,150,255),"tool":(120,128,145)}
RED=(255,99,99); GREEN=(88,214,141)
P="2026-10-02-reviewer-context-packet-"
def rr(d,box,fill,outline=None,r=16,w=2): d.rounded_rectangle(box,r,fill=fill,outline=outline,width=w)

# ---------- header 1400x700
im=Image.new("RGB",(1400,700),BG); d=ImageDraw.Draw(im)
d.text((80,64),"CONTEXT ENGINEERING · iOS MONOREPO · REVIEWER AGENTS",font=f("DejaVuSans-Bold.ttf",22),fill=MUTED)
d.text((80,108),"Your review agent doesn't",font=f("DejaVuSans-Bold.ttf",64),fill=FG)
d.text((80,186),"need more code.",font=f("DejaVuSans-Bold.ttf",64),fill=FG)
d.text((80,264),"It needs the callers.",font=f("DejaVuSans-Bold.ttf",64),fill=C["callSite"])
def bar(y,label,parts,total,scale,note,ok):
    d.text((80,y),label,font=f("DejaVuSans-Bold.ttf",24),fill=FG)
    x=80; yy=y+40
    rr(d,(80,yy,80+int(total*scale),yy+34),(33,39,54),None,6)
    for k,v in parts:
        w=int(v*scale)
        if w>0: d.rectangle((x,yy,x+w,yy+34),fill=C[k]); x+=w
    d.text((80+int(total*scale)+20 if note else x+20,yy+3),note,font=f("DejaVuSans-Bold.ttf",26),fill=GREEN if ok else RED)
s=1000/80000
bar(380,"Whole modules, 200k budget · 77,460 tokens",[("diff",2000),("rules",9000),("tool",23360),("file",43100)],77460,s,"",False)
d.text((80+int(77460*s)+20,423),"2 / 5",font=f("DejaVuSans-Bold.ttf",26),fill=RED)
bar(500,"Review contract, 32k budget · 10,870 tokens",[("diff",2000),("rules",1700),("interface",390),("callSite",640),("tool",6140)],10870,s,"",True)
d.text((80+int(10870*s)+20,543),"5 / 5",font=f("DejaVuSans-Bold.ttf",26),fill=GREEN)
d.text((80,630),"Seeded findings whose evidence is in the window · constructed 8-module repo",font=f("DejaVuSans.ttf",20),fill=MUTED)
im.save(P+"header.png")

# ---------- diagram 1400x940: what fills the window
im=Image.new("RGB",(1400,940),BG); d=ImageDraw.Draw(im)
d.text((60,40),"What fills a reviewer agent's window",font=f("DejaVuSans-Bold.ttf",40),fill=FG)
d.text((60,96),"Same diff, same repo, four packets. Grey track = budget. Right: seeded findings whose evidence made it in.",font=f("DejaVuSans.ttf",22),fill=MUTED)
rows=[
 ("Whole modules","32,000 budget",[("diff",2000),("rules",9000),("tool",20700)],31700,"1 / 5","0 tokens of source: tools and one big CLAUDE.md filled it"),
 ("Diff only","32,000 budget",[("diff",2000),("rules",9000),("tool",20700)],31700,"1 / 5","same picture without the ambition"),
 ("Whole modules","200,000 budget",[("diff",2000),("rules",9000),("tool",23360),("file",43100)],77460,"2 / 5","every file in Networking + Checkout; no caller outside them"),
 ("Review contract","32,000 budget",[("diff",2000),("rules",1700),("interface",390),("callSite",640),("tool",6140)],10870,"5 / 5","scoped rules, 3 interface stubs, 4 caller excerpts, 12 tools"),
]
s=1000/80000; y=160
for name,bud,parts,total,cov,note in rows:
    rr(d,(60,y,1340,y+150),PANEL,LINE,14)
    d.text((90,y+18),name,font=f("DejaVuSans-Bold.ttf",26),fill=FG)
    d.text((90+d.textlength(name,font=f("DejaVuSans-Bold.ttf",26))+16,y+22),bud,font=f("DejaVuSans.ttf",20),fill=MUTED)
    ok=cov.startswith("5")
    w=d.textlength(cov,font=f("DejaVuSans-Bold.ttf",34)); d.text((1310-w,y+14),cov,font=f("DejaVuSans-Bold.ttf",34),fill=GREEN if ok else RED)
    x=90; yy=y+66
    bnum=int(bud.split()[0].replace(",",""))
    track=min(int(bnum*s),1000)
    rr(d,(90,yy,90+track,yy+30),(33,39,54),None,6)
    if bnum*s<=1000:
        d.line((90+track,yy-8,90+track,yy+38),fill=FG,width=3)
        d.text((90+track+8,yy-26),"budget",font=f("DejaVuSans.ttf",16),fill=MUTED)
    else:
        d.text((90+1000-150,yy-26),"budget 200,000 →",font=f("DejaVuSans.ttf",16),fill=MUTED)
    for k,v in parts:
        ww=int(v*s)
        if ww>0: d.rectangle((x,yy,x+ww,yy+30),fill=C[k]); x+=ww
    lx=max(x,90+track)+16 if bnum*s<=1000 else x+12
    d.text((lx,yy+4),f"{total:,}",font=f("DejaVuSansMono-Bold.ttf",20),fill=FG)
    d.text((90,y+108),note,font=f("DejaVuSans.ttf",20),fill=MUTED)
    y+=170
# legend
x=60; y=860
for k,lab in [("diff","diff"),("rules","CLAUDE.md rules"),("interface","interface stubs"),("callSite","caller excerpts"),("file","whole files"),("tool","tool schemas")]:
    d.rectangle((x,y+4,x+20,y+24),fill=C[k]); d.text((x+30,y),lab,font=f("DejaVuSans.ttf",21),fill=FG); x+=30+d.textlength(lab,font=f("DejaVuSans.ttf",21))+40
im.save(P+"window.png")

# ---------- eviction order 1400x620
im=Image.new("RGB",(1400,640),BG); d=ImageDraw.Draw(im)
d.text((60,40),"Same items, different order, 8,000-token budget",font=f("DejaVuSans-Bold.ttf",38),fill=FG)
d.text((60,94),"A first-fit packer keeps whatever it reaches first. My first draft reached the tools first.",font=f("DejaVuSans.ttf",22),fill=MUTED)
s=1200/8000
def row(y,title,parts,used,cov,ok,sub):
    rr(d,(60,y,1340,y+200),PANEL,LINE,14)
    d.text((90,y+18),title,font=f("DejaVuSans-Bold.ttf",26),fill=FG)
    w=d.textlength(cov,font=f("DejaVuSans-Bold.ttf",34)); d.text((1310-w,y+14),cov,font=f("DejaVuSans-Bold.ttf",34),fill=GREEN if ok else RED)
    x=90; yy=y+70
    rr(d,(90,yy,90+1200,yy+40),(33,39,54),None,6)
    for k,v in parts:
        ww=int(v*s); d.rectangle((x,yy,x+ww,yy+40),fill=C[k])
        if ww>70: d.text((x+8,yy+9),f"{v:,}",font=f("DejaVuSansMono-Bold.ttf",18),fill=BG)
        x+=ww
    d.text((90,y+128),sub,font=f("DejaVuSans.ttf",21),fill=MUTED)
    d.text((90,y+160),f"used {used:,} of 8,000",font=f("DejaVuSansMono.ttf",19),fill=MUTED)
row(150,"diff → rules → tools → evidence  (first draft)",[("diff",2000),("rules",1700),("tool",4100),("interface",120)],7920,"2 / 5",False,"8 tools fit; 2 of 3 interface stubs and all 4 caller excerpts were evicted")
row(380,"diff → rules → evidence → tools",[("diff",2000),("rules",1700),("interface",390),("callSite",640),("tool",3160)],7890,"5 / 5",True,"all evidence fits; 6 of 12 tools still fit (Read, Grep, Glob, WebFetch, WebSearch, PR diff)")
im.save(P+"eviction.png")

# ---------- code card 1400x900 (LinkedIn)
im=Image.new("RGB",(1400,900),BG); d=ImageDraw.Draw(im)
d.text((60,40),"The reviewer's packet is a build step",font=f("DejaVuSans-Bold.ttf",40),fill=FG)
d.text((60,98),"ContextPacket, Compiler.swift (simplified): what the review contract selects, in order",font=f("DejaVuSans.ttf",22),fill=MUTED)
rr(d,(60,150,1340,660),(22,26,36),LINE,14)
mono=f("DejaVuSansMono.ttf",24)
KW=(198,120,221); TY=(97,175,239); CM=(110,120,140); ST=FG; GR=C["callSite"]
lines=[
 [("case ",KW),(".contract",ST),(":",ST)],
 [("    // root + the modules this diff touches, not one 9,000-token CLAUDE.md",CM)],
 [("    let ",KW),("rules = repo.scopedRules.filter { !$0.covers.isDisjoint(with: touched) }",ST)],
 [("",ST)],
 [("    // interfaces the diff uses from other modules",CM)],
 [("    let ",KW),("evidence = interfaceItems(repo: repo, changed: changed)",ST)],
 [("    // reverse edges: who calls what this diff changed",CM)],
 [("        + ",ST),("callSiteItems",GR),("(repo: repo, diff: diff)",ST)],
 [("",ST)],
 [("    // evidence before tools (read/search/review only): a tight budget",CM)],
 [("    // drops tools, not callers",CM)],
 [("    return ",KW),("rules + evidence + reviewTools",ST)],
]
for i,segs in enumerate(lines):
    x=95; y=172+i*38
    for t,c in segs: d.text((x,y),t,font=mono,fill=c); x+=d.textlength(t,font=mono)
d.text((60,685),"Constructed iOS monorepo, one diff, five seeded findings:",font=f("DejaVuSans.ttf",26),fill=FG)
d.text((60,730),"whole modules, 77,460 tokens  →  evidence for 2 of 5",font=f("DejaVuSansMono-Bold.ttf",26),fill=RED)
d.text((60,772),"review contract, 10,870 tokens  →  evidence for 5 of 5",font=f("DejaVuSansMono-Bold.ttf",26),fill=GREEN)
d.text((60,840),"github.com/rajatslakhina/context-packet-article-demo",font=f("DejaVuSans.ttf",24),fill=MUTED)
im.save(P+"code-card.png")
print("ok")
