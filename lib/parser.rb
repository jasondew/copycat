require 'java'
require 'lib/java/stanford-parser.jar'
import 'edu.stanford.nlp.parser.lexparser.LexicalizedParser'
import 'edu.stanford.nlp.parser.lexparser.Options'
import 'edu.stanford.nlp.process.DocumentPreprocessor'
import 'java.io.StringReader'

module Parser
  PARSER_DEFINITION = 'englishPCFG.ser.gz'

  def self.parse(s)
    op = Options.new
    @lp ||= LexicalizedParser.new(PARSER_DEFINITION, op)
    op = @lp.op
    # op.tlpParams.setInputEncoding
    tlp = op.tlpParams.treebankLanguagePack
    tokenizer = tlp.getTokenizerFactory
    # The java code sets a lot of other options here on the dp object,
    # but it seems to work without doing that, so why do anything else?
    dp = DocumentPreprocessor.new(StringReader.new(s))
    dp.setTokenizerFactory(tokenizer)
    it = dp.iterator
    sentences = []
    sentences << it.next while it.hasNext
    if(sentences.length != 1)
      raise "ERROR: Tokenized #{sentences.length} sentences!"
    end
    @lp.parse(sentences[0])
    tree = @lp.getBestParse
    java_tree_to_arrays(tree)
  end

  def self.java_tree_to_arrays(tree)
    kids = tree.children.map{|x|java_tree_to_arrays(x)}
    kids.unshift(tree.label.value)
    kids
  end

  def self.shell_out_parse(s)
    fn = "/tmp/parsee-#{(10**20).to_s(36)}"
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
