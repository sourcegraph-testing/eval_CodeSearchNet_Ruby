module Bayes
  class Classifier
    attr_reader :categories

    def initialize
      @categories = {}
    end

    def train(category, text)
      ensure_category(category).train(text)
    end

    def ensure_category(category)
      @categories[category] ||= Bayes::Category.new
    end

    def train_with_array(category, lines)
      lines.each{ |line| train(category, line) }
    end

    def train_with_file(category, filename)
      train_with_array category, File.read(filename).split(/\r?\n/)
    end

    def train_with_csv(filename, separator: "||")
      csv = CSV.new File.read(filename), col_sep: separator, quote_char: "§" # hope § won't be used anywhere
      csv.each do |row|
        train row[1], row[0]
      end
    end

    def apply_weighting(category, coeff)
      ensure_category(category).apply_weighting(coeff)
    end

    def classify(string)
      words = string.word_hash.keys
      @categories.each_with_object({}) do |category, hash|
        hash[category[0]] = category[1].score_for(words)
      end.sort_by { |cat| -cat[1] }[0][0]
    end

    def pop_unused
      @categories.delete_if{ |name,cat| cat.blank? }
    end

    def flush
      @categories.each{ |name, cat| cat.reset }
    end

    def flush_all
      @categories = {}
    end
  end
end