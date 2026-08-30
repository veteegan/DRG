/*

Mein Kampf with Cheat Crackers
Jawohl bruderherz
Heil The Encryption
An die at Front!

*/

#include "ProcessFront.h"

#include "openssl/evp.h"
#include "openssl/rand.h"
#include "openssl/sha.h"
#include "openssl/ssl.h"
#include "openssl/x509.h"
#include "openssl/x509_vfy.h"
#include "openssl/hmac.h"
#include "openssl/buffer.h"

#include "curl/curl.h"

#include "../Utilities/rapidjson/document.h"
#include "../Utilities/rapidjson/stringbuffer.h"
#include "../Utilities/rapidjson/writer.h"


// Authentication key material is intentionally not distributed with the public project.

bool EncryptPayload(const std::string& plaintext, std::string& ciphertext, const unsigned char* key) {
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) {
        //NSLog(@"[EncryptPayload] Failed to create EVP_CIPHER_CTX");
        return false;
    }

    unsigned char iv[12];
    if (!RAND_bytes(iv, sizeof(iv))) {
        //NSLog(@"[EncryptPayload] Failed to generate IV");
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    if (1 != EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL)) {
        //NSLog(@"[EncryptPayload] EVP_EncryptInit_ex failed");
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    if (1 != EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, sizeof(iv), NULL)) {
        //NSLog(@"[EncryptPayload] EVP_CIPHER_CTX_ctrl (SET_IVLEN) failed");
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    if (1 != EVP_EncryptInit_ex(ctx, NULL, NULL, key, iv)) { // Use the provided key
        //NSLog(@"[EncryptPayload] EVP_EncryptInit_ex (setting key and IV) failed");
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    std::vector<unsigned char> ciphertext_buf(plaintext.size());
    int len;
    if (1 != EVP_EncryptUpdate(ctx, ciphertext_buf.data(), &len, (unsigned char*)plaintext.c_str(), plaintext.size())) {
        //NSLog(@"[EncryptPayload] EVP_EncryptUpdate failed");
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }
    int ciphertext_len = len;

    if (1 != EVP_EncryptFinal_ex(ctx, ciphertext_buf.data() + len, &len)) {
        //NSLog(@"[EncryptPayload] EVP_EncryptFinal_ex failed");
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }
    ciphertext_len += len;

    unsigned char tag[16];
    if (1 != EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, sizeof(tag), tag)) {
        //NSLog(@"[EncryptPayload] EVP_CIPHER_CTX_ctrl (GET_TAG) failed");
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    EVP_CIPHER_CTX_free(ctx);

    ciphertext.assign((char*)iv, sizeof(iv));
    ciphertext.append((char*)ciphertext_buf.data(), ciphertext_len);
    ciphertext.append((char*)tag, sizeof(tag));

    //NSLog(@"[EncryptPayload] Encryption successful. Ciphertext length: %lu", ciphertext.length());

    return true;
}

bool DecryptPayload(const std::string& ciphertext, std::string& plaintext, const unsigned char* key) {
    if (ciphertext.size() < 12 + 16) { // IV + Tag
        //NSLog(@"[DecryptPayload] Ciphertext too short");
        return false;
    }

    const unsigned char* iv = (const unsigned char*)ciphertext.c_str();
    const unsigned char* tag = (const unsigned char*)(ciphertext.c_str() + ciphertext.size() - 16);
    const unsigned char* ciphertext_data = (const unsigned char*)(ciphertext.c_str() + 12);
    int ciphertext_len = ciphertext.size() - 12 - 16;

    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) {
        //NSLog(@"[DecryptPayload] Failed to create EVP_CIPHER_CTX");
        return false;
    }

    if (1 != EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL)) {
        //NSLog(@"[DecryptPayload] EVP_DecryptInit_ex failed");
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    if (1 != EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, 12, NULL)) {
        //NSLog(@"[DecryptPayload] EVP_CIPHER_CTX_ctrl (SET_IVLEN) failed");
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    if (1 != EVP_DecryptInit_ex(ctx, NULL, NULL, key, iv)) {
        //NSLog(@"[DecryptPayload] EVP_DecryptInit_ex (setting key and IV) failed");
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    std::vector<unsigned char> plaintext_buf(ciphertext_len);
    int len;
    if (1 != EVP_DecryptUpdate(ctx, plaintext_buf.data(), &len, ciphertext_data, ciphertext_len)) {
        //NSLog(@"[DecryptPayload] EVP_DecryptUpdate failed");
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }
    int plaintext_len = len;

    if (1 != EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, 16, (void*)tag)) {
        //NSLog(@"[DecryptPayload] EVP_CIPHER_CTX_ctrl (SET_TAG) failed");
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    int ret = EVP_DecryptFinal_ex(ctx, plaintext_buf.data() + len, &len);
    EVP_CIPHER_CTX_free(ctx);

    if (ret > 0) {
        plaintext.assign((char*)plaintext_buf.data(), plaintext_len + len);
        //NSLog(@"[DecryptPayload] Decryption successful. Plaintext length: %lu", plaintext.length());
        return true;
    } else {
        //NSLog(@"[DecryptPayload] Decryption failed");
        return false;
    }
}

std::string base64_decode(const std::string &encoded) {
    BIO *bio, *b64;
    int decodeLen = encoded.length();
    std::vector<char> buffer(decodeLen);

    bio = BIO_new_mem_buf(encoded.c_str(), -1);
    b64 = BIO_new(BIO_f_base64());
    bio = BIO_push(b64, bio);

    BIO_set_flags(bio, BIO_FLAGS_BASE64_NO_NL);

    int length = BIO_read(bio, buffer.data(), encoded.length());
    BIO_free_all(bio);

    return std::string(buffer.data(), length);
}

std::string base64_encode(const unsigned char* buffer, size_t length) {

    BIO *bio, *b64;
    BUF_MEM *bufferPtr;

    b64 = BIO_new(BIO_f_base64());
    bio = BIO_new(BIO_s_mem());
    bio = BIO_push(b64, bio);

    BIO_set_flags(bio, BIO_FLAGS_BASE64_NO_NL);
    BIO_write(bio, buffer, length);
    BIO_flush(bio);
    BIO_get_mem_ptr(bio, &bufferPtr);

    std::string encodedData(bufferPtr->data, bufferPtr->length);
    BIO_free_all(bio);

    return encodedData;
}

ApiResponse MeinKampf(const std::string& KEY, const std::string& UDID) {
    (void)KEY;
    (void)UDID;
    // TODO: Implement your own authentication transport, endpoint configuration,
    // key management, and TLS trust policy before enabling login.
    return {false, "Authentication is not configured", "0"};
}


// PBKDF2 Key Derivation
std::string PKCS(const std::string& S, const std::string& KEY, const std::string& UDID, const int Iterate) {
    //NSLog(@"[PKCS] Starting PBKDF2 key derivation");
    std::string saltStr = KEY + UDID;
    unsigned char derivedKey[32]; // 256 bit key

    //  PBKDF2 SHA-256
    if (!PKCS5_PBKDF2_HMAC(S.c_str(), S.length(),
                           (const unsigned char*)saltStr.c_str(), saltStr.length(),
                           Iterate, EVP_sha256(),
                           sizeof(derivedKey), derivedKey)) {
        //NSLog(@"[PKCS] PBKDF2 key derivation failed");
        throw std::runtime_error("PBKDF2 Key Derivation Failed");
    }

    //NSLog(@"[PKCS] PBKDF2 key derivation successful");
    return std::string(reinterpret_cast<char*>(derivedKey), sizeof(derivedKey));
}

// HMAC-SHA256
std::string GEAK(const std::string& DerivedKey, const std::string& KEY, const std::string& UDID) {
    //NSLog(@"[GEAK] Starting HMAC-SHA256 generation");
    std::string messageStr = KEY + UDID;
    unsigned char hmacDigest[SHA256_DIGEST_LENGTH];

    // HMAC-SHA256
    unsigned int len = 0;
    HMAC(EVP_sha256(),
         DerivedKey.c_str(), DerivedKey.length(),
         (unsigned char*)messageStr.c_str(), messageStr.length(),
         hmacDigest, &len);

    // Base64 Encode
    char base64Encoded[SHA256_DIGEST_LENGTH * 2];
    int encodedLen = EVP_EncodeBlock((unsigned char*)base64Encoded, hmacDigest, len);

    std::string encodedMAC(base64Encoded, encodedLen);
    //NSLog(@"[GEAK] HMAC-SHA256 generated and encoded");

    return encodedMAC;
}

std::string urlEncode(const std::string &value) {
    std::ostringstream escaped;
    escaped.fill('0');
    escaped << std::hex << std::uppercase;

    for (const auto &c : value) {
        if (isalnum(static_cast<unsigned char>(c)) || c == '-' || c == '_' || c == '.' || c == '~') {
            escaped << c;
        }
        else {
            escaped << '%' << std::setw(2) << int((unsigned char)c);
        }
    }

    return escaped.str();
}



