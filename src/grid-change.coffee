class GridEdit.GridChange
  constructor: (@cells, value) ->
    useBlank = value == 'ge-blank'
    @changes = []
    @table = @cells[0].col.table
    @borderStyle = @table.theme.cells.selectionBorderStyle
    @highRow = 0
    @highCol = 0

    for cell in @cells
      rowIndex = cell.address[0]
      colIndex = cell.address[1]

      thisChange = {
        row: rowIndex,
        col: colIndex,
        value: if useBlank then '' else value or cell.value()
      }

      if @firstCell
        if thisChange.row < @firstCell.row
          @firstCell = thisChange
        else if thisChange.row == @firstCell.row
          if thisChange.col < @firstCell.col
            @firstCell = thisChange
      else
        @firstCell = thisChange
        @lowRow = thisChange.row
        @lowCol = thisChange.col

      @highRow = thisChange.row if thisChange.row > @highRow
      @highCol = thisChange.col if thisChange.col > @highCol
      @lowRow = thisChange.row if thisChange.row < @lowRow
      @lowCol = thisChange.col if thisChange.col < @lowCol
      @changes.push(thisChange)

    # get relative coordinates for each change
    for change in @changes
      change.rowVector = change.row - @firstCell.row
      change.colVector = change.col - @firstCell.col

    # determine whether this was a scattered change <ctrl>+click
    width = @highCol - @lowCol + 1
    height = @highRow - @lowRow + 1
    area = width * height
    @scattered = @cells.length != area

  applyTo: (gridChange) ->
    copyValue = @changes[0].value

    if gridChange.scattered
      gridChange.fill(copyValue)
      return 'pasteGrid'
    else
      copyWidth = @width()
      copyHeight = @height()
      pasteWidth = gridChange.width()
      pasteHeight = gridChange.height()

      if pasteWidth < copyWidth or pasteHeight < copyHeight
        x = gridChange.firstCell.row
        y = gridChange.firstCell.col
        @apply(x, y)
        return 'copyGrid'
      else
        repeatsWidth = parseInt(pasteWidth / copyWidth)
        repeatsHeight = parseInt(pasteHeight / copyHeight)
        x = gridChange.firstCell.row
        y = gridChange.firstCell.col

        for i in [0...repeatsHeight]
          currentX = (x + (i * copyHeight))
          for j in [0...repeatsWidth]
            currentY = (y + (j * copyWidth))
            @apply(currentX, currentY)
    'pasteGrid'

  copyValues: ->
    x = @firstCell.row
    y = @firstCell.col

    for change in @changes
      cell = @table.getCell(x + change.rowVector, y + change.colVector)
      if cell and cell.editable
        change.oldValue = cell.value()

  width: ->
    @highCol - @lowCol + 1

  height: ->
    @highRow - @lowRow + 1

  fill: (value) ->
    x = @firstCell.row
    y = @firstCell.col

    for change in @changes
      cell = @table.getCell(x + change.rowVector, y + change.colVector)
      if cell and cell.editable
        change.oldValue = cell.value()
        cell.value(value, false)
      else
        change.oldValue = ''

  apply: (x, y) ->
    if x == false or y == false
      x = @firstCell.row
      y = @firstCell.col

    for change in @changes
      cell = @table.getCell(x + change.rowVector, y + change.colVector)
      if cell and cell.editable
        change.oldValue = cell.value()
        cell.value(change.value, false)
      else
        change.oldValue = ''

  undo: (x, y) ->
    if x == false or y == false
      x = @firstCell.row
      y = @firstCell.col

    for change in @changes
      cell = @table.getCell(x + change.rowVector, y + change.colVector)
      cell.value(change.oldValue, false) if cell and cell.editable

  displayBorders: ->
    for cell in @cells
      @addBorder cell

  removeBorders: ->
    for cell in @cells
      cell.element.style.border = ""

  addBorder: (cell) ->

    rowIndex = cell.address[0]
    colIndex = cell.address[1]

    if @scattered
      cell.element.style.border = @borderStyle
    else
      if @firstCell.row == @highRow
        cell.element.style.borderTop = @borderStyle
        cell.element.style.borderBottom = @borderStyle
      else
        if rowIndex == @lowRow
          # top
          cell.element.style.borderTop = @borderStyle
        else if rowIndex == @highRow
          # bottom
          cell.element.style.borderBottom = @borderStyle

      if @firstCell.col == @highCol
        cell.element.style.borderRight = @borderStyle
        cell.element.style.borderLeft = @borderStyle
      else
        if colIndex == @lowCol
          # left
          cell.element.style.borderLeft = @borderStyle
        else if colIndex == @highCol
          # right
          cell.element.style.borderRight = @borderStyle
