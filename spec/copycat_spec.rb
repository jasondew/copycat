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
  end
end
