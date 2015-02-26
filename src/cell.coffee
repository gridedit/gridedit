class GridEdit.Cell
  constructor: (@originalValue, @row) ->
    @index = @row.cells.length
    @id = "#{@row.id}-#{@index}"
    @address = [@row.id, @index]
    @table = @row.table
    @col = @table.cols[@index]
    @meta = @col
    @element = document.createElement 'td'

  ###
		Initialization
		-----------------------------------------------------------------------------------------
	###

  initialize: ->
    @initEditable()
    @initValueKey()
    @initSource()
    @initOriginalValue()
    @initSourceValue()
    @initNode()
    @initControl()
    @applyControlBehavior()
    @applyEventBehavior()
    GridEdit.Hook::initCellHooks(@)
    @applyStyle()

  initOriginalValue: -> @originalValue = '' if @originalValue == undefined
  initSourceValue: -> @source[@valueKey] = @originalValue
  initEditable: -> @editable = @col.editable != false
  initValueKey: -> @valueKey = @col.valueKey
  initSource: -> @source = @table.config.rows[@address[0]]
  initNode: -> @element.appendChild document.createTextNode @col.format(@originalValue)
  initControl: -> @control = document.createElement 'input'

  ###
  	Display
	  -----------------------------------------------------------------------------------------
  ###

  showRed: -> @showUneditable() # legacy support

  applyStyle: ->
    @element.classList.add @col.cellClass if @col.cellClass
    if @col.style
      for styleName of @col.style
        @element.style[styleName] = @col.style[styleName]

  addToSelection: ->
    @showActive()
    @table.activeCells.push @

  removeFromSelection: ->
    index = @table.activeCells.indexOf(@)
    @table.activeCells.splice(index, 1)
    @showInactive()

  isActive: -> @table.activeCells.indexOf(@) isnt -1

  makeActive: (clearActiveCells = true) ->
    @table.hideControl()
    GridEdit.Utilities::clearActiveCells @table if clearActiveCells
    unless @isActive()
      if GridEdit.Hook::run @, 'beforeActivate', @
        @showActive()
        @table.activeCells.push @
        @table.selectionStart = @
        openCell = @table.openCell
        openCell.edit openCell.control.value if openCell
        GridEdit.Hook::run @, 'afterActivate', @

  makeInactive: -> @showInactive()

  showActive: ->
    unless @isActive()
      @oldBackgroundColor = @element.style.backgroundColor
      @element.style.backgroundColor = @table.theme.cells.activeColor

  showInactive: ->
    @element.style.backgroundColor = @oldBackgroundColor

  showUneditable: ->
    @element.style.backgroundColor = @table.theme.cells.uneditableColor
    @table.redCells.push @

  ###
  	Edit
	  -----------------------------------------------------------------------------------------
  ###

  edit: (value = null) ->
    if @editable
      if value isnt null
        @value value
        @hideControl() if @isBeingEdited()
      else
        @showControl()
    else
      @showUneditable()

  ###
  	Value
	  -----------------------------------------------------------------------------------------
  ###

  value: (newValue = null, addToStack=true) ->
    currentValue = @source[@valueKey]
    if newValue isnt null and newValue isnt currentValue
      newValue = @formatValue(newValue)
      oldValue = @value()
      if GridEdit.Hook::run @, 'beforeEdit', @, oldValue, newValue
        @table.addToStack { type: 'cell-edit', oldValue: oldValue, newValue: newValue, address: @address } if addToStack
        @setValue(newValue)
        @renderValue(newValue)
        @row.afterEdit()
        GridEdit.Hook::run @, 'afterEdit', @, oldValue, newValue, @table.contextMenu.getTargetPasteCell()
        @table.checkIfCellIsDirty(@)
        return newValue
      else
        currentValue
    else
      currentValue

  formatValue: (value) -> value
  setValue: (value) -> @source[@valueKey] = value
  renderValue: (value) -> @element.textContent = @col.format(value)
  select: -> @control.select()

  ###
    Dirty
	  -----------------------------------------------------------------------------------------
  ###

  isDirty: () ->
    return false if @row.alwaysPristine
    @originalValue != @value()
  ###

  	Control
	  -----------------------------------------------------------------------------------------
  ###

  showControl: (value = null) ->
    if @editable
      if GridEdit.Hook::run @, 'beforeControlInit', @
        @table.contextMenu.hideBorders()
        @renderControl()
        @setControlValue(value)
        @table.openCell = @
        GridEdit.Hook::run @, 'afterControlInit', @
    else
      @showUneditable()

  setControlValue: (value) ->
    @control.value = value

  renderControl: ->
    GridEdit.Utilities::setStyles @control, @position()
    @table.element.appendChild @control
    @control.style.position = 'fixed'
    control = @control
    setTimeout(->
      control.focus()
    , 0)

  hideControl: ->
    if GridEdit.Hook::run @, 'beforeControlHide', @
      @control.parentNode.removeChild(@control) if @isBeingEdited()
      @table.openCell = null
      GridEdit.Hook::run @, 'afterControlHide', @

  applyControlBehavior: ->
    cell = @
    table = @table
    @control.onkeydown = (e) ->
      key = e.which
      switch key
        when 13 # return
          cell.edit @value
        when 9 # tab
          cell.edit @value
          moveTo table.nextCell()

  ###
  	Positioning
	  -----------------------------------------------------------------------------------------
  ###

  position: -> @element.getBoundingClientRect()
  reposition: -> GridEdit.Utilities::setStyles @control, @position()
  next: -> @row.cells[@index + 1] or @row.below()?.cells[0]
  previous: -> @row.cells[@index - 1] or @row.above()?.cells[@row.cells.length - 1]
  above: -> @row.above()?.cells[@index]
  below: -> @row.below()?.cells[@index]
  isBefore: (cell) -> cell.address[0] is @address[0] and cell.address[1] > @address[1]
  isAfter: (cell) -> cell.address[0] is @address[0] and cell.address[1] < @address[1]
  isAbove: (cell) -> cell.address[0] > @address[0] and cell.address[1] is @address[1]
  isBelow: (cell) -> cell.address[0] < @address[0] and cell.address[1] is @address[1]
  addClass: (newClass) -> @element.classList.add newClass
  removeClass: (classToRemove) -> @element.classList.remove classToRemove
  isBeingEdited: -> if @control then @control.parentNode? else false
  toggleActive: -> if @isActive() then @removeFromSelection() else @makeActive(false)

  isVisible: ->
    position = @position()
    (position.top >= @table.topOffset) and (position.bottom <= window.innerHeight)

  ###
  	Events
	  -----------------------------------------------------------------------------------------
  ###

  onReturnKeyPress: ->
    @table.moveTo @table.belowCell()
  onSpaceKeyPress: -> @edit()
  onKeyPress:(value) -> @showControl(value)

  applyEventBehavior: ->
    cell = @
    table = @table
    doubleClickTimeout = null

    @element.onclick = (e) ->
      table.contextMenu.hideBorders()

      if table.lastClickCell == cell
        # double click event
        if GridEdit.Hook::run cell, 'onDblClick', cell, e
          table.lastClickCell = null
          cell.showControl(cell.value())
      else
        table.lastClickCell = cell

        clearInterval doubleClickTimeout
        doubleClickTimeout = setTimeout(->
          table.lastClickCell = null
        , 1000)

        if GridEdit.Hook::run cell, 'onClick', cell, e
          ctrl = e.ctrlKey
          cmd = e.metaKey
          shift = e.shiftKey

          activateRow = (row) ->
          if cellFromCol <= cellToCol
            for col in [cellFromCol..cellToCol]
              c = table.getCell(row, col)
              c.makeActive(false)
          else
            for col in [cellToCol..cellFromCol]
              c = table.getCell(row, col)
              c.makeActive(false)

          if ctrl or cmd
            cell.toggleActive()
          if shift
            cellFrom = table.activeCells[0]
            cellFromRow = cellFrom.address[0]
            cellFromCol = cellFrom.address[1]
            cellToRow = cell.address[0]
            cellToCol = cell.address[1]
            if cellFromRow <= cellToRow
              for row in [cellFromRow..cellToRow]
                activateRow row
            else
              for row in [cellToRow..cellFromRow]
                activateRow row
        false

    @element.onmousedown = (e) ->
      if e.which is 3 # right mouse button
        table.contextMenu.show(e.x, e.y, cell)
        return
      else
        unless e.shiftKey or e.ctrlKey or e.metaKey
          table.state = "selecting"
          cell.makeActive()
      false

    @element.onmouseover = (e) ->
      if table.state is 'selecting'
        table.selectionEnd = cell
        table.setSelection()

    @element.onmouseup = (e) ->
      if e.which != 3 # right mouse button
        table.selectionEnd = cell
        table.state = "ready"
        table.setSelection() unless e.metaKey or e.ctrlKey

    if table.mobile
      startY = null
      @element.ontouchstart = (e) ->
        startY = e.changedTouches[0].clientY
        GridEdit.Utilities::clearActiveCells table
        if table.openCell then table.openCell.hideControl()
      @element.ontouchend = (e) ->
        y = e.changedTouches[0].clientY
        if e.changedTouches.length < 2 and (y is startY)
          e.preventDefault()
          cell.edit()

