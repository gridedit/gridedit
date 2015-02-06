class GridEdit.Utilities
  constructor: ->

  setAttributes: (el, attrs) ->
    for key, value of attrs
      el.setAttribute key, value if value

  setStyles: (el, styles) ->
    for key, value of styles
      el.style[key] = "#{value}px"

  clearActiveCells: (table) ->
    redCells = table.redCells
    activeCells = table.activeCells
    if redCells.length > 0
      for redCell, index in redCells
        redCell?.makeInactive()
      table.redCells = []
    if activeCells.length > 0
      for activeCell, index in activeCells
        activeCell?.makeInactive()
        activeCell?.hideControl()
      table.activeCells = []
    table.selectionStart = null
    table.selectionEnd = null
    table.contextMenu.hide()
    if table.selectedCol then table.selectedCol.makeInactive()
  capitalize: (string) -> string.toLowerCase().replace /\b./g, (a) -> a.toUpperCase()

  valueFromKey: (key, shift) ->
    char = String.fromCharCode key
    if shift then char else char.toLowerCase()
