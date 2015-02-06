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
    @initUserHooks()
    @applyStyle()

  initOriginalValue: -> @originalValue = '' if @originalValue == undefined
  initSourceValue: -> @source[@valueKey] = @originalValue
  initEditable: -> @editable = @col.editable != false
  initValueKey: -> @valueKey = @col.valueKey
  initSource: -> @source = @table.config.rows[@address[0]]
  initNode: -> @element.appendChild document.createTextNode @col.format(@originalValue)

  initControl: ->
    @control = document.createElement 'input'

  ###
  	User Hooks
	  -----------------------------------------------------------------------------------------
  ###

  initUserHooks: ->
    @beforeEdit = @table.config.beforeEdit
    @afterEdit = @table.config.afterEdit
    @beforeActivate = @table.config.beforeCellActivate
    @afterActivate = @table.config.afterCellActivate
    @beforeControlInit = @table.config.beforeControlInit
    @afterControlInit = @table.config.afterControlInit
    @beforeControlHide = @table.config.beforeControlHide
    @afterControlHide = @table.config.afterControlHide
    @onClick = @table.config.onCellClick
    @beforeNavigateTo = @table.config.beforeCellNavigateTo

  userHook: (hookName) -> # all additional arguments are passed to user function
    if @[hookName]
      userArguments = []
      for arg, i in arguments
        continue if i == 0
        userArguments.push arg
      @[hookName].apply(userArguments)
    else
      true

  ###
  	Display
	  -----------------------------------------------------------------------------------------
  ###

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
    GridEdit.Utilities::clearActiveCells @table if clearActiveCells
    unless @isActive()
      if @userHook 'beforeActivate', @
        @showActive()
        @table.activeCells.push @
        @table.selectionStart = @
        @table.hideControl()
        openCell = @table.openCell
        openCell.edit openCell.control.value if openCell
        @userHook 'afterActivate', @

  makeInactive: -> @showInactive()

  showActive: ->
    unless @isActive()
      @oldBackgroundColor = @element.style.backgroundColor
      @element.style.backgroundColor = @table.cellStyles.activeColor

  showInactive: ->
    @element.style.backgroundColor = @oldBackgroundColor

  showUneditable: ->
    @element.style.backgroundColor = @table.cellStyles.uneditableColor
    @table.redCells.push @

  ###
  	Edit
	  -----------------------------------------------------------------------------------------
  ###

  edit: (value = null) ->
    if @editable
      if value isnt null
        @value value
        if @isBeingEdited() then @hideControl() else @edit()
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
      if @userHook 'beforeEdit', @, oldValue, newValue
        @table.addToStack { type: 'cell-edit', oldValue: oldValue, newValue: newValue, address: @address } if addToStack
        @setValue(newValue)
        @renderValue(newValue)
        @row.afterEdit()
        @userHook 'afterEdit', @, oldValue, newValue, @table.contextMenu.getTargetPasteCell()
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
  	Control
	  -----------------------------------------------------------------------------------------
  ###

  showControl: (value = null) ->
    if @userHook 'beforeControlInit', @
      @setControlValue(value)
      @table.contextMenu.hideBorders()
      @renderControl()
      @table.openCell = @
      @userHook 'afterControlInit', @

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
    if @userHook 'beforeControlHide', @
      @control.parentNode.removeChild(@control) if @isBeingEdited()
      @table.openCell = null
      @userHook 'afterControlHide', @

  applyControlBehavior: ->
    cell = @
    table = @table
    @control.onkeydown = (e) ->
      key = e.which
      switch key
        when 13 # return
          cell.edit @value
          cell.below()?.makeActive()
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
  previous: ->
    console.log('p')
    @row.cells[@index - 1] or @row.above()?.cells[@row.cells.length - 1]
  above: -> @row.above()?.cells[@index]
  below: -> @row.below()?.cells[@index]
  isBefore: (cell) -> cell.address[0] is @address[0] and cell.address[1] > @address[1]
  isAfter: (cell) -> cell.address[0] is @address[0] and cell.address[1] < @address[1]
  isAbove: (cell) -> cell.address[0] > @address[0] and cell.address[1] is @address[1]
  isBelow: (cell) -> cell.address[0] < @address[0] and cell.address[1] is @address[1]
  addClass: (newClass) -> @element.classList.add newClass
  removeClass: (classToRemove) -> @element.classList.remove classToRemove
  isBeingEdited: -> @control.parentNode?
  toggleActive: -> if @isActive() then @removeFromSelection() else @makeActive(false)

  isVisible: ->
    position = @position()
    (position.top >= @table.topOffset) and (position.bottom <= window.innerHeight)

  ###
  	Events
	  -----------------------------------------------------------------------------------------
  ###

  onReturnKeyPress: -> false
  onSpaceKeyPress: -> @edit()
  onKeyPress:(value) -> @showControl(value)

  applyEventBehavior: ->
    cell = @
    table = @table

    @element.onclick = (e) ->
      table.contextMenu.hideBorders()

      if table.lastClickCell == cell
        # double click event
        table.lastClickCell = null
        cell.edit()
      else
        table.lastClickCell = cell
        onClickReturnVal = if cell.col.onClick then cell.col.onClick(cell, e) else true
        if onClickReturnVal
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



    @element.onmousedown = (e) ->
      if e.which is 3 # right mouse button
        table.contextMenu.show(e.x, e.y, cell)
        return
      else
        unless e.shiftKey or e.ctrlKey or e.metaKey
          table.state = "selecting"
          cell.makeActive()

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

  formatValue: (newValue) ->
    Number(newValue)

  setValue: (newValue) ->
    @source[@valueKey] = Number(newValue)

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
    @initValueKey()
    @initSource()
    @initOriginalValue()
    @initSourceValue()
    @applyEventBehavior()
    @initUserHooks()
    @applyStyle()
    @initNode()

    @editable = false
    @renderValue()

  initNode: ->
    div = document.createElement 'div'
    div.style.width = '1em'
    div.style.margin = 'auto'
    @span = document.createElement 'span'
    div.appendChild @span
    @element.appendChild div

  edit: () -> false
  onReturnKeyPress: () -> @toggle()
  initControl: -> @toggle()
  renderControl: -> GridEdit.Utilities::clearActiveCells @table
  isBeingEdited: -> false

  toggle: ->
    @value(!@value())

  renderValue: ->
    @span.className = if @value() then 'glyphicon glyphicon-check' else 'glyphicon glyphicon-unchecked'

  applyEventBehavior: ->
    super

    cell = @
    @element.onclick = (e) ->
      cell.toggle()

  onSpaceKeyPress: ->
    @toggle()

