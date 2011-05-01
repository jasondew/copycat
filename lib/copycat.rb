require "copycat/version"

require "tree"
require "parser"
require "wordnet"

module Copycat

  module ClassMethods

    def mutate sentence, times = 1
      tree = Parser.parse(sentence)

      transform_tree tree

      # Transform the tree again, picking a particular wordnet entry 
      tree.each do |node|
        next unless node.content.is_a? Hash

        # Pick a wordnet entry randomly from the matches
        #
        # I suppose if we knew the prior probabilities of the different senses,
        # picking the most probable would be preferable to picking at random.
        node.content[:current] = random node.content[:entries]
      end

      # Perform mutations <times> times
      times.times do
        tree.each do |node|
          next unless node.content.is_a? Hash
          node.content[:current] = node.content[:current].similar_word
        end
      end

      # take the final sense and pick a concrete word for it
      tree.each do |node|
        next unless node.content.is_a? Hash
        node.content[:old_text] = node.content[:text]
        node.content[:text] = random node.content[:current].words.keys
      end

      reconstituted_sentence = []
      tree.each do |node|
        next unless node.is_leaf?
        val = node.content.is_a?(Hash) ? node.content[:text] : node.content
        reconstituted_sentence << val
      end

      # Pretty-print the result
      lines = []
      tree.each do |node|
        next unless node.is_leaf?
        if(node.content.is_a? Hash)
          lines << [node.content[:text], node.content[:old_text]]
        else
          lines << node.content
        end
      end
      left_width = lines.map{|l|l.is_a?(String) ? l.length : l[0].length}.max
      # right_width = lines.map{|l|l.is_a?(String) ? 0 : l[1].length}.max
      lines.each do |line|
        if line.is_a? String
          puts("%-#{left_width}s |" % line)
        else
          puts("%-#{left_width}s | <= %s" % line)
        end
      end

      result = reconstituted_sentence.join " "
      # Cleans up some extra whitespace added before punctuation
      result = result.gsub(/\s+([;,\.\!\?])/, "\\1")

      result
    end

    # Returns a float in the range of [0,1] representing the probabality that
    # sentence2 has plagiarized sentence1
    def compare(sentence1, sentence2)
      tagged_words1 = remove_non_words unhash flatten transform_tree Parser.parse(sentence1)
      tagged_words2 = remove_non_words unhash flatten transform_tree Parser.parse(sentence2)

      # ensure that tagged_words1.size >= tagged_words2.size
      if tagged_words1.size < tagged_words2.size
        tagged_words1, tagged_words2 = tagged_words2, tagged_words1
      end

      max_similarity = 0.0
      tagged_words2.size.times do |end_point|
        end_point.times do |begin_point|
          similarity = compare_fragments(tagged_words1, tagged_words2[begin_point..end_point])
          similarity *= (end_point - begin_point).to_f / tagged_words2.size
          max_similarity = [similarity, max_similarity].max
        end
      end

      max_similarity
    end

    # precondition: tagged_words1.size >= tagged_words2.size
    def compare_fragments tagged_words1, tagged_words2
      max_similarity = 0.0
      compared_size = tagged_words2.size

      (tagged_words1.size - tagged_words2.size + 1).times do |offset|
        similarity = compare_tagged_words tagged_words1[offset..(offset + compared_size - 1)], tagged_words2
        max_similarity = [similarity, max_similarity].max
      end

      max_similarity

      #compare_subtrees tree1, tree2

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

    def compare_tagged_words tagged_words1, tagged_words2
      tagged_words1.zip(tagged_words2).inject(0.0) do |sum, ((tag1, word1), (tag2, word2))|
        if tag1 == tag2
          sum + wordnet_compare(word1, word2)
        else
          sum
        end
      end / tagged_words1.size.to_f
    end

    def compare_subtrees tree1, tree2
      if tree1.size == 2 and tree2.size == 2
        # base case, we have two collections of wordnet objects
        wordnet_compare(tree1.children.first.content, tree2.children.first.content)
      elsif tree1.size == 2
      elsif tree2.size == 2
      else
        # all possible alignments

        total = 0.0
        tree1.children.zip(tree2.children).each do |subtree1, subtree2|
          total += compare_subtrees subtree1, subtree2
        end
        total / tree1.children.length
      end
    end

    def child_tags tree
      tree.children.
           map(&:content).                  # get tags
           reject {|tag| tag !~ /^[A-Z]/ }  # reject punctuation tags
    end

    def flatten tree
      if tree.size == 2
        val = tree.children.first.content
        if val.is_a? Hash
          val = val[:entries]
        end
        return {tree.content => val}
      end

      tree.children.map {|subtree| flatten subtree }.flatten
    end

    def unhash tagged_words
      tagged_words.map {|hash| [hash.keys.first, hash.values.first] }
    end

    def remove_non_words tagged_words
      tagged_words.reject {|tag, word| tag !~ /^[A-Z]/ }
    end

    def wordnet_compare entries1, entries2
      if entries1.class == String and entries2.class == String
        entries1 == entries2 ? 1.0 : 0.0
      elsif [entries1.class,entries2.class].include?(String)
        # This means one of the words is in wordnet but the other isn't,
        # which makes it terribly hard to make a judgment.
        # Just an estimate. Not really sure what a good number here is.
        0.1
      else
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
    def transform_tree tree
      if tree.children.empty?
        if (pos = tag_to_wordnet_part_of_speech(tree.parent.content)) and (results = Wordnet.search(tree.content, pos))
          unless results.empty?
            tree.content = {:pos => pos, :text => tree.content, :entries => results}
          end
        end
      else
        tree.children.each {|child| transform_tree child }
      end

      tree
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
