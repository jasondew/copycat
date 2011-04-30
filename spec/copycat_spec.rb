require 'lib/copycat'

describe Copycat do
  describe 'Mutation' do
    sentence = "Thomas had a hard time keeping his eye on the ball."

    it 'should not throw an error when mutating a simple sentence' do
      p = lambda { Copycat.mutate sentence }
      p.should_not raise_error
    end

    it 'should return a sentence' do
      words = Copycat.mutate(sentence).split(' ')
      words.length.should be > 8
    end

    it 'should not include ruby inspection strings' do
      sentence2 = "He had a bad habit of throwing a tantrum whenever I was most vulnerable."
      Copycat.mutate(sentence2)['::'].should be_nil
    end
  end
end
