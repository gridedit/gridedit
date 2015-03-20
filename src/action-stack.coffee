class GridEdit.ActionStack
  constructor: (@table) ->
    @userDefinedActions = {
      undo: {},
      redo: {}
    }
    @index = -1;
    @actions = [];

  getCell: (action) ->
    @table.getCell(action.address[0], action.address[1])

  addAction: (actionObject) ->
    if @actions.length > 0 and @index < @actions.length - 1
      @actions = @actions.splice(0, @index + 1)
    @actions.push(actionObject)
    @index++;

  addUndo: (actionName, f) ->
    @userDefinedActions.undo[actionName] = f

  addRedo: (actionName, f) ->
    @userDefinedActions.redo[actionName] = f

  undo: ->
    if @index > -1
      @index--
      action = @actions[@index + 1]
      switch action.type
        when 'cell-edit'
          cell = @getCell(action)
          cell.value(action.oldValue, false)
          break

        when 'cut'
          action.grid.undo(false, false)
          break

        when 'paste-pasteGrid'
          action.pasteGrid.undo(action.x, action.y)
          break

        when 'paste-copyGrid'
          action.grid.undo(action.x, action.y)
          break

        when 'fill'
          action.grid.undo(false, false)
          break

        when 'add-row'
          @table.removeRow(action.index, false)
          break

        when 'remove-row'
          @table.addRow(action.index, false, action.rowObject)
          break

        when 'move-row'
          @table.moveRow(action.newIndex, action.oldIndex, false)
          break

        when 'add-rows'
          rowIndexes = []
          for i in [0...action.rowObjects.length]
            rowIndexes.push(i + action.index)
          @table.removeRows(rowIndexes, false)
          break

        when 'remove-rows'
          @table.addScatteredRows(action.rowObjects)
          break

        when 'move-rows'
          @table.moveRows(action.modifiedNewIndex, action.modifiedRowToMoveIndex, action.numRows, false)
          break

        else
          @userDefinedActions.undo[action.type](action)

  redo: ->
    if(@index < @actions.length - 1)
      @index++
      action = @actions[@index]

      switch action.type
        when 'cell-edit'
          cell = @table.getCell(action.address[0], action.address[1])
          cell.value(action.newValue, false)
          break

        when 'cut'
          action.grid.apply(false, false)
          break

        when 'paste-pasteGrid'
          action.grid.applyTo(action.pasteGrid)
          break

        when 'paste-copyGrid'
          action.grid.apply(action.x, action.y)
          break

        when 'fill'
          action.grid.apply(false, false)
          break

        when 'add-row'
          @table.addRow(action.index, false, action.rowObject)
          break

        when 'remove-row'
          @table.removeRow(action.index, false)
          break

        when 'move-row'
          @table.moveRow(action.oldIndex, action.newIndex, false)
          break

        when 'add-rows'
          @table.addRows(action.index, false, action.rowObjects)
          break

        when 'remove-rows'
          @table.removeRows(action.rowIndexes, false)
          break

        when 'move-rows'
          @table.moveRows(action.originalRowToMoveIndex, action.originalNewIndex, action.numRows, false)
          break

        else
          @userDefinedActions.redo[action.type](action)
