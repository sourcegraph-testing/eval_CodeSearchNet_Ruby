module Encruby
  class Message
    AES_MODE = :CBC

    attr_accessor :key

    def initialize(key)
      self.key = key
      @cipher = OpenSSL::Cipher::AES256.new(AES_MODE)
    end

    def key=(key)
      key = Pathname.new(key.to_s)
      if !key.readable? || key.read.strip.empty?
        raise Error, "Unreadable RSA public/private key!"
      end
      @rsa = OpenSSL::PKey::RSA.new(key.read)
    end

    def with_key(key)
      self.key = key
      self
    end

    def hmac_signature(content)
      OpenSSL::HMAC.hexdigest('sha256', @rsa.public_key.to_s, content)
    end

    # 1. Generate random AES key to encrypt message
    # 2. Use Public Key from the Private key to encrypt AES Key
    # 3. Prepend encrypted AES key to the encrypted message
    #
    # Output message format will look like the following:
    #
    #  {RSA Encrypted AES Key}{RSA Encrypted IV}{AES Encrypted Message}
    def encrypt(message)
      raise Error, "data must not be empty" if message.to_s.strip.empty?
      # 1
      @cipher.reset
      @cipher.encrypt
      aes_key   = @cipher.random_key
      aes_iv    = @cipher.random_iv
      encrypted = @cipher.update(message) + @cipher.final

      # 2
      rsa_encrypted_aes_key = @rsa.public_encrypt(aes_key)
      rsa_encrypted_aes_iv  = @rsa.public_encrypt(aes_iv)

      # 3
      content = rsa_encrypted_aes_key + rsa_encrypted_aes_iv + encrypted

      # 4
      hmac = hmac_signature(content)
      content = Base64.encode64(hmac + content)

      { signature: hmac, content: content }
    rescue OpenSSL::OpenSSLError => e
      raise Error.new(e.message)
    end

    # 0. Base64 decode the encrypted message
    # 1. Split the string in to the AES key and the encrypted message
    # 2. Decrypt the AES key using the private key
    # 3. Decrypt the message using the AES key
    def decrypt(message, hash: nil)
      # 0
      message = Base64.decode64(message)
      hmac = message[0..63] # 64 bits of hmac signature

      case
      when hash && hmac != hash
        raise Error, "Provided hash mismatch for encrypted file!"
      when hmac != hmac_signature(message[64..-1])
        raise Error, "HMAC signature mismatch for encrypted file!"
      end

      # 1
      rsa_encrypted_aes_key = message[64..319]  # next 256 bits
      rsa_encrypted_aes_iv  = message[320..575] # next 256 bits
      aes_encrypted_message = message[576..-1]

      # 2
      aes_key = @rsa.private_decrypt rsa_encrypted_aes_key
      aes_iv  = @rsa.private_decrypt rsa_encrypted_aes_iv

      # 3
      @cipher.reset
      @cipher.decrypt
      @cipher.key = aes_key
      @cipher.iv  = aes_iv
      content = @cipher.update(aes_encrypted_message) + @cipher.final

      { signature: hmac, content: content }
    rescue OpenSSL::OpenSSLError => e
      raise Error.new(e.message)
    end
  end
end
