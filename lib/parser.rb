module Parser
  PARSER_DIR = '/home/jed/stanford-parser-2011-04-20'
  def self.parse(s)
    fn = "parsee-#{(10**20).to_s(36)}"
    open(fn,'w'){|f|f.write(s)}
    res = `#{PARSER_DIR}/lexparser.csh #{fn} 2>/dev/null`
    self.parse_parens(res.gsub("\n",' '))[0]
  end

  def self.parse_parens(s)
    if(s =~ /^\s*\((\S+)\s+/)
      tree = [$1.to_sym]
      args, rem = self.parse_args($')
      tree = tree + args
      [tree, rem]
    end
  end

  def self.parse_args(s)
    if(s =~ /^\(\s*/)
      # subtree
      val, rem = self.parse_parens(s)
      other_vals, rem = self.parse_args(rem)
      [[val] + other_vals, rem]
    elsif(s =~ /^\)\s*/)
      # end of args
      [[], $']
    elsif(s =~ /^([^\s\(\)]+)\s*/)
      # leaf
      val = $1
      rem = $'
      other_vals, rem = self.parse_args(rem)
      [[val] + other_vals, rem]
    end
  end

  def self.pp(v, indent = 0)
    if(v.length == v.flatten.length)
      puts(' '*indent + v.inspect)
    else
      puts(' '*indent + '[' + v[0].inspect)
      v[1..-1].each{|el| self.pp(el, indent + 2)}
    end
    nil
  end
end
