module Wordnet
  def self.noun(w)
    
  end

  def self.data
    @data
  end

  def self.sense_for(w)
    if(ws = @index[w])
      ws[0]
    end
  end

  def self.similar(id)
    if(hypers = @data[id][:hypernym])
      id = hypers[rand(hypers.length)]
      words = @data[id][:word]
      words[rand(words.length)]
    end
  end

  # This is very ad-hoc so far. All the rules used here I learned from the noun file,
  # so may not apply really.
  def self.parse_dict_files
    @data = {}
    @index = {}
    files = Dir.glob('dict/data.*')
    files.each do |file|
      File.read(file).split("\n").reject{|l|l=~/^\s/}.each do |line|
        tokens = line.split(' ')
        id = tokens.shift
        h2 = {}
        3.times { tokens.shift }
        h2[:word] = [tokens.shift]
        add = lambda do |key, value|
          h2[key] ||= []
          h2[key] << value
        end
        until(tokens.empty?)
          t = tokens.shift
          case t
            when '@'
              add.call(:hypernym, tokens.shift)
            when '|'
              h2[:description] = tokens.join(' ')
              tokens = []
            when '#m' # e.g. 12699301 to 12699157
              add.call(:member_of, tokens.shift)
            when '%m' # e.g. 12699157 to 12699301
              add.call(:member, tokens.shift)
            when '%p' # e.g. 12699301 to 07745803
              add.call(:part, tokens.shift)
            when '~'  # e.g. 03614007 to 03928814
              add.call(:hyponym, tokens.shift)
            when /^[-'0-9a-z_]{2,}$/i
              add.call(:word, t) unless t =~ /^(\d+|-.*)$/
          end
        end
        @data[id] = h2
        h2[:word].each do |x|
          @index[x] ||= []
          @index[x] << id
        end
      end
    end
    true
  end
end