###
  String Cell
  -----------------------------------------------------------------------------------------
###

class GridEdit.StringCell extends GridEdit.Cell
  constructor: (value, @row) ->
    super
    @type = 'string'
    @initialize()
    @

###
  Number Cell
  -----------------------------------------------------------------------------------------
###

class GridEdit.NumberCell extends GridEdit.Cell
  constructor: (value, @row) ->
    super
    @type = 'number'
    @initialize()
    @

  normalizeValue: (value) ->
    if value is null or value is undefined or value == ''
      null
    else
      n = Number(value)
      if isNaN n then null else n

  formatValue: (newValue) ->
    @normalizeValue(newValue)

  setValue: (newValue) ->
    @source[@valueKey] = @normalizeValue(newValue)

  ###
		CheckBox Cell
		-----------------------------------------------------------------------------------------
	###

class GridEdit.CheckBoxCell extends GridEdit.Cell
  constructor: (value, @row) ->
    super
    @type = 'checkbox'
    @initialize()
    @

  initialize: ->
    @initEditable()
    @initValueKey()
    @initSource()
    @initOriginalValue()
    @initSourceValue()
    @applyEventBehavior()
    GridEdit.Hook::initCellHooks(@)
    @applyStyle()
    @initNode()

    @toggleable = @editable
    @editable = false # prevents default cell edit behavior
    @renderValue()

  initNode: ->
    div = document.createElement 'div'
    div.style.width = '1em'
    div.style.margin = 'auto'
    @span = document.createElement 'span'
    div.appendChild @span
    @element.appendChild div

  edit: () -> false
  initControl: -> @toggle()
  renderControl: -> GridEdit.Utilities::clearActiveCells @table
  isBeingEdited: -> false

  toggle: ->
    if @toggleable
      @value(!@value())
      @setValue(@value())
    else
      @showUneditable()

  renderValue: ->
    disabled = if @toggleable then '' else 'disabled'
    if @value()
      if @table.theme.inputs.checkbox.checkedClassName
        @span.className = @table.theme.inputs.checkbox.checkedClassName
      else
        @span.innerHTML = "<input type='checkbox' #{disabled} checked />"
    else
      if @table.theme.inputs.checkbox.uncheckedClassName
        @span.className = @table.theme.inputs.checkbox.uncheckedClassName
      else
        @span.innerHTML = "<input type='checkbox' #{disabled} />"

  applyEventBehavior: ->
    super

    cell = @
    @element.onclick = (e) ->
      cell.table.contextMenu.hideBorders()
      cell.toggle()

  onSpaceKeyPress: ->
    @toggle()

