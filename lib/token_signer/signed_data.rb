# frozen_string_literal: true

class TokenSigner
  class SignedData
    def self.new_as_invalid
      new(unsigned_value: nil, signed_value: nil, signed_at: nil, sig_valid: false)
    end

    # `signed_at`: Unix time (integer)
    def initialize(unsigned_value:, signed_value:, signed_at:, sig_valid:, max_age: nil)
      self.class.validate_max_age(max_age)
      @unsigned_value = unsigned_value
      @signed_value = signed_value
      @signed_at = signed_at
      @max_age = max_age
      @sig_valid = sig_valid
    end

    def when_valid
      yield @unsigned_value, @signed_value if valid?
      self
    end

    def when_invalid
      yield unless valid?
      self
    end

    private

    def valid?
      return false unless @sig_valid

      if @max_age
        self.class.now_as_unix - @signed_at <= @max_age
      else
        true
      end
    end

    class << self
      def now_as_unix
        Time.now.to_i
      end

      def validate_max_age(max_age)
        return if max_age.nil?
        return if (max_age.is_a?(Integer) || max_age.is_a?(ActiveSupport::Duration)) && max_age.positive?

        raise TypeError
      end
    end
  end

  private_constant :SignedData
end
