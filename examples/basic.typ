#import "../lib.typ": *

#set page(height: auto, width: auto, margin: 2em)

#ndproof[
  / premise: $(p and (q or r))$
  / have: $p$ #by(elimand(1))
  / have: $(q or r)$ #by(elimand(1))

  / subproof:
    / assume: $q$
    / have: $(p and q)$ #by(introand(2, 4))
    / have: $(((p and q) or (p and r)))$ #by(introor(5))

  / subproof:
    / assume: $r$
    / have: $(p and r)$ #by(introand(2, 7))
    / have: $((p and q) or (p and r))$ #by(introor(8))

  / have: $((p and q) or (p and r))$ #by(elimor(3, (4, 6), (7, 9)))
]
