module HexCommon
  module_function
  def geti
    c = fetch_char
    c = fetch_char while c && c !~ /\A[\d+-]\z/
    s = c
    c = fetch_char
    while c && c =~ /\d/
      s << c
      c = fetch_char
    end
    s.to_i 10
  end

  def getb
    fetch_char&.ord || -1
  end

  def binary op, l, r
    case op.to_sym
    when :+;       l + r
    when :-;       l - r
    when :*;       l * r
    when :/, :':'; l / r
    when :%;       l % r
    else
      raise "unknown operator: #{l} #{op} #{r}"
    end
  end

  def unary op, v
    case op.to_sym
    when :'++'; v + 1
    when :'--'; v - 1
    when :-@;   -v
    else
      raise "unknown operator: #{op} #{v}"
    end
  end

  private def fetch_char
    @chars_read ||= []
    @char_index ||= -1
    @char_index += 1
    @chars_read[@char_index] ||= $stdin.getbyte&.chr
  end

  private def unfetch_char
    @char_index -= 1
  end
end
