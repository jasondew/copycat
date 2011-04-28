module Plagiarizer
  def self.plagiarize(sentence)
    parsed = Parser.parse(sentence)
    tree = self.transform(parsed)
    self.flatten(tree)
  end

  def self.transform(tree)
    if(tree[1].class == String)
      if(id = Wordnet.sense_for(tree[1]) and sim = Wordnet.similar(id))
        [tree[0], sim]
      else
        tree
      end
    else
      [tree[0]] + tree[1..-1].map{|x|self.transform(x)}
    end
  end


  def self.flatten(tree)
    if(tree[1].class == String)
      tree[1]
    else
      tree[1..-1].map{|t|self.flatten(t)}.join(' ')
    end
  end
end
