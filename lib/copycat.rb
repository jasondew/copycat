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

        # picking the first sense of the word because we have no better information
        entry = node.content.first
        next unless entry

        replacement = entry.similar_word
        node.content = random(replacement.words.keys) if replacement
      end

      reconstituted_sentence = []
      tree.each {|node| reconstituted_sentence << node.content if node.is_leaf? }

      result = reconstituted_sentence.join " "
      # Cleans up some extra whitespace added before punctuation
      result = result.gsub(/\s+([;,\.\!\?])/, "\\1")

      if times == 1
        result
      else
        mutate(result, times - 1) # not suitable for large times, since uses stack
      end
    end

    # Returns a float in the range of [0,1] representing the probabality that
    # sentence2 has plagiarized sentence1
    def compare(sentence1, sentence2)
      tagged_words1 = remove_non_words unhash flatten transform_tree Parser.parse(sentence1)
      tagged_words2 = remove_non_words unhash flatten transform_tree Parser.parse(sentence2)

#      STDERR.puts "comparing:\n  #{sentence1.inspect}\n  #{sentence2.inspect}"
#      STDERR.puts "comparing:\n  #{tagged_words1.inspect}\n  #{tagged_words2.inspect}"

      # ensure that tagged_words1.size >= tagged_words2.size
      if tagged_words1.size < tagged_words2.size
        tagged_words1, tagged_words2 = tagged_words2, tagged_words1
      end

      max_similarity = 0.0
      tagged_words2.size.times do |size|
        max_similarity = [compare_fragments(tagged_words1, tagged_words2[0..size]), max_similarity].max
      end

      STDERR.puts "final result = #{max_similarity.inspect}"

      max_similarity
    end

    # precondition: tagged_words1.size >= tagged_words2.size
    def compare_fragments tagged_words1, tagged_words2
      if tagged_words1.size == tagged_words2.size
        result = compare_tagged_words tagged_words1, tagged_words2
        STDERR.puts "identical sizes, tagged_words1.size=#{tagged_words1.size} result = #{result.inspect}\n\n#{'#'*120}"
        result
      else
        max_similarity = 0.0
        compared_size = tagged_words2.size

        (tagged_words1.size - tagged_words2.size).times do |offset|
          similarity = compare_tagged_words tagged_words1[offset..(offset + compared_size - 1)], tagged_words2
          STDERR.puts ">> offset #{offset} similarity = #{similarity.inspect}"
          max_similarity = [similarity, max_similarity].max
        end

        result = max_similarity
        STDERR.puts "non-identical sizes, result = #{result.inspect}\n\n#{'#'*120}"
        result
      end

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
#STDERR.puts " !! >> tagged_words1.size = #{tagged_words1.size}, tagged_words2.size = #{tagged_words2.size}, zip size = #{tagged_words1.zip(tagged_words2).size}"
      tagged_words1.zip(tagged_words2).inject(0.0) do |sum, ((tag1, word1), (tag2, word2))|
        if tag1 == tag2
          result = sum + wordnet_compare(word1, word2)
#          STDERR.puts "compare_tagged_words >> #{result.inspect}"
          result
        else
#          STDERR.puts "compare_tagged_words >> #{sum.inspect} b/c tags didn't match >> #{tag1} != #{tag2}"
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
      return {tree.content => tree.children.first.content} if tree.size == 2

      tree.children.map {|subtree| flatten subtree }.flatten
    end

    def unhash tagged_words
      tagged_words.map {|hash| [hash.keys.first, hash.values.first] }
    end

    def remove_non_words tagged_words
      tagged_words.reject {|tag, word| tag !~ /^[A-Z]/ }
    end

    def wordnet_compare entries1, entries2
      result =
      if entries1.class == String and entries2.class == String
        entries1 == entries2 ? 1.0 : 0.0
      elsif entries1.class == String
        entries2.detect {|entry| entry.words.detect {|word| word == entries1 } } ? 1.0 : 0.0
      elsif entries2.class == String
        entries1.detect {|entry| entry.words.detect {|word| word == entries2 } } ? 1.0 : 0.0
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

#      STDERR.puts "  wordnet_compare #{entries1.inspect} to #{entries2.inspect} => #{result.inspect}"

      result
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
          tree.content = results unless results.empty?
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
