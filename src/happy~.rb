require './hex_common.rb'

# language HexHappy
# register: i | x
# array: a
# immediate: -?\d+ | '.+'
# index: i | IMM
# clause: IMM | REG
# factor: IMM | ARR[IDX]
# operator: + | - | * | / | %
# mnemonic:
#   geti REG
#   getb REG
#   puti CLZ
#   putb CLZ
#   set REG FACT
#   store ARR[IDX] CLZ
#   bin OP REG FACT
#   neg REG
#   jump LAB
#   xjump LAB_pos LAB_zeroneg (REG > 0)
# program: (LAB: mnemonic* (ends with jump or xjump))*
# entry label: main0
# exit label: exit
module HexHappy
  Mnemonic = Struct.new 'Mnemonic', :command, :args do
    def to_s; "Mn(#{command}: #{args.join ', '})" end
  end
  Label = Struct.new 'Label', :name do
    def to_s; "Lb(#{name})" end
  end
  Register = Struct.new 'Register', :reg do
    def to_s; "Rg(#{reg})" end
  end
  Operator = Struct.new 'Operator', :op do
    def to_s; "Op(#{op})" end
  end
  Immediate = Struct.new 'Immediate', :value do
    def to_s; "Im(#{value})" end
  end
  ArrayImm = Struct.new 'ArrayImm', :index do
    def to_s; "Ar(#{index})" end
  end
  ArrayRegI = Struct.new 'ArrayRegI' do
    def to_s; 'Ar(Rg(i))' end
  end

  ARGS_SIZE = {
    geti: 1, getb: 1, puti: 1, putb: 1, set: 2, store: 2, bin: 3, neg: 1, jump: 1, xjump: 2,
  }.freeze
  REGISTERS = %w[i x].freeze

  module_function

  def exec code
    return exec parse code if code.is_a? String
    label = Label.new :main0
    arr = []
    regs = { i: 0, x: 0 }
    arr_get = ->(x){
      i = x.is_a?(ArrayRegI) ? [regs[:i], 0].max : x.index.value
      debug "get arr[#{i}]: #{arr[i] || 0}"
      arr[i] ||= 0
    }
    arr_set = ->(x, v){
      i = x.is_a?(ArrayRegI) ? [regs[:i], 0].max : x.index.value
      debug "set arr[#{i}] = #{v}"
      arr[i] = v
    }
    fact = ->(x){ x.is_a?(Immediate) ? x.value : arr_get.(x) }
    clz = ->(x){ x.is_a?(Immediate) ? x.value : regs[x.reg] }

    while label.name != :exit
      debug label
      code[label].each do |l|
        debug "#{l} #{regs}"
        a, b, c = l.args
        case l.command
        when :geti
          regs[a.reg] = HexCommon.geti
        when :getb
          regs[a.reg] = HexCommon.getb
        when :puti
          print clz.(a)
        when :putb
          print (clz.(a) & 255).chr
        when :set
          regs[a.reg] = fact.(b)
        when :store
          arr_set.(a, clz.(b))
        when :bin
          regs[b.reg] = HexCommon.bin a.op, regs[b.reg], fact.(c)
        when :neg
          regs[a.reg] = -regs[a.reg]
        when :jump
          label = a
          break
        when :xjump
          label = regs[:x].positive? ? a : b
          break
        else
          raise "unknown command: #{l}"
        end
      end
    end
  end

  private def debug s
    $stderr.puts "[HexHappy] #{s}" if $hex_debug
  end

  def parse code
    blocks = {}
    now_label = nil
    now_block = []
    end_block = ->(label){
      label = parse_label label unless label.is_a? Label

      if !now_label.nil? || !now_block.empty?
        raise "duplicate label: #{now_label}" if blocks[now_label]
        blocks[now_label] = now_block
        now_block = []
      end
      now_label = label
    }

    code.each_line do |l|
      l.strip!
      l.sub! /#.*+/, ''
      next if l.empty?

      if l =~ /\A(\w++):\z/
        end_block.($1)
        next
      end

      name, *args = l.split
      name = name.to_sym
      raise "unknown mnemonic: #{l}" unless ARGS_SIZE[name]
      raise "invalid args size: #{l}" if ARGS_SIZE[name] != args.size
      a, b, c = args
      now_block <<
        case name
        when :geti, :getb, :neg
          Mnemonic.new name, [parse_register(a)]
        when :puti, :putb
          Mnemonic.new name, [parse_clause(a)]
        when :set
          Mnemonic.new name, [parse_register(a), parse_factor(b)]
        when :store
          Mnemonic.new name, [parse_array(a), parse_clause(b)]
        when :bin
          Mnemonic.new name, [parse_operator(b), parse_register(a), parse_factor(c)]
        when :jump
          Mnemonic.new name, [parse_label(a)]
        when :xjump
          Mnemonic.new name, [parse_label(a), parse_label(b)]
        else
          raise "unknown mnemonic: #{name} (args: #{args})"
        end
    end

    end_block.('__end__')
    blocks
  end

  private def parse_label s
    raise "invalid label name: #{s}" unless s =~ /\A\w++\z/
    Label.new s.to_sym
  end

  private def parse_register s
    raise "invalid register name: #{s}" unless REGISTERS.include? s
    Register.new s.to_sym
  end

  private def parse_immediate s
    if s =~ /\A[+-]?+\d++\z/
      Immediate.new s.to_i 10
    elsif s =~ /\A('.+'|".+")\z/
      Immediate.new eval(s).ord
    else
      raise "invalid immediate: #{s}"
    end
  end

  private def parse_array s
    if s =~ /\Aa\[([+-]?+\d++)\]\z/
      i = parse_immediate $1
      raise "negative immediate index for array: #{s}" if i.value < 0
      ArrayImm.new i
    elsif s == 'a[i]'
      ArrayRegI.new
    else
      raise "invalid array: #{s}"
    end
  end

  private def parse_factor s
    parse_immediate(s) rescue parse_array(s)
  rescue
    raise "invalid factor: #{s}"
  end

  private def parse_clause s
    parse_immediate(s) rescue parse_register(s)
  rescue
    raise "invalid clause: #{s}"
  end

  private def parse_operator s
    raise "invalid operator name: #{s}" unless s =~ /\A[-+*\/%]=\z/
    Operator.new s[0].to_sym
  end
end

if __FILE__ == $0
  $hex_debug = ARGV.any?{|x| x =~ /\A-*+d(?:ebug)?+\z/ }
  HexHappy.exec DATA.read
end

__END__
main0:
  geti x
  store a[0] x
  jump loop_cond
loop_cond:
  set x a[1]
  bin x += 1
  store a[1] x
  bin x -= a[0]
  xjump exit loop_body # exit if x > a[0]
loop_body:
  set x a[1]
  bin x %= 3
  xjump x_not3 x_3
x_not3:
  set x a[1]
  bin x %= 5
  xjump x_x x_buzz
x_3:
  putb 'F'
  putb 'i'
  putb 'z'
  putb 'z'
  set x a[1]
  bin x %= 5
  xjump x_end x_buzz
x_x:
  set x a[1]
  puti x
  jump x_end
x_buzz:
  putb 'B'
  putb 'u'
  putb 'z'
  putb 'z'
  jump x_end
x_end:
  set x "\n"
  putb x
  jump loop_cond
