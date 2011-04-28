require 'java'
require 'lib/java/stanford-parser.jar'
import 'edu.stanford.nlp.parser.lexparser.LexicalizedParser'
import 'edu.stanford.nlp.parser.lexparser.Options'
import 'edu.stanford.nlp.process.DocumentPreprocessor'
import 'java.io.StringReader'

module Parser
  PARSER_DEFINITION = 'englishPCFG.ser.gz'

  def self.load_parser
    op = Options.new
    @lp ||= LexicalizedParser.new(PARSER_DEFINITION, op)
  end

  def self.parse(s)
    do_parse(s)
    tree = @lp.getBestParse
    java_tree_to_arrays(tree)
  end

  def self.best_parses(k, s)
    do_parse(s)
    trees = @lp.getKBestPCFGParses(k)
    trees.map{|scored_tree| [scored_tree.score, java_tree_to_arrays(scored_tree.object)] }
  end

  def self.do_parse(s)
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
  end

  def self.java_tree_to_arrays(tree)
    kids = tree.children.map{|x|java_tree_to_arrays(x)}
    kids.unshift(tree.label.value)
    kids
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

  self.load_parser
end
