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

  describe 'Comparison' do
    sentence1 = %q{In plagiarism detection with reference, the suspicious text fragments
                   are compared to a reference corpus in order to find the possible
                   source of the plagiarism cases.}
    sentence2 = %q{I can't believe it's not butter!}
    sentence3 = %q{Jason and I built this state-of-the-art plagiarism detector in which
                   the suspicious text fragments are compared to a reference corpus; this
                   is how we have made most of our money to date.}
    sentence4 = %q{When you want to detect plagiarism with a reference text, you compare
                   the suspicious text fragments with a reference corpus so as to
                   determine the likely source of the plagiarism.}

    it 'should return a low probability for unrelated sentences' do
      Copycat.compare(sentence1, sentence2).should be_within(0.11).of(0.1)
    end

    it 'should return a high probability for identical sentences' do
      Copycat.compare(sentence1, sentence1).should be_within(0.06).of(0.95)
    end

    it 'should return a high probability for sentences with identical portions' do
      Copycat.compare(sentence1, sentence3).should be_within(0.25).of(0.8)
    end

    it 'should return a not-low probability for a reworded sentence' do
      Copycat.compare(sentence1, sentence4).should be_within(0.3).of(0.5)
    end
  end
end