###
	Date Cell
	-----------------------------------------------------------------------------------------
###

class GridEdit.DateCell extends GridEdit.Cell
  constructor: (value, @row) ->
    node = document.createTextNode @toDateString @originalValue
    @control = @toDate()
    @control.valueAsDate = new Date(@originalValue) if @originalValue
    @element.appendChild node

  formatValue: (newValue) ->
    if newValue.length > 0
      @toDateString(Date.parse(newValue))
    else if newValue instanceof Date
      @toDateString newValue
    else if newValue.length is 0
      @control.valueAsDate = null
      ''

  setValue: (newValue) ->
    @source[@valueKey] = new Date(newValue)
    @control.valueAsDate = new Date(newValue)

  initControl: ->
    super()
    @control.value = @toDateInputString(@value())

  value: ->
    @control.valueAsDate

  toDateString: (passedDate = null) ->
    if passedDate and passedDate isnt ''
      date = new Date(passedDate)
    else
      if @value() then date = new Date(@value()) else null
    if date instanceof Date
      ('0' + (date.getMonth() + 1)).slice(-2) + '-' + ('0' + date.getDate()).slice(-2) + '-' + date.getFullYear()
      # date.getFullYear() + '-' + ('0' + (date.getMonth()+1)).slice(-2) + '-' + ('0' + date.getDate()).slice(-2)
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
      date.getFullYear() + '-' + ('0' + (date.getMonth() + 1)).slice(-2) + '-' + ('0' + date.getDate()).slice(-2)
    else
      ''

###
	HTML Cell
	-----------------------------------------------------------------------------------------
###

class GridEdit.HTMLCell extends GridEdit.Cell
  constructor: (value, @row) ->
    @htmlContent = @col.defaultValue || @originalValue || ''
    node = @toFragment()
    @control = document.createElement 'input'
    @element.appendChild node

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

  render: ->
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

  initControl: ->
    cell = @
    select = document.createElement "select"
    console.log "There is not a 'choices' key in cell #{@address} and you specified that it was of type 'select'" if not @meta.choices
    for choice in @meta.choices
      option = document.createElement "option"
      if choice instanceof Array
        for subchoice, index in choice
          option.value = subchoice if index is 0
          option.text = subchoice if index is 1
      else
        option.value = option.text = choice
      option.selected = true if cell.value() is choice
      select.add option
    select.classList.add 'form-control'
    select.onchange = (e) ->
      cell.edit e.target.value
    @control = select

  select: -> false

  onSpaceKeyPress: ->
    @renderControl()
    control = @control
    setTimeout(->
      event = document.createEvent('MouseEvents');
      event.initMouseEvent('mousedown', true, true, window);
      control.dispatchEvent(event);
    , 0)

###
  TextArea Cell
  -----------------------------------------------------------------------------------------
###

class GridEdit.TextAreaCell extends GridEdit.Cell
  constructor: (value, @row) ->
    node = document.createTextNode @originalValue || ''
    @element.appendChild node
    @control = document.createElement 'textarea'
    @control.classList.add 'form-control'

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

#  initControl: -> @control.value = @value()
#  formatValue: (newValue) -> newValue
#  setValue: (newValue) -> @source[@valueKey] = newValue
#  render: -> @element.textContent
#  select: -> @control.select()

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
    @element.className = 'handle'
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
