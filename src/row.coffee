class GridEdit.Row
  constructor: (@attributes, @table) ->
    @id = @table.rows.length
    @cells = []
    @index = @table.rows.length
    @element = document.createElement 'tr'
    @cssClass = @attributes.cssClass
    @element.className = @cssClass if @cssClass
    @oldBorderBottom = @element.style.borderBottom
    @oldBorderTop = @element.style.borderTop
    @type = @attributes.gridEditRowType

    table = @table
    row = @
    @element.ondragenter = (e) ->
      table.lastDragOverIsBeforeFirstRow = false
      prevRow = table.lastDragOver
      if prevRow
        if row.index != 0 and prevRow.index == row.index
          # do nothing
        else
          prevRow.element.style.borderBottom = row.oldBorderBottom
          row.element.style.borderBottom = table.theme.borders.dragBorderStyle
      else
        row.element.style.borderBottom = table.theme.borders.dragBorderStyle
      table.lastDragOver = row

    @includeRowHandles = @table.config.includeRowHandles

    GridEdit.Utilities::setAttributes @element,
      id: "row-#{@id}"

  createCell: (value) ->
    index = @cells.length
    col = @table.cols[index]
    type = col.type
    cell

    switch type
      when 'string'
        cell = new GridEdit.StringCell(value, @)
        break
      when 'number'
        cell = new GridEdit.NumberCell(value, @)
        break
      when 'date'
        cell = new GridEdit.DateCell(value, @)
        break
      when 'html'
        cell = new GridEdit.HTMLCell(value, @)
        break
      when 'select'
        cell = new GridEdit.SelectCell(value, @)
        break
      when 'textarea'
        cell = new GridEdit.TextAreaCell(value, @)
        break
      when 'checkbox'
        cell = new GridEdit.CheckBoxCell(value, @)
        break
      else
        cell = new GridEdit.GenericCell(value, @)
        break

    cell

  below: -> @table.rows[@index + 1]
  above: -> @table.rows[@index - 1]
  select: ->
    for cell in @cells
      cell.addToSelection()

  afterEdit: () ->
    @table.calculateSubtotals()

  addHandle: () ->
    if @includeRowHandles
      cell = new GridEdit.HandleCell @
      @element.appendChild cell.element

###
  Generic Row
  -----------------------------------------------------------------------------------------
###

class GridEdit.GenericRow extends GridEdit.Row
  constructor: (@attributes, @table) ->
    super
    @editable = true

    @addHandle()

    for col, i in @table.cols
      cell = @createCell @attributes[col.valueKey]
      @cells.push cell
      @table.cols[i].cells.push cell
      @element.appendChild cell.element

    delete @attributes
    @

###
  Static Row
  -----------------------------------------------------------------------------------------
###

class GridEdit.StaticRow extends GridEdit.Row
  constructor: (@attributes, @table) ->
    super

    @addHandle()

    @editable = @attributes.editable = false
    @element.innerHTML = @attributes.html
    @type = 'static'
    delete @attributes
    @

###
  Subtotal Row
  -----------------------------------------------------------------------------------------
###

class GridEdit.SubTotalRow extends GridEdit.Row
  constructor: (@attributes, @table) ->
    super
    @subtotalColumns = {}
    @labels = @attributes.labels
    @running = @attributes.running

    @addHandle()

    for col, i in @table.cols
      cell = new GridEdit.GenericCell '', @
      cell.editable = false
      if @labels
        value = @labels[col.valueKey]
        # cell.value(value, false) if value
        cell.element.innerHTML = value || ''
      @cells.push cell
      @table.cols[i].cells.push cell
      @element.appendChild cell.element

      if(@attributes.subtotal[col.valueKey])
        @subtotalColumns[col.valueKey] = i

    @table.subtotalRows.push(@)
    @calculate()

  calculate: () ->
    start = -1
    unless @running
      for sub in @table.subtotalRows
        rowIndex = sub.index
        if rowIndex < @index and rowIndex > start
          start = rowIndex

    for col, index of @subtotalColumns
      total = 0
      for row in @table.rows when row.index > start
        break if row.index == @index
        continue if row.type == 'subtotal' or row.type == 'header' # todo - add calculable property to row classes
        cell = row.cells[index]
        total += Number(cell.value()) if cell
      @cells[index].value(total, false)

    @

  afterEdit: () ->
    # do not calculate

###
  Header Row
  -----------------------------------------------------------------------------------------
###

class GridEdit.HeaderRow extends GridEdit.Row
  constructor: (@attributes, @table) ->
    super
    @editable = true
    @addHandle()

    for col, i in @table.cols
      cell = new GridEdit.HTMLCell @attributes[col.valueKey], @
      cell.editable = true
      @cells.push cell
      @table.cols[i].cells.push cell
      @element.appendChild cell.element

    delete @attributes
    @

