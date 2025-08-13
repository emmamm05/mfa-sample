# ruby
module CryptoUtils
  module PBKDF2
    DEFAULT_DIGEST = 'SHA256'
    DEFAULT_KEY_LENGTH = 32 # 256-bit
    DEFAULT_PBKDF2_ITERATIONS = 600_000

    module_function

    # Returns a hex-encoded PBKDF2-HMAC digest
    # secret: String
    # salt_hex: Hex-encoded salt
    # iterations: Integer
    # length: key length in bytes (default 32)
    # digest: OpenSSL::Digest name as String or symbol (default 'SHA256')
    def hex(secret, salt_hex, iterations: DEFAULT_PBKDF2_ITERATIONS, length: DEFAULT_KEY_LENGTH, digest: DEFAULT_DIGEST)
      raise ArgumentError, 'secret must be present' if secret.nil?
      raise ArgumentError, 'salt_hex must be present' if salt_hex.nil?

      salt   = [salt_hex].pack('H*')
      digest = OpenSSL::Digest.const_get(digest.to_s).new
      bytes  = OpenSSL::PKCS5.pbkdf2_hmac(secret, salt, iterations.to_i, length, digest)
      bytes.unpack1('H*')
    end
  end
end