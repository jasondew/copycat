#FIXME change this to use bundler
require "tree"

module Wordnet

  POINTER_SYMBOLS = { "!"  => "Antonym",
                      "@"  => "Hypernym",
                      "@i" => "Instance Hypernym",
                      "~"  => "Hyponym",
                      "~i" => "Instance Hyponym",
                      "#m" => "Member holonym",
                      "#s" => "Substance holonym",
                      "#p" => "Part holonym",
                      "%m" => "Member meronym",
                      "%s" => "Substance meronym",
                      "%p" => "Part meronym",
                      "="  => "Attribute",
                      "+"  => "Derivationally related form",
                      "*"  => "Entailment",
                      ">"  => "Cause",
                      "^"  => "Also see",
                      "$"  => "Verb Group",
                      "+"  => "Derivationally related form",
                      "&"  => "Similar to",
                      "<"  => "Participle of verb",
                      "\\" => "Pertainym (pertains to noun) for adjectives, Derived from adjective for adverbs",
                      ";c" => "Domain of synset - TOPIC",
                      "-c" => "Member of this domain - TOPIC",
                      ";r" => "Domain of synset - REGION",
                      "-r" => "Member of this domain - REGION",
                      ";u" => "Domain of synset - USAGE",
                      "-u" => "Member of this domain - USAGE" }

  class Entry

    attr_reader :id, :part_of_speech, :words, :pointers, :gloss

    def initialize id, part_of_speech, words, pointers, gloss
      @id, @part_of_speech, @words, @pointers, @gloss = id, part_of_speech, words, pointers, gloss
    end

    def inspect
      "#<Wordnet::Entry::#{@id} @words=#{@words.inspect}>"
    end

    def hypernyms
      ids = @pointers.select {|symbol, *_| symbol == "@" }.map {|_, offset, *_| offset.to_i }
      ids.map {|id| Wordnet[id, part_of_speech] }
    end

    def hypernym_ancestors
      return if (ancestors = hypernyms).empty?

      root = Tree::TreeNode.new(id, self)

      ancestors.each do |word|
        word_ancestors = word.hypernym_ancestors
        root << word_ancestors if word_ancestors
      end

      root
    end

    def <=> other
    end

  end

  module ClassMethods

    # not sure we want to keep this here after testing
    attr_reader :data, :index

    @loaded = false
    @data = {}
    @index = {}

    PARTS_OF_SPEECH = [:noun, :verb, :adj, :adv]
    DATA_PATH = File.join File.dirname(__FILE__), "data"

    def included _
      @data = Hash.new
      @index = Hash.new

      PARTS_OF_SPEECH.each do |part_of_speech|
        pos_data = {}
        pos_index = {}
        filename = File.join DATA_PATH, "data.#{part_of_speech}"

        File.readlines(filename).each do |line|
          next if line =~ /^  /
          # synset_offset lex_filenum ss_type w_cnt word lex_id [word lex_id...] p_cnt [ptr...] [frames...] | gloss

          data, gloss = line.split /\|/, 2
          id_string, _, _, word_count, *words_and_pointers = data.split /\s/
          id = id_string.to_i

          # parse the words
          words = Hash.new

          word_count.to_i.times do
            word, pointer = words_and_pointers.shift(2)
            word.gsub! /_/, " "

            words[word] = pointer
          end

          # parse the pointers
          pointer_count = words_and_pointers.shift
          pointers = Array.new

          pointer_count.to_i.times do
            symbol, offset, type, source_or_target = words_and_pointers.shift(4)
            pointers << [symbol, offset, type, source_or_target]
          end

          entry = Entry.new(id, part_of_speech, words, pointers, gloss)
          pos_data[id] = entry
          words.each {|word, pointer| pos_index[word.downcase] = entry }
        end

        @data[part_of_speech] = pos_data
        @index[part_of_speech] = pos_index
      end

      @loaded = true
    end

    def loaded?
      !! @loaded
    end

    def search word
      PARTS_OF_SPEECH.map {|part_of_speech| @index[part_of_speech][word.downcase] }.compact
    end

    def [] id, part_of_speech
      return unless @loaded and @data
      return unless (pos_data = @data[part_of_speech.to_sym])

      pos_data[id.to_i]
    end

  end
  extend ClassMethods

end
