def em s
  "\e[1;32m{{ #{s} }}\e[0m"
end

while gets
  # E: 右下がり
  # SE: 鉛直
  # NE: 右上がり
  $_.gsub! '[0, 0, :E]', em('t')
  $_.gsub! '[1, -1, :SE]', em('x')
  $_.gsub! '[0, 0, :SE]', em('i')
  $_.gsub! '[0, 0, :NE]', em('β')
  $_.gsub! /\[0, (\d++), :E\]/ do em "δ_#{$1.to_i-1}" end
  $_.gsub! /\[0, (\d++), :NE\]/ do em "γ_#{$1.to_i-1}" end
  $_.gsub! /\[0, (\d++), :SE\]/ do em "a_#{$1.to_i-1}" end
  $_.gsub! /\[1, (\d++), :SE\]/ do em "α_#$1" end
  print
end
