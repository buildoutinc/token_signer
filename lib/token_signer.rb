# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext'
require 'token_signer/version'
require 'token_signer/signed_data'
require 'token_signer/null_signer'

class TokenSigner
  MIN_SECRET_SIZE = 24 # matches ActiveRecord::SecureToken::MINIMUM_TOKEN_LENGTH
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
    raise InvalidSecret, "secret length must be >= #{MIN_SECRET_SIZE}" unless secret.bytesize >= MIN_SECRET_SIZE
  end

  # This has to come after we've defined everything an instance needs
  self.instance = new(nil) # dummy instance to prevent errors
end
