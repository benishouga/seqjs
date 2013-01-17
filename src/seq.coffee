Util =
  measureTextHeight: ->
    unless @span
      @span = document.createElement("span")
      @span.textContent = "gM"
      @span.style.visibility = "hidden"
      @span.style.position = "absolute"
      body = document.body
      body.insertBefore @span, body.firstChild
    @span.offsetHeight / 2
  S4: ->
    (((1 + Math.random()) * 0x10000) | 0).toString(16).substring 1
  guid: ->
    S4 = @S4
    S4() + S4() + "-" + S4() + "-" + S4() + "-" + S4() + "-" + S4() + S4() + S4()
  trim: (text)->
    return text.replace(/^\s+|\s+$/g, "");

Config =
  margin: 8
  itemMargin: 20
  lineMinWidth: 64
  lineHeight: 32
  padding: 4
  executionWidth: 8
  arrowSize: 8
  curveWidth: 12
  fragmentMargin: 5
  textStyle: 'rgb(0, 0, 0)'
  strokeStyle: 'rgb(0, 0, 0)'
  fillStyle: 'rgb(255, 255, 255)'
  textFillStyle: 'rgba(255, 255, 255, 0.8)'

# --- View ---
class View
  constructor: ->
    @x = 0
    @y = 0
  draw: (context) ->
    context.save()
    @translate context
    @onDraw context
    @dispatchDraw context
    context.restore()
  translate: (context) ->
    context.translate @x, @y
  onDraw: (context) ->
  dispatchDraw: (context) ->

class ViewGroup extends View
  constructor: () ->
    super()
    @children = []
  dispatchDraw: (context) ->
    child.draw context for child in @children
  add: (child) -> @children.push child

class Diagram extends ViewGroup
  constructor: (@context) ->
    super()
  measureTextWidth: (text) ->
    @context.measureText(text).width
  show: ->
    @layout()
    @context.save()
    @context.translate 0.5, 0.5
    @draw @context
    @context.restore()
  layout: ->

class SequenceDiagram extends Diagram
  constructor: (context) ->
    super context
    @lines = []
    @items = []
    @fragmentStack = []
    @fragmentMaxStack = 0
    @x = Config.margin
    @y = Config.margin
    @bottom = 0
    @right = 0
  layout: ->
    @layoutLifeLines()
    @layoutItems()
  layoutLifeLines: ->
    right = 0
    for line in @lines
      line.layout right
      right += line.width + Config.margin
  layoutItems: ->
    bottom = Config.lineHeight
    for item in @items
      item.y = bottom + Config.itemMargin
      item.layout()
      bottom = item.bottom
    @bottom = bottom + Config.itemMargin
    lineMargin = @fragmentMaxStack * Config.fragmentMargin
    @shiftLifeLine lineMargin
    if @lines.length == 0
      return
    last = @lines[@lines.length - 1]
    @right = last.x + last.width + lineMargin
  addLine: (lifeLine) ->
    @lines.push lifeLine
    @add lifeLine
  addItem: (item) ->
    @items.push item
    @add item
  pushFragment: (fragment)->
    @fragmentStack.push fragment
    @fragmentMaxStack = Math.max @fragmentMaxStack, @fragmentStack.length
  popFragment: ->
    @fragmentStack.pop()
  shiftLifeLine: (shiftValue)->
    for line in @lines
      line.x += shiftValue

class LifeLine extends ViewGroup
  constructor: (@diagram, @name) ->
    super()
    @position = 0
    @stack = []
  measureWidth: ->
    @textWidth = @diagram.measureTextWidth @name
    @width = Math.max @textWidth + Config.padding * 2, Config.lineMinWidth
  onDraw: (context) ->
    context.strokeRect(-@width / 2, 0, @width, Config.lineHeight)
    context.fillText @name, - @textWidth / 2, Config.lineHeight / 2 + Util.measureTextHeight() / 2
    context.beginPath()
    context.moveTo 0, Config.lineHeight
    context.lineTo 0, @end or @diagram.bottom
    context.stroke()
  startExecution: (message) ->
    execution = new Execution @diagram, @stack.length
    execution.start = message
    @stack.push execution
    execution.parent = @
    @add execution
  endExecution: (message) ->
    execution = @stack.pop()
    execution.end = message
  currentExecution: ->
    if @stack.length == 0 then null else @stack[@stack.length - 1]
  layout: (current)->
    @measureWidth()
    @x = current + @width / 2

