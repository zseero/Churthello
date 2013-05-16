#packaging:
#ocra --windows --chdir-first churthello.rb lib/*
######################################################################################################
#download:
#https://www.dropbox.com/s/x26ba8igkk2komj/StuartsGameOfLife.exe

require 'rubygems'
require 'gosu'

module Layers
  Background, Hexagon, Text, Box, Text2 = *0...5
end

class Vector
  attr_accessor :x, :y
  def initialize(x, y); @x, @y = x, y; end
  def +(v); Vector.new(@x + v.x, @y + v.y); end
  def -(v); Vector.new(@x - v.x, @y - v.y); end
  def *(v); Vector.new(@x * v.x, @y * v.y); end
  def /(v); Vector.new(@x / v.x, @y / v.y); end
  def %(v); Vector.new(@x % v.x, @y % v.y); end
  def ==(v); (@x == v.x && @y == v.y); end
  def dup; Vector.new(@x, @y); end
end

class Pos
  attr_accessor :row, :column
  def initialize(row, column); @row, @column = row, column; end
  def ==(p); (@row == p.row && @column == p.column); end
  def dup; Pos.new(@row, @column); end
end

class Window < Gosu::Window
  attr_reader :screen_size, :world_size, :fontSize, :fontSize2
  attr_accessor :board, :hexImg, :font, :font2
  def initialize
    boardWidth = 64
    @world_size = Vector.new(9, 13)
    @screen_size = Vector.new((@world_size.x + 2.35) * (boardWidth * 0.75),
                             ((@world_size.y + 1) / 2.0 * boardWidth) -
                             ((@world_size.y + 1) / 2.0 * (0.5773502692 * (boardWidth.to_f / 4.0))))
    super(@screen_size.x.to_i, @screen_size.y.to_i, false)
    self.caption = "Churthello           Press ENTER to pass"
    @hexImg = Gosu::Image.new(self, 'lib/hex.png', false)
    @fontSize = (boardWidth * 0.75).round
    @font = Gosu::Font.new(self, Gosu::default_font_name, @fontSize)
    @fontSize2 = 24
    @font2 = Gosu::Font.new(self, Gosu::default_font_name, @fontSize2)
    makeBoard(boardWidth)
  end

  def makeBoard(boardWidth)
    @board = Board.new(self, @world_size, boardWidth)
  end

  def update
    @board.update
  end

  def draw
    @board.draw
  end

  def needs_cursor?
    true
  end

  def button_down(id)
    if id == Gosu::KbReturn
      @board.pIndex += 1
      @board.pIndex %= @board.players.length
    end
  end
end

