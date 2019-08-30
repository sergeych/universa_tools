# Universa KeyRecord. This structure is intended to hold small encrypted entity,
# usually a key to other, big encrypted entity. KeyRecord maximum plaintext size is small,
# so everything that could be large than say 128 bytes should be encrypted using a key stored
# as plaintext in the KR.
#
# This class is not directly instantiable, use one of its ancestors, like KeyRecordPbkdf2, or decode packed
# binary record.
class KeyRecord


  # Unpack single KeyRecord packed into binary form.
  def self.from_packed packed
    decode_array(Boss.load(packed))
  end

  # Unpack array of key records
  def self.unpack_all(packed_records)
    Boss.load(packed_records).map { |array| decode_array(array) }
  end

  # Pack a self in binary form, this is different from pack_all/unpack_all.
  # @return [Binary] stinrg with encoded key record
  def pack
    Boss.pack(serialized)
  end

  # Pack many key records into single binary packed form. To unpack it ise {unpack_all}
  #
  # @param [Array(KeyRecord)] records to pack
  # @return [Binary] binary packed string.
  def self.pack_all(records)
    # hack: we call private method, we do not want to make it public
    Boss.pack(records.map{ |x| x.send :serialized})
  end

  protected

  def initialize(code, ciphertext)
    @code, @ciphertext = code, ciphertext
    @code or raise ArgumentError, "code can't be nil"
  end

  def encrypt_with_key(key, plaintext)
    @ciphertext = key.etaEncrypt(plaintext).freeze
  end

  def serialized_params
    raise "implement serialized params"
  end

  private

  def serialized
    @ciphertext or raise IllegalStateError, "empty ciphertext, encrypt something first"
    [@code, serialized_params, @ciphertext].flatten
  end

  def self.decode_array(packed_array)
    code, *params, encpypted_key = *packed_array
    case code
      when 1
        KeyRecordPbkdf2.new(params, encpypted_key)
      else
        raise ArgumentError, "unknown KR code #{code}"
    end
  end

end

# PBKDF2 KeyRecord. Allow safely using passwords, carrying all necessary information to re-derive key later.
# Allow using only part of the PBKDF2 derived data as a key, so more than one key could be derived from the same
# password cryptographically safe and independently.
class KeyRecordPbkdf2 < KeyRecord

  HASH_CODES = [
      "com.icodici.crypto.digest.Sha256", # 0
  ]

  # Construct instance using PBKDF2 parameters or serialization parameters.
  def initialize(params = nil, encrypted_key = nil, salt: 'default_salt', rounds: 500000, key_length: 32, offset: 0, length: 32, hint: nil, hash_code: 0)
    if params
      @salt_bytes, @rounds, @key_length, @offset, @length, @password_hint, @hash_code = *params
    else
      @salt_bytes, @rounds, @key_length, @offset, @length, @password_hint, @hash_code =
          salt.force_encoding('binary'), rounds, key_length, offset, length, hint, hash_code
    end
    @salt_bytes&.freeze
    @hash = HASH_CODES[@hash_code] or raise ArgumentError, "invalid hash code #{hash_code}"
    super 1, encrypted_key
  end

  # Encrypt plaintext deriving key from a given password
  # @return [KeyRecordPbkdf2] self
  def encrypt(password, plaintext)
    plaintext = plaintext.force_encoding('binary')
    encrypt_with_key(derive_key(password), plaintext)
    self
  end

  # Decrypt the contained ciphertext deriving a key from a given password
  #
  # @param [String] password to derive key from
  # @return [Binary] binary string for the decrypted data
  def decrypt(password)
    @ciphertext or raise IllegalStateError, "missing ciphertext"
    derive_key(password).eta_decrypt(@ciphertext)
  end

  protected

  def derive_key(password)
    # UMI bridge does not go well with frozen strings
    @salt_bytes.frozen? and @salt_bytes = @salt_bytes[0..]
    data = Universa::PBKDF2.derive(password, salt: @salt_bytes, rounds: @offset, hash: @hash.clone, length: @key_length)
    Universa::SymmetricKey.new(data[@offset...(@offset + @length)])
  end

  def serialized_params
    [@salt_bytes, @rounds, @key_length, @offset, @length, @password_hint, @hash_code]
  end

end
