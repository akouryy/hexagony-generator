require './hex_common.rb'

# language HexHappy
# register: i | x | t
# array: a
# immediate: -?\d+ | '.+'
# unary: ++ | -- | -@
# binary: + | - | * | / | %
#
# (initialy all registers and elements of arrays are 0.)
#
# mnemonic:
#   t = geti
#   t = getb
#   puti t
#   putb t
#   txi = IMM
#   txi UNA
#   t = xi
#   xi = t
#   xi BIN= t
#   swap t, xi
#   swap xi, t
#   t = a[IMM]
#   t = a[i]
#   a[IMM] = t
#   a[i] = t
#   ! LAB
#   t ? +LAB_t_pos -LAB_t_zeroneg (REG > 0)
#
# program: (LAB: mnemonic* (ends with jump or xjump))*
# entry label: @main0
# exit label: @exit
module HexHappy
  module_function

  def exec code
  end

  private def debug s
    $stderr.puts "[HexHappy] #{s}" if $hex_debug
  end

  LAB = /@? \w++/x
  IMM = /[+-]?+[0-9]++ | '..?' | "..?"/x
  UNA = /\+\+ | -- | -@/x
  BIN = /[-+*\/%]/x

  def exec code
    code = parse code unless code.is_a? Hash
    now_label = :@main0
    arrs = { a: [] }
    regs = { i: 0, t: 0, x: 0 }
    get = ->((type, a, b)){
      case type
      when :reg; regs[a.to_sym]
      when :imm; a
      when :arr; arrs[a.to_sym][get.(b)] ||= 0
      else raise "cannot get #{type}, #{a}, #{b}"
      end
    }
    set = ->((type, a, b), val){
      case type
      when :reg; regs[a.to_sym] = val
      when :imm; a = val
      when :arr; arrs[a.to_sym][get.(b)] = val
      else raise "cannot get #{type}, #{a}, #{b}"
      end
    }

    while now_label != :@exit
      debug now_label
      code[now_label].each do |l|
        debug "#{l}        (#{regs})"
        cmd, a, b, c = l
        case cmd.to_sym
        when :geti
          set.(a, HexCommon.geti)
        when :getb
          set.(a, HexCommon.getb)
        when :puti
          print get.(a)
        when :putb
          print (get.(a) & 255).chr
        when :move
          set.(a, get.(b))
        when :swap
          x = get.(a)
          set.(a, get.(b))
          set.(b, x)
        when :unary
          set.(b, HexCommon.unary(a, get.(b)))
        when :binary
          set.(b, HexCommon.binary(a, get.(b), get.(c)))
        when :jump
          now_label = a.to_sym
          break
        when :tjump
          now_label = get.(a).positive? ? b.to_sym : c.to_sym
          break
        else
          raise "unknown command: #{l}"
        end
      end
    end
  end

  def parse code
    blocks = {}
    now_label = nil
    now_block = []
    end_block = ->(label){
      if !now_label.nil? || !now_block.empty?
        raise "duplicate label: #{now_label}" if blocks[now_label]
        blocks[now_label] = now_block
        now_block = []
      end
      now_label = label
    }

    code.each_line do |raw_l|
      l = raw_l.gsub /\s++|#.*+/, ''
      next if l.empty?

      now_block <<
        case l
        when /\A (#{LAB}): \z/x
          end_block.($1.to_sym)
          next
        when /\A (t) = (get[ib]) \z/x
          [$2.to_sym, [:reg, $1]]
        when /\A (put[ib]) (t) \z/x
          [$1.to_sym, [:reg, $2]]
        when /\A ([txi]) = (#{IMM}) \z/x
          [:move, [:reg, $1], [:imm, imm($2)]]
        when /\A ([txi]) (#{UNA}) \z/x
          [:unary, $2, [:reg, $1]]
        when /\A (#{UNA}) ([txi]) \z/x
          [:unary, $1, [:reg, $2]]
        when /\A(?: (t) = ([xi]) | ([xi]) = (t) )\z/x
          [:move, [:reg, $1 || $3], [:reg, $2 || $4]]
        when /\A ([xi]) (#{BIN})= (t) \z/x
          [:binary, $2, [:reg, $1], [:reg, $3]]
        when /\A (t) = (a)\[(#{IMM})\] \z/x
          [:move, [:reg, $1], [:arr, $2, [:imm, imm($3)]]]
        when /\A (t) = (a)\[(i)\] \z/x
          [:move, [:reg, $1], [:arr, $2, [:reg, $3]]]
        when /\A (a)\[(#{IMM})\] = (t) \z/x
          [:move, [:arr, $1, [:imm, imm($2)]], [:reg, $3]]
        when /\A (a)\[(i)\] = (t) \z/x
          [:move, [:arr, $1, [:reg, $2]], [:reg, $3]]
        when /\A ! (\w++)/x
          [:jump, $1]
        when /\A (t)\? \+(#{LAB}) -(#{LAB})/x
          [:tjump, [:reg, $1], $2, $3]
        when /\A swap (?: (t), ([xi]) | ([xi]), (t) )/x
          [:swap, [:reg, $1 || $3], [:reg, $2 || $4]]
        else
          raise "unknown command: #{raw_l}"
        end
    end

    end_block.('__end__')
    blocks
  end

  private def imm s
    eval(s).ord
  end
end

if __FILE__ == $0
  $hex_debug = ARGV.any?{|x| x =~ /\A-*+d(?:ebug)?+\z/ }
  $hex_use_multibyte_literal = !ARGV.any?{|x| x =~ /\A-*+(?:M|no-*+multibyte)\z/ }
  x = HexHappy.parse DATA.read
  pp x
  HexHappy.exec x
  require './happy2jumpable'
  y = Happy2Jumpable.convert x
  p y
  File.write '../test.hjp', y
  puts "HexJumpable code written to ../test.hjp"
end

__END__
@main0:
  ! input_loop
input_loop:
  t = getb
  t ? +input_loop_body -input_loop_end
input_loop_body:
  x = t
  t = '0'
  x -= t
  t = x
  a[i] = t
  i++
  ! input_loop
input_loop_end:
  i = 0
  ! output_loop
output_loop:
  t = a[i]
  x = t
  t = 5
  i += t # i = i0 + 5
  t = a[i]
  x *= t
  t = 7
  i += t # i = i0 + 12
  t = a[i]
  x *= t
  t = 5
  i += t # i = i0 + 17
  t = a[i]
  x *= t
  t = x
  puti t
  t = 65
  i -= t # i = i0 - 48
  t = i
  t ? +@exit -output_loop_forward
output_loop_forward:
  t = 49
  i += t # i = i0 + 1
  ! output_loop
