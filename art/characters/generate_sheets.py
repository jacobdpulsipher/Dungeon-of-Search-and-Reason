from PIL import Image, ImageDraw
from pathlib import Path
W,H=40,48
D=8
FR=4
ROWS=6
# directions clockwise starting down, down-left, left, up-left, up, up-right, right, down-right
# palette
P={
'outline':(25,27,40,255),'deep':(34,43,61,255),'navy':(39,54,76,255),'navyhi':(61,78,101,255),
'ochre':(185,103,42,255),'ochrehi':(226,144,61,255),'rust':(126,63,39,255),'cream':(244,222,176,255),
'skin':(226,164,119,255),'skinhi':(248,199,147,255),'hair':(37,32,37,255),'hairhi':(63,49,49,255),
'gold':(239,184,86,255),'steel':(112,139,157,255),'steelhi':(177,202,207,255),'steelsh':(66,86,106,255),
'red':(255,72,79,255),'redhi':(255,168,126,255),'glow':(255,216,125,255),'black':(20,24,34,255),
'boot':(45,37,39,255),'dust':(215,183,126,255)}

def make(robot=False):
  im=Image.new('RGBA',(W*D*FR,H*ROWS),(0,0,0,0))
  for row in range(ROWS):
   for direction in range(D):
    for f in range(FR):
     cell=Image.new('RGBA',(W,H),(0,0,0,0)); q=ImageDraw.Draw(cell)
     # drawing in canonical side-facing x+, facing direction mirrored for leftward views; vertical fronts/back variants use orientation tweaks
     left=direction in (1,2,3,4)
     back=direction in (3,4,5)
     diag=direction in (1,3,5,7)
     flip=left
     walk=row==1; leapstart=row==2; air=row==3; land=row==4; fire=row==5
     step=[0,2,0,-2][f] if walk else 0
     bob=(-1 if walk and f in (1,3) else 0) + (-1 if row==0 and f==1 else 0)
     tuck=air or leapstart
     # use drawing coordinates, helper rect with flip performed at final
     def rect(box,c): q.rectangle(box,fill=P[c])
     def poly(points,c): q.polygon(points,fill=P[c])
     # shadow/glow-free contact shadow pixels
     # legs (stance, stride, or tucked)
     if tuck:
      rect((12,31,18,36),'navy'); rect((21,31,27,36),'navyhi')
      foot_shift = [-2, 0, 2, 0][f] if air else [0, 1, 0, -1][f]
      rect((9+foot_shift,35,17+foot_shift,38),'boot'); rect((24-foot_shift,34,30-foot_shift,37),'boot')
     else:
      lshift=step; rshift=-step
      if land: lshift=-2; rshift=2
      rect((13+lshift,29+bob,18+lshift,38+bob),'navy'); rect((22+rshift,29+bob,27+rshift,38+bob),'navyhi')
      rect((11+lshift,37+bob,19+lshift,40+bob),'boot'); rect((21+rshift,37+bob,29+rshift,40+bob),'boot')
     # torso silhouette and coat
     rect((11,16+bob,28,32+bob),'outline')
     rect((12,17+bob,27,30+bob),'ochre' if not robot else 'steelsh')
     rect((12,20+bob,15,30+bob),'rust' if not robot else 'steel')
     rect((24,19+bob,27,29+bob),'ochrehi' if not robot else 'steel')
     # Long coat tails lift and swing during the leap, then settle on landing.
     if row == 2:
      poly([(12,28+bob),(17,29+bob),(17,34+bob),(13,32+bob)],'rust' if not robot else 'steel')
     elif row == 3:
      tail_y = [3, 1, -1, 1][f]
      poly([(12,27+bob),(18,29+bob),(15,35+bob+tail_y),(10,33+bob+tail_y)],'rust' if not robot else 'steel')
      if not robot: rect((11,30+bob+tail_y,13,31+bob+tail_y),'ochrehi')
     elif row == 4:
      tail_y = [2, 1, 0, 0][f]
      poly([(12,28+bob),(18,29+bob),(17,33+bob+tail_y),(12,32+bob+tail_y)],'rust' if not robot else 'steel')
     # shirt/chest
     if robot:
      rect((17,18+bob,23,26+bob),'gold'); rect((18,19+bob,22,24+bob),'red')
      rect((14,28+bob,26,30+bob),'steelhi')
     else:
      rect((17,18+bob,22,27+bob),'cream'); rect((18,23+bob,21,24+bob),'gold')
      rect((16,26+bob,24,27+bob),'rust')
      rect((13,28+bob,26,30+bob),'gold')
      rect((25,27+bob,27,29+bob),'deep') # holster
     # arms, aim wrist + compact pistol
     rect((9,19+bob,12,27+bob),'rust' if not robot else 'steelsh')
     rect((27,18+bob,29,25+bob),'ochrehi' if not robot else 'steel')
     rect((28,23+bob,31,25+bob),'skin' if not robot else 'steelhi')
     # head face
     rect((14,7+bob,26,17+bob),'outline')
     rect((15,8+bob,25,16+bob),'steel' if robot else 'skin')
     if robot:
      rect((15,8+bob,25,11+bob),'steelhi')
      rect((15,12+bob,25,14+bob),'red'); rect((18,12+bob,21,12+bob),'redhi')
      rect((24,9+bob,25,10+bob),'gold')
     else:
      # swept dark hair, fringe, sideburn
      poly([(14,11+bob),(15,6+bob),(19,5+bob),(25,7+bob),(28,6+bob),(25,10+bob),(21,9+bob),(18,11+bob)],'hair')
      rect((16,7+bob,23,8+bob),'hairhi'); rect((15,10+bob,16,14+bob),'hair')
      rect((21,11+bob,22,11+bob),'outline') # eye
      rect((20,14+bob,23,14+bob),'rust')
     # small shoulder/ear and belt detail
     rect((12,18+bob,14,21+bob),'gold' if not robot else 'steelhi')
     rect((20,28+bob,21,29+bob),'cream' if not robot else 'red')
     # direction-facing pistol silhouette, 8-way direction cues: mirror and rotate small barrel according to facings
     # for vertical orientation, change wrist/barrel y while body is 3/4 facing
     if direction in (3,4,5):
      rect((23,18+bob,25,25+bob),'deep'); rect((23,15+bob,26,19+bob),'gold' if not robot else 'red')
      rect((24,13+bob,26,15+bob),'outline')
     else:
      rect((28,23+bob,32,24+bob),'deep'); rect((30,22+bob,34,23+bob),'gold' if not robot else 'red')
      rect((32,22+bob,34,22+bob),'cream' if not robot else 'redhi')
     # shooting muzzle spark
     if fire and f in (0,1):
      if direction in (3,4,5): poly([(22,11+bob),(25,8+bob),(28,11+bob),(25,14+bob)],'glow')
      else: poly([(33,21+bob),(37,22+bob),(34,25+bob)],'glow')
     # movement effects
     if leapstart and f==0: rect((7,41,11,42),'dust'); rect((29,42,33,43),'dust')
     if land and f<2: rect((6,41,11,42),'dust'); rect((29,41,34,42),'dust')
     if flip: cell=cell.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
     x=(f*D+direction)*W; y=row*H
     im.alpha_composite(cell,(x,y))
  return im
for name,bot in [('rogue',False),('robot',True)]:
 make(bot).save(Path('art/characters')/(name+'.png'))