###
	Date Cell
	-----------------------------------------------------------------------------------------
###

class GridEdit.DateCell extends GridEdit.Cell
  constructor: (value, @row) ->
    super
    @type = 'date'
    @initialize()
    @

  initNode: ->
    @element.appendChild document.createTextNode @toDateString @originalValue

  initControl: ->
    @control = @toDate()
    try
      @control.valueAsDate = new Date(@originalValue) if @originalValue
    catch error
      # save Safari from error

  formatValue: (newValue) ->
    if newValue.length > 0
      @toDateString(Date.parse(newValue))
    else if newValue instanceof Date
      @toDateString newValue
    else if newValue.length is 0
      try
        @control.valueAsDate = null
      catch error
        # save Safari from error
      ''

  setValue: (newValue) ->
    @source[@valueKey] = new Date(newValue)
    @setControlValue()

  setControlValue: ->
    try
      @control.valueAsDate = @source[@valueKey]
    catch error
      # save Safari from error

  renderValue: ->
    @element.textContent = @col.format(@toDateString @value())

  toDateString: (passedDate = null) ->
    if passedDate and passedDate isnt ''
      date = new Date(passedDate)
    else
      date = if @value() then new Date(@value()) else null
    if date instanceof Date
      if isNaN(date.getTime())
        ''
      else
        ('0' + (date.getUTCMonth() + 1)).slice(-2) + '-' + ('0' + date.getUTCDate()).slice(-2) + '-' + date.getUTCFullYear()

    else
      ''
  toDate: ->
    input = document.createElement 'input'
    input.type = 'date'
    input.value = @toDateString()
    input

  toDateInputString: (passedDate = null) ->
    if passedDate and passedDate isnt ''
      date = new Date(passedDate)
    else
      if @value() then date = new Date(@value()) else null
    if date instanceof Date
      date.getUTCFullYear() + '-' + ('0' + (date.getUTCMonth() + 1)).slice(-2) + '-' + ('0' + date.getUTCDate()).slice(-2)
    else
      ''