class Board
  attr_reader :width
  attr_accessor :window, :scores, :players, :pIndex, :world, :animating
  def initialize(window, world_size, width)
    @window, @world_size = window, world_size
    @width = width
    createWorld
    @players = [:r, :y, :b]
    @pIndex = 0
    createScoreBoard
    @animating = false
  end

  def createWorld
    @world = []
    for rowI in 0...@world_size.y
      row = []
      rowEvenOdd = rowI % 2
      for columnI in 0...@world_size.x
        columnEvenOdd = columnI % 2
          bool = rowI.even? &&
          ((rowI / 4.0 == rowI / 4 && (columnI + 2) / 4.0 == (columnI + 2) / 4) ||
          ((rowI + 2) / 4.0 == (rowI + 2) / 4 && (columnI) / 4.0 == (columnI) / 4))
        if rowEvenOdd == columnEvenOdd && !bool
          row << Hex.new(self, Pos.new(rowI, columnI))
        else
          row << nil
        end
      end
      @world << row
    end
    halfRow = (@world_size.y / 2.0).to_i
    halfColumn = (@world_size.x / 2.0).to_i
    @world[halfRow - 2][halfColumn].color.add(:r)
    @world[halfRow - 1][halfColumn - 1].color.add(:y)
    @world[halfRow + 1][halfColumn - 1].color.add(:b)
    @world[halfRow + 2][halfColumn].color.add(:r)
    @world[halfRow + 1][halfColumn + 1].color.add(:y)
    @world[halfRow - 1][halfColumn + 1].color.add(:b)
  end

  def createScoreBoard
    @scores = {}
    @scoreHexs = {}
    @players.each {|p| @scores[p] = 0}
    i = 0
    @players.each { |p|
      @scoreHexs[p] = Hex.new(self, Pos.new(i * 2 + (@window.world_size.y / 2) - 2, -2))
      @scoreHexs[p].color.add(p)
      i += 1
    }
  end

  def drawScores
    @players.each { |p|
      score = @scores[p]
      hex = @scoreHexs[p]
      width = @window.font.text_width(score.to_s)
      c = 0xff000000
      c = 0xffffffff if @players[@pIndex] == p
      @window.font.draw(score.to_s, hex.centerPos.x - (width / 2.0),
                        hex.centerPos.y - (@window.fontSize / 2.0),
                        Layers::Text, 1, 1, c)
    }
  end

  def update
    click = @window.button_down?(Gosu::MsLeft)
    bool = @clicked && !click
    @clicked = click
    closest = nil
    @emptyCount = 0
    @players.each {|p| @scores[p] = 0}
    for row in @world
      for hex in row
        if hex
          hex.update
          @emptyCount += 1 if hex.color.empty?
          @players.each {|p| @scores[p] += 1 if hex.color.genes.include?(p)}
          if bool
            closest = hex if closest.nil? ||
              Gosu::distance(hex.centerPos.x, hex.centerPos.y, @window.mouse_x, @window.mouse_y) <
              Gosu::distance(closest.centerPos.x, closest.centerPos.y, @window.mouse_x, @window.mouse_y)
          end
        end
      end
    end
    if bool && !@animating && !@gameOver
      success = closest.click(@players[@pIndex])
      @pIndex += 1 if success
      @pIndex %= @players.length
    end
    @scoreHexs.each_value {|hex| hex.update}
    if @emptyCount == 0 && !@gameOver
      @gameOver = true
      @gameOverTimer = 0
    end
    @gameOverTimer += 1 if !@gameOverTimer.nil?
  end

  def outputScores
    names = {:r => 'Red', :y => 'Yellow', :b => 'Blue'}
    max = nil
    @players.each {|p| max = p if max.nil? || @scores[p] >= @scores[max]}
    text = names[max] + " is the winner!"
    width = @window.font2.text_width(text)
    halfWidth = width / 2
    halfHeight = @window.fontSize2 / 2
    drawCoord = Vector.new(@window.screen_size.x / 2 - halfWidth, @window.screen_size.y / 2 - halfHeight)
    c = 0xff000000
    buffer = 7
    @window.draw_quad(drawCoord.x - buffer, drawCoord.y - buffer, c,
                      drawCoord.x + width + buffer, drawCoord.y - buffer, c,
                      drawCoord.x + width + buffer, drawCoord.y + @window.fontSize2 + buffer, c,
                      drawCoord.x - buffer, drawCoord.y + @window.fontSize2 + buffer, c,
                      Layers::Box)
    c = @scoreHexs[max].color.color
    buffer = 5
    @window.draw_quad(drawCoord.x - buffer, drawCoord.y - buffer, c,
                      drawCoord.x + width + buffer, drawCoord.y - buffer, c,
                      drawCoord.x + width + buffer, drawCoord.y + @window.fontSize2 + buffer, c,
                      drawCoord.x - buffer, drawCoord.y + @window.fontSize2 + buffer, c,
                      Layers::Box)
    @window.font2.draw(text, drawCoord.x, drawCoord.y, Layers::Text2, 1, 1, 0xff000000)
  end

  def draw
    for row in @world
      for hex in row
        hex.draw if hex
      end
    end
    @scoreHexs.each_value {|hex| hex.draw}
    drawScores
    if @gameOverTimer && @gameOverTimer > 120
      outputScores
    end
  end
end