class Item extends ViewGroup
  layout: ->
    @bottom = @y
  getAbsoluteBottom: ->
    parent = if @parent? then @parent.getAbsoluteTop() else 0
    return @bottom + parent
  getAbsoluteTop: ->
    parent = if @parent? then @parent.getAbsoluteTop() else 0
    return @y + parent

class Message extends Item
  constructor: (@diagram, @text, @from, @to) ->
    super()
    @textWidth = @diagram.measureTextWidth @text
  onDraw: (context) ->
    from = @from.x
    to = @to.x
    from = from + @fromAdjust if @fromAdjust?
    to = to + @toAdjust if @toAdjust?
    if @from is @to
      @drawCurveArrow context, from, to
      @drawCurveText context, from
      return
    @toRight = from < to
    @drawArrow context, from, to
    @drawText context, from, to if @text?
  drawArrow: (context, from, to) ->
    arrowSize = Config.arrowSize
    wingTailX = to - arrowSize * (if @toRight then 1 else -1)
    wingTailY = arrowSize / 2
    context.beginPath()
    context.moveTo from, 0
    context.lineTo to, 0
    context.moveTo wingTailX, wingTailY
    context.lineTo to, 0
    context.lineTo wingTailX, -wingTailY
    context.stroke()
  drawCurveArrow: (context, from, to) ->
    arrowSize = Config.arrowSize
    wingTailX = to + arrowSize
    wingTailY = arrowSize / 2
    right = Math.min(from, to) + Config.curveWidth * 2
    context.beginPath()
    context.moveTo from, 0
    context.lineTo right, 0
    context.lineTo right, Config.curveWidth
    context.lineTo to, Config.curveWidth
    context.moveTo wingTailX, Config.curveWidth + wingTailY
    context.lineTo to, Config.curveWidth
    context.lineTo wingTailX, Config.curveWidth - wingTailY
    context.stroke()
  drawText: (context, from, to) ->
    base = if @toRight then from else to
    context.fillStyle = Config.textFillStyle
    textHeight = Util.measureTextHeight()
    context.fillRect base + Math.abs(to - from) / 2 - @textWidth / 2 - 2, -textHeight - 1, @textWidth + 3, textHeight
    context.fillStyle = Config.textStyle
    context.fillText @text, base + Math.abs(to - from) / 2 - @textWidth / 2, -3
  drawCurveText: (context, from) ->
    context.fillStyle = Config.textFillStyle
    textHeight = Util.measureTextHeight()
    context.fillRect from + 5, -textHeight - 1, @textWidth + 3, textHeight
    context.fillStyle = Config.textStyle
    context.fillText @text, from + 5, -3
  layout: ->
    @execution()
    @bottom = if @from is @to then @y + Config.curveWidth else @y
  execution: ->
    @adjustFrom()
    @adjustTo()
  adjustFrom: ->
    if @from is @to
      @fromAdjust = @from.currentExecution()?.right()
      return
    from = @from.x
    to = @to.x
    if 0 < to - from
      @fromAdjust = @from.currentExecution()?.right()
    else
      @fromAdjust = @from.currentExecution()?.left()
  adjustTo: ->
    if @from is @to
      @toAdjust = @from.currentExecution()?.right()
      return
    from = @from.x
    to = @to.x
    if 0 < to - from
      @toAdjust = @to.currentExecution()?.left()
    else
      @toAdjust = @to.currentExecution()?.right()

class SyncMessage extends Message
  constructor: (diagram, text, from, to) ->
    super(diagram, text, from, to)
  execution: ->
    @adjustFrom()
    @to.startExecution(@)
    @adjustTo()

class ReplyMessage extends Message
  constructor: (diagram, text, from, to) ->
    super(diagram, text, from, to)
  execution: ->
    @adjustFrom()
    @from.endExecution(@)
    @adjustTo()

class Execution extends View
  constructor: (@diagram, @overlap) ->
    super()
    @start = null
    @end = null
  onDraw: (context) ->
    context.strokeStyle = Config.strokeStyle
    context.fillStyle = Config.fillStyle
    context.beginPath()
    left = -Config.executionWidth / 2 + Config.executionWidth * @overlap
    end = @end?.getAbsoluteTop() or @diagram.bottom
    context.rect left, @start.getAbsoluteBottom(), Config.executionWidth, end - @start.getAbsoluteBottom()
    context.fill()
    context.stroke()
  left: ->
    -Config.executionWidth / 2 + Config.executionWidth * @overlap
  right: ->
    Config.executionWidth / 2 + Config.executionWidth * @overlap