###
	HTML Cell
	-----------------------------------------------------------------------------------------
###

class GridEdit.HTMLCell extends GridEdit.Cell
  constructor: (value, @row) ->
    super
    @type = 'html'
    @initialize()
    @

  initNode: ->
    @htmlContent = @col.defaultValue || @originalValue || ''
    @element.appendChild @toFragment()

  setValue: (newValue) ->
    @htmlContent = newValue
    node = @toFragment()
    @element.innerHTML = ""
    @element.appendChild node

  toFragment: ->
    element = document.createElement "div"
    fragment = document.createDocumentFragment()
    element.innerHTML = @htmlContent
    fragment.appendChild(element.firstChild || document.createTextNode(''))
    fragment

  renderValue: ->
    @htmlContent

###
	Select Cell
	-----------------------------------------------------------------------------------------
###

class GridEdit.SelectCell extends GridEdit.Cell
  constructor: (value, @row) ->
    super
    @type = 'select'
    @initialize()
    @

  initNode: ->
    node = document.createTextNode @originalValue
    @element.appendChild node

  setControlValue: ->
    cell = @
    @control.innerHTML = '';
    for choice in @meta.choices
      option = document.createElement "option"
      if choice instanceof Array
        for subchoice, index in choice
          option.value = subchoice if index is 0
          option.text = subchoice if index is 1
      else
        option.value = option.text = choice
      option.selected = true if cell.value() is choice
      @control.add option

  initControl: ->
    cell = @
    select = document.createElement "select"
    @control = select
    console.log "There is not a 'choices' key in cell #{@address} and you specified that it was of type 'select'" if not @meta.choices
    @setControlValue()
    select.classList.add @table.theme.inputs.select.className
    select.onchange = (e) ->
      cell.edit e.target.value

  select: -> false

  onSpaceKeyPress: ->
    @renderControl()
    control = @control
    setTimeout(->
      event = document.createEvent('MouseEvents')
      event.initMouseEvent('mousedown', true, true, window)
      control.dispatchEvent(event)
    , 0)

  onKeyPress: (key) ->
    @onSpaceKeyPress()
    startsWith = new RegExp('^' + key, 'i')
    control = @control
    for option, i in control.options
      if startsWith.test(option.value)
        control.selectedIndex = i
        break

###
  TextArea Cell
  -----------------------------------------------------------------------------------------
###

class GridEdit.TextAreaCell extends GridEdit.Cell
  constructor: (value, @row) ->
    super
    @type = 'textarea'
    @initialize()
    @

  initNode: ->
    node = document.createTextNode @originalValue || ''
    @element.appendChild node

  initControl: ->
    cell = @
    textarea = document.createElement 'textarea'
    textarea.classList.add @table.theme.inputs.textarea.className
    @control = textarea

###
  Generic Cell
  -----------------------------------------------------------------------------------------

  Special cell class used by GridEdit for specialty rows and cells
###

class GridEdit.GenericCell extends GridEdit.Cell
  constructor: (value, @row) ->
    super
    @type = 'generic'
    @initialize()
    @

###
  Handle Cell
  -----------------------------------------------------------------------------------------

  Special cell class used by GridEdit to create row handles for moving rows
###

class GridEdit.HandleCell
  constructor: (@row) ->
    row = @row
    table = row.table
    @element = document.createElement 'td'
    @element.setAttribute "draggable", true
    @element.className = table.theme.cells.handleClassName
    node = document.createElement 'div'
    node.innerHTML = '<span></span><span></span><span></span>'
    @element.appendChild(node)

    @element.onclick = (e) ->
      index = row.index
      row.table.selectRow(e, index)

    @element.ondragstart = () ->
      GridEdit.Utilities::clearActiveCells(table)
      table.contextMenu.hideBorders()
      row.select()
      table.draggingRow = row

    @element.ondragend = () ->
      rowToMoveInex = table.draggingRow.index
      lastDragOverIndex = table.lastDragOver.index
      modifier = if lastDragOverIndex == 0 and !table.lastDragOverIsBeforeFirstRow then 1 else 0
      insertAtIndex = lastDragOverIndex + modifier

      table.lastDragOver.element.style.borderBottom = table.lastDragOver.oldBorderBottom
      table.lastDragOver.element.style.borderTop = table.lastDragOver.oldBorderTop
      table.lastDragOver.element.style.borderTop = table.lastDragOver.oldBorderTop
      table.lastDragOver = null

      table.moveRow(rowToMoveInex, insertAtIndex)

    @