class Hex
  attr_reader :centerPos, :drawPos
  attr_accessor :color, :sizeMult
  def initialize(board, pos)
    @board, @pos = board, pos
    @img = @board.window.hexImg
    @color = Color.new
    @count = 0
    configure
    @stage = :idle
    @sizeMult = 1.0
    @otherSizeMult = 1.0
  end

  def configure
    @width = @board.width
    @circleSpace = 0.5773502692 * (@width.to_f / 4.0)
    @imgSizeMult = @width.to_f / @img.width.to_f
    @oDrawPos = Vector.new((@pos.column + 2) * (@width * 0.75),
                (@pos.row / 2.0 * @width) - (@pos.row / 2.0 * @circleSpace) - (@circleSpace / 2))
    @centerPos = @oDrawPos + Vector.new(@width / 2, @width / 2)
    @drawPos = @oDrawPos.dup
  end

  def click(c)
    return false if !(@color.genes.include?(c) && @color.hetero? || @color.empty?)
    dirs=[Pos.new(2, 0), Pos.new(-2, 0), Pos.new(1, 1), Pos.new(-1, -1), Pos.new(1, -1), Pos.new(-1, 1)]
    direction = nil
    paths = []
    foundNeighbor = false
    for dir in dirs
      p = @pos.dup
      path = []
      sPath = nil
      p.row += dir.row; p.column += dir.column
      for i in 0...1000
        row = @board.world[p.row]
        hex = row[p.column] if row
        break if !hex
        break if p.row < 0 || p.column < 0
        break if hex.color.empty?
        if !hex.color.genes.include?(c)
          path << hex
          foundNeighbor = true
        elsif hex.color.hetero? && hex.color.genes.include?(c)
          path << hex
          sPath = path.dup if path.length > 1
          foundNeighbor = true
        elsif hex.color.homo? && hex.color.genes.include?(c)
          path << hex
          sPath = path.dup if path.length > 1
          break
        end
        p.row += dir.row; p.column += dir.column
      end
      paths << sPath if sPath
    end
    if paths.length == 0 && @board.scores[@board.players[@board.pIndex]] > 0 || !foundNeighbor
      return false
    end
    @board.animating = true
    @stage = :shrinkEnds
    @paths = paths
    @newColor = c
    true
  end

  def update
    sizeChanger = 0.05
    if @stage == :shrinkEnds
      @sizeMult -= sizeChanger
      @paths.each {|path| path[-1].sizeMult = @sizeMult}
      if @sizeMult <= 0
        @stage = :growEnds
        @sizeMult = 0.0
        @paths.each {|path| path[-1].sizeMult = @sizeMult}
        @color.add(@newColor)
        @paths.each {|path| path[-1].color.add(@newColor)}
      end
    end
    if @stage == :growEnds
      @sizeMult += sizeChanger
      @paths.each {|path| path[-1].sizeMult = @sizeMult}
      if @sizeMult >= 1
        @stage = :shrinkMiddle
        @sizeMult = 1.0
        @paths.each {|path| path[-1].sizeMult = @sizeMult}
      end
    end
    if @stage == :shrinkMiddle
      @otherSizeMult -= sizeChanger
      @paths.each {|path| path[0..-2].each {|hex| hex.sizeMult = @otherSizeMult}}
      if @otherSizeMult <= 0
        @stage = :growMiddle
        @otherSizeMult = 0.0
        @paths.each {|path| path[0..-2].each {|hex| hex.sizeMult = @otherSizeMult}}
        @color.add(@newColor)
        @paths.each {|path| path[0..-2].each {|hex| hex.color.add(@newColor)}}
      end
    end
    if @stage == :growMiddle
      @otherSizeMult += sizeChanger
      @paths.each {|path| path[0..-2].each {|hex| hex.sizeMult = @otherSizeMult}}
      if @otherSizeMult >= 1
        @stage = :idle
        @otherSizeMult = 1.0
        @paths.each {|path| path[0..-2].each {|hex| hex.sizeMult = @otherSizeMult}}
        @board.animating = false
      end
    end
    @drawPos = @centerPos - Vector.new(@width * @sizeMult / 2, @width * @sizeMult / 2)
  end

  def draw
    @img.draw(@drawPos.x, @drawPos.y, Layers::Hexagon,
      @imgSizeMult * @sizeMult, @imgSizeMult * @sizeMult, @color.color)
  end
end

class Color
  attr_reader :colorGenes

  def initialize
    @reference = {
      []       => 0xffffffff,#white
      [:r, :r].sort => 0xffff0000,#red
      [:r, :y].sort => 0xffff8800,#orange
      [:y, :y].sort => 0xffffff00,#yellow
      [:y, :b].sort => 0xff00ff00,#green
      [:b, :b].sort => 0xff0088ff,#blue
      [:b, :r].sort => 0xffff00ff #purple
    }
    @colorGenes = []
  end

  def add(sym)
    if @colorGenes.length > 0 && !@colorGenes.include?(sym)
      @colorGenes << sym
      @colorGenes.delete_at(0)
    else
      @colorGenes = [sym, sym]
    end
  end

  def empty?; @colorGenes.length == 0; end
  def hetero?; @colorGenes[0] != @colorGenes[1]; end
  def homo?; @colorGenes[0] == @colorGenes[1]; end
  def genes; @colorGenes; end
  def color; @reference[@colorGenes.sort]; end
  def to_s; @colorGenes.join(', '); end
end

window = Window.new
window.show