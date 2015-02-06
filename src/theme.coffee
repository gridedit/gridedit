class GridEdit.Theme
  constructor: (@themeName, customTheme) ->

    switch @themeName
      when 'bootstrap'
        @apply @bootstrap
        break
      else
        @themeName = 'default'
        @apply @default
        break

    if customTheme
      @themeName = "#{@themeName}-custom"
      @apply customTheme

  apply: (theme) ->
    self = @
    apply = (target, obj) ->
      for k, v of obj
        if typeof v == 'object'
          target[k] = {} unless target[k]
          apply target[k], v
        else
          target[k] = v

    for k, v of theme
      if typeof v == 'object'
        self[k] = {} unless self[k]
        apply self[k], v
      else
        self[k] = v

  default: {
    bootstrap: false,
    cells: {
      activeColor: "#FFE16F",
      uneditableColor: "#FFBBB3",
      handleClassName: 'handle',
      selectionBorderStyle: '2px dashed blue'
    },
    borders: {
      dragBorderStyle: '3px solid rgb(160, 195, 240)',
    },
    inputs: {
      textarea: {
        className: 'grid-edit'
      },
      select: {
        className: 'grid-edit'
      },
      checkbox: {
        checkedClassName: false,
        uncheckedClassName: false
      }
    }
  }

  bootstrap: {
    bootstrap: true,
    cells: {
      activeColor: "#FFE16F",
      uneditableColor: "#FFBBB3",
      handleClassName: 'handle',
      selectionBorderStyle: '2px dashed blue'
    },
    borders: {
      dragBorderStyle: '3px solid rgb(160, 195, 240)',
    },
    inputs: {
      textarea: 'form-control'
      select: {
        className: 'form-control'
      },
      checkbox: {
        checkedClassName: 'glyphicon glyphicon-check',
        uncheckedClassName: 'glyphicon glyphicon-unchecked'
      }
    }
  }

