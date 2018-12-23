require './jumpable'

# Happyコマンドの境界では
# * メモリポインタはt上にある
# * メモリポインタはxを右前に見ている
# * α[0],β,γ[0]は0である
module Happy2Jumpable
  module_function
  def convert blocks
    jbs = blocks.map do |k, b|
      l_start = k
      l_ends = nil

      commands = b.flat_map do |l|
        raise "command after jump: #{l}" if l_ends

        cmd, a, b, c = l
        cmd = cmd.to_sym
        case cmd
        when :geti, :getb, :puti, :putb
          assert_reg a, ?t
          cmd
        when :unary
          assert_reg b, 'txi'
          [
            *to_reg(b[1]),
            { '++' => :inc, '--' => :dec, '-@' => :neg }.fetch(a.to_s),
            *from_reg(b[1]),
          ]
        when :binary
          convert_bin a, b, c
        when :move
          convert_move a, b
        when :swap
          convert_swap a, b
        when :jump
          l_ends = [a.to_sym]
          []
        when :tjump
          assert_reg a, 't'
          l_ends = [b.to_sym, c.to_sym]
          []
        end
      end

      [l_start, commands, l_ends]
    end
    jbs.push *arr_get_ip5 if jbs.any?{|_, cs, _| cs.include? :array_get }
    jbs.push *arr_set_ip1 if jbs.any?{|_, cs, _| cs.include? :array_set }

    HexJumpable.new jbs.map{|ls, cs, les|
      HexJumpable::Block.new ls, cs.map{|c| HexJumpable::Command.new c }, *les
    }
  end

  private def assert_reg x, ok
    raise "assertion failed: expected register #{ok}, but found #{x}" if x[0] != :reg || !ok.chars.include?(x[1])
  end

  private def to_reg r
    case r
    when ?t; []
    when ?x; [:right]
    when ?i; [:back_left]
    end
  end

  private def from_reg r
    case r
    when ?t; []
    when ?x; [:back_right]
    when ?i; [:left]
    end
  end

  private def convert_bin op, l, r
    assert_reg l, 'xi'
    assert_reg r, 't'
    rev_x = l[1] == 'x' ? [:reverse] : []
    rev_i = l[1] == 'i' ? [:reverse] : []
    [
      *rev_x, # t
      :back_right, # βγ
      { '+' => :add, '-' => :sub, '*' => :mul, '/' => :div, '%' => :mod }.fetch(op.to_s), # β = xi op t
      :left, :reverse, # xi
      :char_R, :dup, # xi = βγ
      :right, # βγ
      :mul, # βγ = 0
      :back_left, # t
      *rev_i,
    ]
  end

  private def convert_move a, b
    case [a[0], a[1], a.dig(2, 0), a.dig(2, 1), b[0], b[1], b.dig(2, 0), b.dig(2, 1)]
    when all_match([:reg, /\A[xi]\z/, nil, nil, :reg, 't', nil, nil])
      rev_x = a[1] == 'x' ? [:reverse] : []
      [
        *rev_x, # t
        :back_left, # xi
        :char_L, :negate, :dup, # xi = t
        :left, # t
        *rev_x,
      ]
    when all_match([:reg, 't', nil, nil, :reg, /\A[xi]\z/, nil, nil])
      rev_i = b[1] == 'i' ? [:reverse] : []
      [
        *rev_i,
        :char_R, :dup, # t = xi
        *rev_i,
      ]
    when all_match([:reg, /\A[txi]\z/, nil, nil, :imm, Integer, nil, nil])
      [
        *to_reg(b[1]),
        *convert_immediate(b[1], zero_rev: a[1] == 'i'),
        *from_reg(b[1]),
      ]
    when all_match([:reg, 't', nil, nil, :arr, 'a', :imm, Integer])
      [
        :back_right, # γ[0]
        *(b[2][1] == 0 ? [] : convert_immediate(b[2][1] * 100, zero_rev: nil)),
        :array_get, # stops at t
      ]
    when all_match([:reg, 't', nil, nil, :arr, 'a', :reg, 'i'])
      [
        :back_right, # γ[0]
        :char_L, :negate, :dup, # γ[0] = i
        :'0', :'0', # γ[0] *= 100
        :array_get, # stops at t
      ]
    when all_match([:arr, 'a', :imm, Integer, :reg, 't', nil, nil])
      [
        :back_right, # γ0
        *(a[2][1] == 0 ? [] : convert_immediate(a[2][1] * 100, zero_rev: nil)),
        :array_set, # stops at t
      ]
    when all_match([:arr, 'a', :reg, 'i', :reg, 't', nil, nil])
      [
        :back_right, # γ[0]
        :char_L, :negate, :dup, # γ[0] = i
        :'0', :'0', # γ[0] *= 100
        :array_set, # stops at t
      ]
    else
      raise "assertion failed: invalid params for move (#{a}, #{b})"
    end
  end

  private def convert_swap a, b
    case [a[0], a[1], b[0], b[1]]
    when all_match([:reg, /\A[xi]\z/, :reg, 't'])
      rev_x = a[1] == 'x' ? [:reverse] : []
      rev_i = a[1] == 'i' ? [:reverse] : []
      [
        *rev_x, # t
        :back_right, # βγ
        :char_R, :dup, # βγ = t
        :right, :reverse, # t
        :char_R, :dup, # t = xi
        :right, :reverse, # xi
        :char_R, :dup, # xi = βγ
        :right, :mul, # βγ = 0
        :back_left, # t
        *rev_i,
      ]
    when all_match([:reg, 't', :reg, /\A[xi]\z/])
      convert_swap b, a
    else
      raise "assertion failed: invalid params for swap (#{a}, #{b})"
    end
  end

  private def all_match matchers
    return Object.new.tap do |o|
      o.instance_variable_set :@matchers, matchers
      def o.=== vs
        vs.is_a?(Array) && @matchers.zip(vs).all?{|m, v| m === v }
      end
    end
  end

  def imm_literals
    if $hex_use_multibyte_literal
      [1..8, 14..31, 65..90, 97..122, 127..0x10ffff]
    else
      [65..90, 97..122]
    end
  end

  private def convert_immediate val, zero_rev:
    neg = val < 0 ? [:negate] : []
    v = val.abs.to_s
    zero_rev = zero_rev ? [:reverse] : []
    [
      if i = 6.downto(1).find{|i| imm_literals.any?{|r| r.include? v[0, i].to_i }}
        s = v.slice! 0, i
        [:"char_#{s.to_i.chr 'UTF-8'}"]
      else
        v = "" if val == 0
        [*zero_rev, :mul, *zero_rev]
      end,
      v.chars.map(&:to_sym),
      neg,
    ].flatten 1
  end

  def arr_get_ip5
    # get algorithm
    # 入力: γ[0]=添字i*100, MP=&γ[0](前:&t,&i)
    # 出力: t=a[i], MP=&t(前:&x,&β)
    # β = 負;
    # while(γ[j](==*MP) > 0) {
    #   α[j] = 100;
    #   δ[j] = γ[j] - α[j];
    #   γ[j+1] = δ[j];
    #   MP = &γ[j+1];
    # }
    # γ[i] = 正;
    # δ[i] = a[i];
    # MP = &γ[i];
    # do {
    #   γ[j] = δ[j];
    #   δ[j-1] = γ[j];
    #   MP = &γ[j-1];
    # } while(γ[j](==*MP) > 0)
    # // MP == β == γ[-1]
    # β = 0;
    # γ[0] = 0;
    # MP = &t;
    [
      [:@main5, [], [:@main5_loop]],
      [:@main5_loop, [
        :right, :left, :char_N, :negate, # β = 負;
        :back_left, :back_right, # reset MP = &γ[0];
      ], [:@get_forward]], # while(γ[j](==*MP) > 0) {
      [:@get_forward, [], [:@get_forward_body, :@get_forward_end]],
      [:@get_forward_body, [
        :back_right, :char_d, # α[j] = 100;
        :left, :reverse, :minus, # δ[j] = γ[j] - α[j];
        :back_right, :char_R, :dup, # γ[j+1] = δ[j]; MP = &γ[j+1];
      ], [:@get_forward]], # }
      [:@get_forward_end, [
        :char_P, # γ[i] = 正;
        :back_left, :reverse, :char_R, :dup, # δ[i] = a[i];
        :back_right, # MP = &γ[i];
      ], :@get_backward],
      [:@get_backward, [ # do {
        :char_R, :dup, # γ[j] = δ[j];
        :back_left, :char_L, :negate, :dup, # δ[j-1] = γ[j];
        :back_right, # MP = &γ[j-1];
      ], [:@get_backward_tmp, :@get_backward_end]], # } while(γ[j](==*MP) > 0)
      [:@get_backward_tmp, [], :@get_backward],
      [:@get_backward_end, [
        # // MP == β == γ[-1]
        :reverse, :mul, # β = 0;
        :reverse, :right, :left, :left, :mul, # α[0] = 0;
        :back_left, :mul, # γ[0] = 0;
        :back_left, :reverse, # MP = &t;
        :inc_ip,
      ], [:@main5_loop]],
    ]
  end

  def arr_set_ip1
    # set algorithm
    # 入力: γ[0]=添字i*100, t=値, MP=&γ[0](前:&t,&i)
    # 出力: a[i]=t, MP=&t(前:&x,&β)
    # β = 負;
    # while(γ[j](==*MP) > 0) {
    #   α[j] = 100;
    #   δ[j] = γ[j] - α[j];
    #   γ[j+1] = δ[j];
    #   γ[j] = δ[j-1];
    #   δ[j] = γ[j];
    #   γ[j] = 正;
    #   MP = &γ[j+1];
    # }
    # γ[i] = δ[i-1];
    # δ[i] = γ[i];
    # a[i] = δ[i];
    # MP = &γ[i];
    # // γ[i] = 正;
    # do {
    #   MP = &γ[j-1];
    # } while(γ[j](==*MP) > 0)
    # // MP == β == γ[-1]
    # β = 0;
    # γ[0] = 0;
    # MP = &t;
    [
      [:@main1, [], [:@main1_loop]],
      [:@main1_loop, [
        :right, :left, :char_N, :negate, # β = 負;
        :back_left, :back_right, # reset MP = &γ[0];
      ], [:@set_forward]], # while(γ[j](==*MP) > 0) {
      [:@set_forward, [], [:@set_forward_body, :@set_forward_end]],
      [:@set_forward_body, [
        :back_right, :char_d, # α[j] = 100;
        :left, :reverse, :minus, # δ[j] = γ[j] - α[j];
        :back_right, :char_R, :dup, # γ[j+1] = δ[j];
        :right, :left, :char_R, :dup, # γ[j] = δ[j-1];
        :back_left, :char_L, :negate, :dup, # δ[j] = γ[j];
        :left, :char_P, # γ[j] = 正;
        :back_left, :back_right, # MP = &γ[j+1];
      ], [:@set_forward]],
      [:@set_forward_end, [
        :char_R, :dup, # γ[i] = δ[i-1];
        :back_left, :char_L, :negate, :dup, # δ[i] = γ[i];
        :back_left, :char_L, :negate, :dup, # a[i] = δ[i];
        :left, :left, # MP = &γ[i];
      ], [:@set_backward]],
      [:@set_backward, [
        :right, :left,
      ], [:@set_backward_tmp, :set_backward_end]],
      [:@set_backward_tmp, [], :@set_backward],
      [:@set_backward_end, [
        :mul, # β = 0;
        :back_left, # MP = &t;
        :dec_ip,
      ], [:@main1_loop]],
    ]
  end
end
