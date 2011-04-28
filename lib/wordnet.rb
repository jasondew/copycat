module Wordnet

  module ClassMethods

    # not sure we want to keep this here after testing
    attr_reader :loaded, :data, :index

    @loaded = false
    @data = {}
    @index = {}

    PARTS_OF_SPEECH = %w(noun verb adj adv)
    DATA_PATH = File.join File.dirname(__FILE__), "data"
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
          id, _, _, word_count, *words_and_pointers = data.split /\s/

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

          pos_data[id] = {:words => words, :pointers => pointers, :gloss => gloss}
          words.each {|word, pointer| (pos_index[word] ||= []) << id }
        end

        @data[part_of_speech] = pos_data
        @index[part_of_speech] = pos_index
      end
    end

    def sense_for(w)
      if(ws = @index[w])
        ws[0]
      end
    end

    def similar(id)
      if(hypers = @data[id][:hypernym])
        id = hypers[rand(hypers.length)]
        words = @data[id][:word]
        words[rand(words.length)]
      end
    end

  end
  extend ClassMethods

end
