# GridEdit
GridEdit is a simple & lightweight vanilla javascript library for creating a tablet friendly editable grid.
#### This product is currently in BETA and is being actively developed
# Installation
<pre>bower install gridedit --save</pre>
# Usage
Create a 'div' element with either an id of 'gridedit', or the value passed into the 'element' key of the configuration.
``` html
<!-- default -->
<div id='gridedit'></div>

<!-- optional -->
<div id='yourElementId'></div>
```
Set the configuration to be passed into the GridEdit constructor.
``` javascript
var gridEditConfig = {
  // configuration options
}
```
Instantiate an object of the GridEdit class.
``` javascript
gridEdit = new GridEdit(gridEditConfig);
```
#### Configuration Options
###### cols
An array of column objects that control column display.

A column object can have the following options:
* *label*
The column header text.

* *type*
The cell type of column. Determines the input type used to edit cells in the column.
Available types are: 'string', 'number', 'date', 'html', and 'select'

* *valueKey*
The key to lookup on each row which holds the value for this column.

* *editable*
Boolean determining whether or not cells in this column can be edited.

* *cellClass*
The class that will be given to the cells in this column.

* *format*
A function callback for formatting the cell contents.
Function is called with one parameter, 'value'.
``` javascript
// prepend a '$' to the value before display
format: function(value){
   return '$' + value;
}
```

###### rows
An array of objects containing values to populate the grid.
###### tableClass
The class to be applied to the GridEdit table.
###### initialize
Whether or not to initialize GridEdit when calling the constructor.
Note: Set this to true.
###### selectionBorderStyle
A CSS border style in string format to determine the border style of selected cells while performing actions such as 'cut', 'copy', and 'paste'
###### contextMenuItems
An object of contextMenuItemName key to contextMenuItem objects allowing custom context menu and keyboard shortcut actions.  Also allows overriding the default context menu items.

A contextMenuItem object can have the following options:
* *name*
The name to be displayed in the context menu.

* *shortCut*
The keyboard shortcut to register with this action.  Currently supports variations of cmd + key or ctrl + key ( uppercase ).
``` javascript
shortCut: 'ctrl+B'
```

* *callback*
The function to perform upon selecting the context menu item or using the keyboard short cut.
Function is called with two paremeters; 'the javascript event' and 'the GridEdit object'
``` javascript
callback: function(event, gridEdit){
   console.log('called from contextMenu');
}
```

###### contextMenuOrder
An array of contextMenuItem keys determining the display order of the context menu.
``` javascript
contextMenuOrder: [ 'cut', 'paste', 'insertAbove' ]
```
*Note: If this option is supplied, only the menu items listed in the array will display in the context menu.*
##### Default Context Menu Items
The code block below shows the default context menu items, their corresponding keys, and keyboard shortcuts.
``` coffeescript
@defaultActions = {
  cut: {
    name: 'Cut',
    shortCut: ctrlOrCmd + '+X',
    callback: @cut
  },
  copy: {
    name: 'Copy',
    shortCut: ctrlOrCmd + '+C',
    callback: @copy
  },
  paste: {
    name: 'Paste',
    shortCut: ctrlOrCmd + '+V',
    callback: @paste
  },
  undo: {
    name: 'Undo',
    shortCut: ctrlOrCmd + '+Z',
    callback: @undo
  },
  redo: {
    name: 'Redo',
    shortCut: ctrlOrCmd + '+Y',
    callback: @redo
  },
  fill: {
    name: 'Fill',
    shortCut: '',
    hasDivider: true,
    callback: @fill
  },
  selectAll: {
    name: 'Select All',
    shortCut: ctrlOrCmd + '+A',
    callback: @selectAll
  },
  insertBelow: {
    name: 'Insert Row Below',
    shortCut: '',
    callback: @insertBelow
  },
  insertAbove: {
    name: 'Insert Row Above',
    shortCut: '',
    callback: @insertAbove
  }
}
```
#Contributing

1. Fork it!
2. Create your feature branch: git checkout -b my-new-feature
3. Commit your changes: git commit -am 'Add some feature'
4. Push to the branch: git push origin my-new-feature
5. Submit a pull request :D





