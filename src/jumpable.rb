# intermediate language HexJumpable
#   program: block*
#   block: label:start commands* (label:end | label:end_positive label:end_zero_or_negative)
#
# label name starting with '@' is reserved.
# @main0, ..., and @main5 are the entry point of IPs. They cannot be used as a end label.
# @exit is the termination label; the program stops when an IP reaches it.
# The start label of a block cannot be used as a end label of the same block.

class HexJumpable
  class Command
    CHARS = {
      nop: '.',
      exit: '@',
      quit: '@',
      inc: ')',
      dec: '(',
      add: '+',
      plus: '+',
      sub: '-',
      minus: '-',
      mul: '*',
      div: ':',
      mod: '%',
      neg: '~',
      negate: '~',
      getb: ',',
      getbyte: ',',
      geti: '?',
      putb: ';',
      putbyte: ';',
      puti: '!',
      left: '{',
      right: '}',
      back_left: '"',
      back_right: '\'',
      rev: '=',
      reverse: '=',
      dup: '&',
      dec_ip: '[',
      array_get: '[',
      inc_ip: ']',
      array_set: ']',
      **('0'..'9').map{|x| [x.to_sym, x] }.to_h,
    }.tap{|h| h.default_proc = ->(h, k){
      h[k] = $1 if k =~ /\Achar_(.)\z/ && !h.values.include?($1)
    } }

    attr :name, :char

    def initialize name
      @name = name.to_sym
      @char = CHARS[@name] || raise(KeyError, "key not found: #@name")
    end

    def to_s
      @char.to_s
    end

    def inspect
      "#@name(#{@char.inspect})"
    end
  end

  class Block
    attr :l_start, :commands, :l_end, :l_end_pos, :l_end_neg

    def initialize l_start, commands, l_end, l_end_neg = nil
      if [l_end, l_end_neg].include? l_start
        raise "the start label #{l_start} cannot be used as a end label of the same block"
      end

      @l_start, @commands = l_start, commands
      if l_end_neg
        @l_end_pos, @l_end_neg = l_end, l_end_neg
      else
        @l_end = l_end
      end
    end

    def to_s
      [@l_start, @commands.join, @l_end, @l_end_pos, @l_end_neg].join(' ')
    end

    def inspect
      "#{"#@l_start: ".ljust(25)}#{ @commands.join.ljust(45) } -> #{ @l_end || "#@l_end_pos / #@l_end_neg" }"
    end
  end

  attr :program

  # program: Array<HexJumpable::Block>
  def initialize program
    @program = program.freeze
  end

  def to_s
    @program.join "\n"
  end

  def inspect
    "#<HexJumpable\n" + @program.map{|b| "  #{b.inspect}\n" }.join + ">"
  end
end
