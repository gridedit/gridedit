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

  fixHeaders: (ge) ->
    clearTimeout @fixHeadersBuffer
    @fixHeadersBuffer = setTimeout ( ->
      currentTH = ge.thead
      currentTHElements = currentTH.getElementsByTagName 'th'
      if ge.fixedHeader
        # modify the existing fixed header
        left = 0
        for cell, index in ge.fixedHeader.cells
          currentTHElement = currentTHElements[index]
          currentTHElementBounds = currentTHElement.getBoundingClientRect()
          cell.innerHTML = currentTHElement.innerHTML
          cell.className = currentTHElement.className
          cell.style.minWidth = currentTHElementBounds.width + 'px'
          cell.style.minHeight = currentTHElementBounds.height + 'px'
          cell.style.backgroundColor = ge.fixedHeader.backgroundColor
          cell.style.left = left + 'px'
          left += currentTHElementBounds.width
      else
        # create a new fixed header
        fakeTHCells = []
        backgroundColor = window.getComputedStyle(currentTH).backgroundColor
        backgroundColor = 'white' if backgroundColor == 'rgba(0, 0, 0, 0)'
        currentTHBounds = currentTH.getBoundingClientRect()
        fakeTable = document.createElement 'table'
        fakeTable.className = ge.tableEl.className
        fakeTable.style.position = 'fixed'
        fakeTable.style.top = currentTHBounds.top + 'px'
        fakeTable.style.left = currentTHBounds.left + 'px'
        fakeTable.style.zIndex = 1039
        fakeTHead = document.createElement 'thead'
        fakeTHead.className = currentTH.className
        fakeTR = document.createElement 'tr'
        if ge.rows.length > 0
          left = 0
          for currentTHElement, index in currentTHElements
            currentTHElementBounds = currentTHElement.getBoundingClientRect()
            fakeTH = document.createElement 'th'
            fakeTH.innerHTML = currentTHElement.innerHTML
            fakeTH.className = currentTHElement.className
            fakeTH.style.position = 'absolute'
            fakeTH.style.width = currentTHElementBounds.width + 'px'
            fakeTH.style.height = currentTHElementBounds.height + 'px'
            fakeTH.style.left = left + 'px'
            fakeTH.style.backgroundColor = backgroundColor
            left += currentTHElementBounds.width
            fakeTHCells.push fakeTH
            fakeTR.appendChild(fakeTH)
          fakeTHead.appendChild(fakeTR)
          fakeTable.appendChild fakeTHead
          document.body.appendChild fakeTable

          # store metaData about the fixed header
          ge.fixedHeader = {
            thead: fakeTHead,
            cells: fakeTHCells,
            backgroundColor: backgroundColor
          }

          # copy the current window 'onresize' function
          windowOnResize = window.onresize;

          # rewrite the window's 'onresize' function to realign the headers
          window.onresize = (e) ->
            GridEdit.Utilities::fixHeaders(ge);
            # add in the original window's 'onresize' functionality
            windowOnResize(e);
      ), 100
