# frozen_string_literal: true

require 'active_support'
require 'token_signer/version'

class TokenSigner
  MIN_SECRET_SIZE = 24
  private_constant :MIN_SECRET_SIZE

  class InvalidSecret < StandardError; end

  class << self
    # Global instance which you can assign in an initializer. Useful for when your app has a single unchangning secret.
    # Assigning this after app initialization is strongly discouraged due to race conditions.
    attr_accessor :instance
  end

  # `secret` can be blank; see NullSigner for implications
  # `max_age` Integer seconds, ActiveSupport::Duration; or nil to skip token age verification
  def initialize(secret, max_age: nil)
    secret = secret.presence
    validate_secret(secret)
    SignedData.validate_max_age(max_age)
    @secret = secret
    @max_age = max_age
  end

  # `unsigned`: a serializable object
  def generate(unsigned)
    from_unsigned_object(unsigned).when_valid do |_, signed_val|
      return signed_val
    end
  end

  def from_signed_string(signed)
    return SignedData.new_as_invalid if signed.blank?

    unsigned, now_unix = signer.verify(signed)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    SignedData.new_as_invalid
  else
    SignedData.new(unsigned_value: unsigned,
                   signed_value: signed,
                   signed_at: now_unix,
                   sig_valid: true,
                   max_age: @max_age)
  end

  private

  def from_unsigned_object(unsigned)
    # Signing time is useful for making tokens expire. We store "now" instead of an expiry time so the server has full
    # control of changing the TTL.
    now_unix = SignedData.now_as_unix
    signed = signer.generate([unsigned, now_unix])

    SignedData.new(unsigned_value: unsigned,
                   signed_value: signed,
                   signed_at: now_unix,
                   sig_valid: true,
                   max_age: @max_age)
  end

  def signer
    return @signer if @signer

    signer_klass = @secret ? ActiveSupport::MessageVerifier : NullSigner

    # `digest: 'SHA1', serializer: Marshal` are the defaults (currently), but we're explicit here in case those change
    # and we're not able to get all apps onto the same version.
    @signer = signer_klass.new(@secret, digest: 'SHA1', serializer: Marshal)
  end

  def validate_secret(secret)
    return if secret.nil? # allowed to be nil; see NullSigner for implications

    raise TypeError, 'secret must be a String' unless secret.is_a?(String)
    raise InvalidSecret, "secret length must be >= #{MIN_SECRET_SIZE}" unless secret.size >= MIN_SECRET_SIZE
  end

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

  # Fallback signer when secret is blank. Its only purpose is to avoid `raise`ing errors.
  # Useful for local development when token signing isn't needed and you don't want to configure a secret.
  # It can't properly generate or verify signatures, but acts like ActiveSupport::MessageVerifier.
  class NullSigner
    def initialize(*); end

    def generate(*)
      ''
    end

    def verify(*)
      raise ActiveSupport::MessageVerifier::InvalidSignature
    end
  end
  private_constant :NullSigner

  # This has to come after we've defined everything an instance needs
  self.instance = new(nil) # dummy instance to prevent errors
end
