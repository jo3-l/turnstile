#import "@preview/pinit:0.2.2": *

#let __ndproof-justification-marker = <__ndproof_justification>

#let __ndproof-extract-justification(body) = {
  let sequence = type([])
  if type(body) == sequence and body.has("children") {
    for it in body.children {
      if type(it) == sequence and it.has("children") {
        let justification = __ndproof-extract-justification(it)
        if justification != none {
          return justification
        }
      } else if type(it) == content and it.func() == figure and it.label == __ndproof-justification-marker {
        return it.body
      }
    }
  }
  return none
}

#let nospace(symbol) = math.class("normal", symbol)

#let assumption = $"AS"$
#let AS = assumption
#let premise = $"PR"$

#let reiterate(m) = $"R" space #m$
#let introand(k, l) = $nospace(and)"I" space #k, #l$
#let elimand(m) = $nospace(and)"E" space #m$

#let introor(m) = $nospace(or)"I" space #m$
#let elimor(i, jk, lm) = {
  let (j, k) = jk
  let (l, m) = lm
  $nospace(or)"E" space #i, space #j#sym.hyph.nobreak#k, space #l#sym.hyph.nobreak#m$
}

#let introcond(k, l) = $nospace(->)"I" space #k, #l$
#let elimcond(k, l) = $nospace(->)"E" space #k, #l$

#let introbicond(k, l) = $nospace(<->)"I" space #k, #l$
#let elimbicond(m) = $nospace(<->)"E" space #m$

#let intronot(k, l) = $nospace(not)"I" space #k#sym.hyph.nobreak#l$
#let elimnot(k, l) = $nospace(not)"E" space #k, #l$

#let raa(k, l) = $"RAA" space #k#sym.hyph.nobreak#l$

#let elimcontra(m) = $nospace(bot)"E" #m$

#let by(justification) = [#figure(justification) #__ndproof-justification-marker]

#let justification-for-kind = ("premise": premise)

/// Return a list of dictionaries `(claim: str, justification: content, depth: number, closes: number)`.
/// `closes` is nonzero if and only if the item concludes a nested subproof, and indicates how many layers
/// of nesting to go back up.
#let __ndproof-process(body, depth: 0) = {
  let sequence = type([])
  let result = ()
  if type(body) == sequence and body.has("children") {
    for it in body.children {
      if type(it) == content and it.func() == terms.item {
        assert(type(it.term.text) == str)
        let kind = it.term.text
        assert(kind in ("premise", "subproof", "have"))
        if kind == "subproof" {
          let subproof-items = __ndproof-process(it.description, depth: depth + 1)
          if subproof-items.len() > 0 {
            subproof-items.at(-1).at("closes") += 1
          }
          result += subproof-items
        } else {
          let justification = justification-for-kind.at(kind, default: none)
          if justification == none {
            justification = __ndproof-extract-justification(it.description)
          }
          result.push((
            claim: it.description,
            justification: justification,
            depth: depth,
            closes: 0,
          ))
        }
      }
    }
  }
  return result
}

#let __ndproof-pin-id(proof-id, pin-counter) = "__ndproof-pin/" + str(proof-id) + "/" + str(pin-counter)

// Return a list of subproofs `(depth:, start-pin:, end-pin:)` and a mapping of item indexes to pins to place.
#let __ndproof-subproof-pins(proof-id, items) = {
  let subproofs = () // list of (depth:, start-pin:, end-pin:)
  let open-subproofs = () // stack of indexes into `subproofs`
  let pin-for-item = (:) // item ID -> pin; keys are strings because of https://github.com/typst/typst/issues/5912

  let pin-counter = 0

  for (idx, item) in items.enumerate() {
    if item.depth > open-subproofs.len() {
      // new subproof opened
      let pin-id = __ndproof-pin-id(proof-id, pin-counter)
      while open-subproofs.len() < item.depth {
        let new-subproof-idx = subproofs.len()
        open-subproofs.push(new-subproof-idx)
        subproofs.push((depth: open-subproofs.len(), start-pin: pin-id, end-pin: none)) // `end-pin` filled in later
      }
      pin-for-item.insert(str(idx), pin-id)
      pin-counter += 1
    }

    if item.closes > 0 {
      let pin-id = __ndproof-pin-id(proof-id, pin-counter)
      while open-subproofs.len() > item.depth - item.closes {
        let subproof-idx = open-subproofs.pop()
        subproofs.at(subproof-idx).at("end-pin") = pin-id
      }
      pin-for-item.insert(str(idx), pin-id)
      pin-counter += 1
    }
  }

  return (subproofs, pin-for-item)
}

#let __ndproof-counter = counter("__ndproof-counter")

#let __calc-left-indent(depth) = {
  if depth == 0 {
    return 0em
  }
  return .5em + (depth - 1) * 1em
}

#let ndproof(body, line-stroke: .5pt) = context {
  let items = __ndproof-process(body)
  let proof-id = __ndproof-counter.get().at(0)

  let (subproofs, pin-for-item) = __ndproof-subproof-pins(proof-id, items)

  let rows = ()
  for (idx, item) in items.enumerate() {
    let pin-id = pin-for-item.at(str(idx), default: none)
    let indent = __calc-left-indent(item.depth)
    rows += (
      [#{ idx + 1 }.],
      box(inset: 0pt, stack(dir: ltr, if pin-id != none { pin(pin-id) }, pad(left: indent, item.claim))),
      item.justification,
    )
  }

  show __ndproof-justification-marker: none
  grid(
    columns: 3,
    column-gutter: (1em, 5em),
    align: (right + horizon, left + horizon, left + horizon),
    row-gutter: .8em,
    ..rows
  )

  for (start-pin, end-pin, depth) in subproofs {
    let indent = __calc-left-indent(depth) - .5em
    pinit-line(
      start-pin,
      start-pin,
      start-dy: -2pt,
      end-dy: -2pt,
      start-dx: indent,
      end-dx: indent + 3pt,
      stroke: line-stroke,
    )
    pinit-line(
      start-pin,
      end-pin,
      start-dy: -2pt,
      end-dy: +2pt,
      start-dx: indent,
      end-dx: indent,
      stroke: .5pt,
    )
    pinit-line(
      end-pin,
      end-pin,
      start-dy: +2pt,
      end-dy: +2pt,
      start-dx: indent,
      end-dx: indent + 3pt,
      stroke: line-stroke,
    )
  }
  __ndproof-counter.step()
}
