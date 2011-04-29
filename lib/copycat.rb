require "copycat/version"

require "tree"
require "parser"
require "wordnet"

module Copycat

  module ClassMethods

    def mutate sentence, times = 1
      tree = Parser.parse(sentence)

      transform_tree tree

      tree.each do |node|
        next unless node.content.is_a? Array

        # picking the first sense of the word because we have to better information
        entry = node.content.first
        next unless entry

        replacement = random(entry.words.keys)
        node.content = replacement if replacement
      end

      reconstituted_sentence = []
      tree.each {|node| reconstituted_sentence << node.content if node.is_leaf? }

      result = reconstituted_sentence.join " "

      if times == 1
        result
      else
        mutate(result, times - 1)
      end
    end

    def compare(sentence1, sentence2)
      tree1 = Parser.parse(sentence1)
      tree2 = Parser.parse(sentence2)
      transform_tree tree1
      transform_tree tree2

      compare_subtrees tree1, tree2

#     subtrees1 = assemble_subtrees tree1
#     subtrees2 = assemble_subtrees tree2
#
#     nonterminal_types = (subtrees1.keys & subtrees2.keys)
#
#     nonterminal_types.each do |nonterminal_type|
#       # Loop through all pairs of subtrees for this nonterminal type
#       subtrees1[nonterminal_type].each do |t1|
#         subtrees2[nonterminal_type].each do |t2|
#           # some comparison of t1 and t2
#         end
#       end
#     end
    end

    def compare_subtrees tree1, tree2
      if(tree1.size == 2 and tree2.size == 2)
        # base case, we have two collections of wordnet objects
        return wordnet_compare(tree1.children[0].content, tree2.children[0].content)
      end

      tree1_child_types = tree1.children.map &:content
      tree2_child_types = tree2.children.map &:content

      # crude initial method -- return 0 if they don't have exactly the
      # same immediate substructure
      return 0 if tree1_child_types != tree2_child_types

      total = 0.0
      tree1.children.zip(tree2.children).each do |stree1, stree2|
        total += compare_subtrees(stree1, stree2)
      end
      total / tree1.children.length
    end

    def wordnet_compare(entries1, entries2)
      if(entries1.class == String or entries2.class == String)
        return entries1 == entries2 ? 1 : 0
      end
      min_distance = 30.0 
      entries1.each do |entry1|
        entries2.each do |entry2|
          hdf = entry1.hypernym_distance_from entry2
          min_distance = [min_distance, hdf].min if hdf
        end
      end
      # There's probably a better way to convert the distance to a similarity
      # measure. Probably.
      1 - min_distance / 30.0
    end

    # Groups the subtrees by non-terminal type
    def assemble_subtrees tree
      subtrees = {}
      tree.each do |t|
        next if t.children.empty?
        # when I spell it out in english suddenly I'm using MORE characters than the original expression
        nonterminal = t.content
        subtrees[nonterminal] ||= []
        subtrees[nonterminal] << t
      end
      subtrees
    end

    # Converts the terminals of a parse tree to arrays of wordnet objects
    def transform_tree(tree)
      if(tree.children.empty?)
        pos = tag_to_wordnet_part_of_speech(tree.parent.content)
        if pos
          tree.content = Wordnet.search(tree.content, pos)
        end
      else
        tree.children.each{|child|transform_tree(child)}
      end
    end

    def tag_to_wordnet_part_of_speech tag
      # Not 100% sure this is complete or accurate
      case tag
        when /^N/  then :noun
        when /^V/  then :verb
        when /^RB/ then :adv
        when /^J/  then :adj
      end
    end

    def random array
      index = (rand * array.size).to_i
      array[index]
    end
  end

  extend ClassMethods
end