class ExecutionStart extends Item
  constructor: (@target)->
    super()
  layout: ->
    super()
    @execution()
  execution: ->
    @target.startExecution(@)

class ExecutionEnd extends Item
  constructor: (@target)->
    super()
  layout: ->
    super()
    @execution()
  execution: ->
    @target.endExecution(@)

class Note extends Item
  constructor: (@diagram, @text, @target, @isLeft)->
    super()
    @textWidth = @diagram.measureTextWidth @text
    @adjustPosition = 0
  onDraw: (context) ->
    textHeight = Util.measureTextHeight()
    textBoxWidth = @textWidth + Config.padding * 2
    textBoxHeight = textHeight + Config.padding * 2
    if @isLeft
      left = @target.x - @adjustPosition - textBoxWidth - Config.padding
    else
      left = @target.x + @adjustPosition + Config.padding
    context.strokeStyle = Config.strokeStyle
    context.fillStyle = Config.textFillStyle
    context.beginPath()
    context.rect left, 0, textBoxWidth, textBoxHeight
    context.fill()
    context.stroke()
    context.fillStyle = Config.textStyle
    context.fillText @text, left + Config.padding, textHeight + Config.padding
  adjust: ->
    if @isLeft
      @adjustPosition += Config.executionWidth / 2 if @target.currentExecution()
    else
      current = @target.currentExecution()
      @adjustPosition = current.right() if current
  layout: ->
    @adjust()
    @bottom = @y + Util.measureTextHeight() + Config.padding * 2

class Alt extends Item
  constructor: (@diagram, @text) ->
    super()
    @textWidth = @diagram.measureTextWidth @text
    @textBoxWidth = @textWidth + Config.padding * 2
  layout: ->
    current = 0
    @margin = @diagram.fragmentStack.length * Config.fragmentMargin
    @diagram.pushFragment @
    for item in @children
      item.y = current
      item.layout()
      current = item.bottom;
    @diagram.popFragment()
    @bottom = @y + current
  onDraw: (context) ->
    context.strokeStyle = Config.strokeStyle
    context.fillStyle = Config.textFillStyle
    textHeight = Util.measureTextHeight()
    context.beginPath()
    context.rect @margin, 0, @textBoxWidth, textHeight + Config.padding
    context.fill()
    context.stroke()
    context.fillStyle = Config.textStyle
    context.fillText @text, @margin + Config.padding, textHeight + Config.padding / 2
  addItem: (item) ->
    item.parent = @
    @add item

class FragmentBase extends Item
  constructor: (@diagram, @text) ->
    super()
  layout: ->
    bottom = Config.itemMargin
    for item in @children
      item.y = bottom + Config.itemMargin
      item.layout()
      bottom = item.bottom
    @bottom = @y + bottom + Config.itemMargin
  onDraw: (context)->
    context.strokeStyle = Config.strokeStyle
    context.beginPath()
    context.rect @margin, 0, @diagram.right - @margin * 2, @bottom - @y
    context.stroke()
  addItem: (item)->
    item.parent = @
    @add item

class Guard extends FragmentBase
  constructor: (diagram, text) ->
    super diagram, '[ ' + text + ' ]'
    @textWidth = @diagram.measureTextWidth @text
  onDraw: (context)->
    @margin = @parent.margin
    super context
    context.fillStyle = Config.textFillStyle
    textHeight = Util.measureTextHeight()
    context.fillRect @margin + @parent.textBoxWidth + Config.padding, 1, @textWidth + Config.padding, textHeight + Config.padding
    context.fillStyle = Config.textStyle
    context.fillText @text, @margin + @parent.textBoxWidth + Config.padding * 2, textHeight + Config.padding / 2

