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
    table.openCell.edit(table.openCell.control.value) if table.openCell
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

  getScreenDimensions: ->
    w = window
    d = document
    e = d.documentElement
    g = d.getElementsByTagName('body')[0]
    x = w.innerWidth || e.clientWidth || g.clientWidth
    y = w.innerHeight|| e.clientHeight|| g.clientHeight
    { width: x, height: y }

  repositionFixedHeader: (ge) ->
    fixedHeader = ge.fixedHeader
    if fixedHeader
      fakeTable = fixedHeader.table
      if fakeTable
        # adjust for page scroll
        doc = document.documentElement
        pageLeft = (window.pageXOffset || doc.scrollLeft) - (doc.clientLeft || 0)
        currentTH = ge.thead
        currentTHBounds = currentTH.getBoundingClientRect()
        fakeTable.style.left = (currentTHBounds.left + pageLeft) + 'px'

  fixHeaders: (ge) ->

    clearTimeout @fixHeadersBuffer

    @fixHeadersBuffer = setTimeout ( ->
      indexModifier = if ge.config.includeRowHandles then 1 else 0
      currentTH = ge.thead
      currentTHElements = currentTH.getElementsByTagName 'th'

      if ge.fixedHeader
        table = ge.fixedHeader.table
        ge.fixedHeader.table.parentNode.removeChild(table) if table and table.parentNode
        backgroundColor = ge.fixedHeader.backgroundColor
      else
        backgroundColor = window.getComputedStyle(currentTH).backgroundColor
        backgroundColor = 'white' if (backgroundColor == 'rgba(0, 0, 0, 0)' or backgroundColor == 'transparent')

      # adjust for page scroll
      doc = document.documentElement
      pageLeft = (window.pageXOffset || doc.scrollLeft) - (doc.clientLeft || 0)
      pageTop = (window.pageYOffset || doc.scrollTop)  - (doc.clientTop || 0)

      # adjust for GridEdit scroll
      geElement = ge.element
      geLeft = (geElement.scrollLeft || 0)
      geTop = (geElement.scrollTop || 0)

      currentTHBounds = currentTH.getBoundingClientRect()
      fakeTable = document.createElement 'table'
      fakeTable.className = ge.tableEl.className + ' ge-fixed-table-header'
      fakeTable.style.position = 'absolute'
      fakeTable.style.top = (currentTHBounds.top + pageTop + geTop) + 'px'
      fakeTable.style.left = (currentTHBounds.left + pageLeft + geLeft) + 'px'
      fakeTable.style.width = currentTHBounds.width + 'px'
      fakeTable.style.zIndex = 1039
      fakeTable.style.pointerEvents = 'none'
      fakeTHead = document.createElement 'thead'
      fakeTHead.className = currentTH.className
      fakeTHead.ondragenter = currentTH.ondragenter
      fakeTHead.ondragleave = currentTH.ondragleave
      fakeTR = document.createElement 'tr'
      left = 0
      for currentTHElement, index in currentTHElements
        currentTHElementBounds = currentTHElement.getBoundingClientRect()
        fakeTH = document.createElement 'th'
        fakeTH.innerHTML = currentTHElement.innerHTML
        fakeTH.className = currentTHElement.className
        fakeTH.style.position = 'absolute'
        fakeTH.style.minWidth = currentTHElementBounds.width + 'px'
        fakeTH.style.maxWidth = currentTHElementBounds.width + 'px'
        fakeTH.style.width = currentTHElementBounds.width + 'px'
        fakeTH.style.minHeight = currentTHElementBounds.height + 'px'
        fakeTH.style.maxHeight = currentTHElementBounds.height + 'px'
        fakeTH.style.left = left + 'px'
        fakeTH.style.backgroundColor = backgroundColor
        fakeTH.setAttribute('col-id', index - indexModifier)
        fakeTH.onclick = (e) ->
          n = @getAttribute 'col-id'
          col = ge.cols[n]
          GridEdit.Utilities::clearActiveCells ge
          setTimeout ( ->
            col.makeActive()
            for cell in col.cells
              cell.addToSelection()
          ), 0

        col = ge.cols[index - indexModifier]
        if col
          if col.headerStyle
            for key, value of col.headerStyle
              fakeTH.style[key] = value
          else
            for key, value of col.style
              fakeTH.style[key] = value

        left += currentTHElementBounds.width
        fakeTR.appendChild fakeTH
      fakeTHead.appendChild fakeTR
      fakeTable.appendChild fakeTHead
      document.body.appendChild fakeTable

      # store metaData about the fixed header
      ge.fixedHeader = {
        table: fakeTable,
        backgroundColor: backgroundColor
      }
    ), 100
