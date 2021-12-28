# frozen_string_literal: true

class TokenSigner
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
end