class Fragment extends FragmentBase
  constructor: (diagram, text) ->
    super diagram, text
    @textWidth = @diagram.measureTextWidth @text
    @textBoxWidth = @textWidth + Config.padding * 2
  layout: ->
    @margin = @diagram.fragmentStack.length * Config.fragmentMargin
    @diagram.pushFragment @
    super()
    @diagram.popFragment()
  onDraw: (context) ->
    super context
    context.strokeStyle = Config.strokeStyle
    context.fillStyle = Config.textFillStyle
    textHeight = Util.measureTextHeight()
    context.beginPath()
    context.rect @margin, 0, @textBoxWidth, textHeight + Config.padding
    context.fill()
    context.stroke()
    context.fillStyle = Config.textStyle
    context.fillText @text, @margin + Config.padding, textHeight + Config.padding / 2


# --- Parser ---

class SequenceCommandParser
  constructor: (context) ->
    @diagram = new SequenceDiagram context
    @factory = new CommandFactory();
  parse: (text)->
    cmdTexts = text.split '\n'
    state = new State(@factory, @diagram, cmdTexts)
    while state.hasNext()
      cmdText = state.next()
      cmd = @factory.create cmdText
      if cmd
        cmd.setup cmdText
        cmd.execute state
    return @diagram

class State
  constructor: (@factory, @diagram, @cmdTexts)->
    @index = 0
    @stack = []
    @lines = {}
  hasNext: ->
    @index < @cmdTexts.length
  next: ->
    if @index < @cmdTexts.length
      cmdText = @cmdTexts[@index]
      @index++
      return cmdText
  line: (name)->
    line = @lines[name]
    if line
      return line
    line = new LifeLine @diagram, name
    @lines[name] = line
    @diagram.addLine line
    return line
  current: ->
    if @stack.length == 0
      return @diagram
    return @stack[@stack.length - 1]

class CommandFactory
  constructor: ->
    @cmds = []
    @cmds.push new AltCommand
    @cmds.push new OptionCommand
    @cmds.push new ElseCommand
    @cmds.push new EndCommand
    @cmds.push new NoteCommand
    @cmds.push new MessageCommand
    @cmds.push new ExecutionCommand
  create: (cmdText)->
    for cmd in @cmds
      if cmd.match cmdText
        return cmd

class Command
  setup: (text)->
    result = @match text
    for value, index in result
      value = value.trim() if value
      @[@names[index - 1]] = value if 0 < index
  match: (text)-> text.match(@reg)

class MessageCommand extends Command
  reg : /^\s*?([^\]>-]+)(\])?->([^\[:]+)(\[)?(?::(.*))?$/
  names: ["fromName", "isReply", "toName", "isSync", "text"]
  execute: (state) ->
    from = state.line(@fromName)
    to = state.line(@toName)
    if @isReply
      message = new ReplyMessage(state.diagram, @text, from, to)
    else if @isSync
      message = new SyncMessage(state.diagram, @text, from, to)
    else
      message = new Message(state.diagram, @text, from, to)
    state.current().addItem message

class NoteCommand extends Command
  reg: /^\s*(left|right|note|comment)@([^\:]+):(.*)$/i
  names: ["position", "lineName", "text"]
  execute: (state) ->
    state.current().addItem(new Note(state.diagram, @text, state.line(@lineName), @position is "left"));

class ExecutionCommand extends Command
  reg: /^([^\[\]]+)(\[|\])$/
  names: ["lineName", "last"]
  execute: (state)->
    if @last is '['
      item = new ExecutionStart state.line(@lineName)
    else
      item = new ExecutionEnd state.line(@lineName)
    state.current().addItem item

class OptionCommand extends Command
  reg: /^\s*(assert|break|consider|critical|ignore|loop|neg|opt|par|seq|strict)(?::(.*))?$/i
  names: ["type", "text"]
  execute: (state)->
    if @text
      frag = new Fragment state.diagram, @type + " [" + @text + "]"
    else
      frag = new Fragment state.diagram, @type
    state.current().addItem frag
    state.stack.push frag

class EndCommand extends Command
  reg: /^\s*end\s*$/i
  names: []
  execute: (state)->
    state.stack.pop()

class AltCommand extends Command
  reg: /^\s*alt(?:\:(.*))?$/i
  names: ["text"]
  execute: (state)->
    alt = new Alt state.diagram, "alt"
    state.current().addItem alt
    guard = new Guard state.diagram, @text
    state.stack.push guard
    alt.addItem guard

class ElseCommand extends Command
  reg: /^\s*else(?:\:(.*))?$/i
  names: ["text"]
  execute: (state)->
    guard = new Guard state.diagram, @text
    state.current().parent.addItem guard
    state.stack.pop()
    state.stack.push guard
