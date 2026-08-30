package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"sync"
	"time"

	_ "github.com/go-sql-driver/mysql"

	"golang.org/x/crypto/pbkdf2"
)

type Response struct {
	Success  bool   `json:"success"`
	Message  string `json:"message,omitempty"`
	TimeLeft string `json:"timeLeft,omitempty"`
}

// Authentication key material is intentionally not distributed with the public project.

const (
	pbkdf2Iterations = 100000
	pbkdf2KeyLen     = 32
)

// Database credentials and deployment configuration must be supplied by the operator.

type rateLimiter struct {
	limiter  *limiter
	lastSeen time.Time
}

type limiter struct {
	tokens      int
	lastRefill  time.Time
	refillRate  int
	capacity    int
	refillMutex sync.Mutex
}

var (
	clients = make(map[string]*rateLimiter)
	mu      sync.Mutex
)

func newLimiter(capacity int, refillRate int) *limiter {
	return &limiter{
		tokens:     capacity,
		lastRefill: time.Now(),
		refillRate: refillRate,
		capacity:   capacity,
	}
}

func (l *limiter) allow() bool {
	l.refillMutex.Lock()
	defer l.refillMutex.Unlock()

	now := time.Now()
	elapsed := now.Sub(l.lastRefill).Seconds()
	refill := int(elapsed * float64(l.refillRate))
	if refill > 0 {
		l.tokens += refill
		if l.tokens > l.capacity {
			l.tokens = l.capacity
		}
		l.lastRefill = now
	}

	if l.tokens > 0 {
		l.tokens--
		return true
	}

	return false
}

func getRateLimiter(ip string) *limiter {
	mu.Lock()
	defer mu.Unlock()

	if rl, exists := clients[ip]; exists {
		rl.lastSeen = time.Now()
		return rl.limiter
	}

	l := newLimiter(5, 1)
	clients[ip] = &rateLimiter{limiter: l, lastSeen: time.Now()}
	return l
}

func cleanupRateLimiters() {
	for {
		time.Sleep(time.Minute)
		mu.Lock()
		for ip, rl := range clients {
			if time.Since(rl.lastSeen) > 5*time.Minute {
				delete(clients, ip)
				// log.Printf("Rate limiter for IP %s cleaned up due to inactivity.", ip)
			}
		}
		mu.Unlock()
	}
}

func main() {
	// TODO: Implement your own backend configuration, protected secret loading,
	// TLS termination, database connection, and HTTP listener before deployment.
}

func rateLimitMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ip := getIPAddress(r)
		limiter := getRateLimiter(ip)
		if !limiter.allow() {
			// log.Printf("Rate limit exceeded for IP: %s", ip)
			http.Error(w, "Too Many Requests", http.StatusTooManyRequests)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// Helper function to get IP address
/* func getIPAddress(r *http.Request) string {
    ip := r.Header.Get("X-Real-IP")
    if ip == "" {
        ip = r.Header.Get("")
    }
    if ip == "" {
        ip = strings.Split(r.RemoteAddr, ":")[0]
    }
    // log.Printf("Incoming request from IP: %s", ip)
    return ip
} */
func getIPAddress(r *http.Request) string {
	// TODO: Implement request-address handling for your own trusted proxy topology.
	return ""
}

func verifyAndUpdateKey(db *sql.DB, key string, udid string) (string, bool, bool, error) {
	var dbUDID sql.NullString
	var endTime sql.NullTime
	var blockStatus int

	tx, err := db.Begin()
	if err != nil {
		// log.Printf("Transaction begin error: %v", err)
		return "0", false, false, err
	}
	defer tx.Rollback()

	query := "SELECT UDID, `END`, `BLOCK` FROM `FOZU` WHERE `KEY` = ? FOR UPDATE"
	err = tx.QueryRow(query, key).Scan(&dbUDID, &endTime, &blockStatus)
	if err != nil {
		if err == sql.ErrNoRows {
			// log.Printf("No entry found for KEY: %s", key)
			return "0", false, false, nil
		}
		// log.Printf("Database query error for KEY %s: %v", key, err)
		return "0", false, false, err
	}

	if blockStatus == 1 {
		// log.Printf("Access blocked for KEY: %s", key)
		return "0", true, true, nil
	}

	if !dbUDID.Valid || dbUDID.String == "" {
		updateQuery := "UPDATE `FOZU` SET `UDID` = ?, `START` = NOW() WHERE `KEY` = ?"
		_, err = tx.Exec(updateQuery, udid, key)
		if err != nil {
			// log.Printf("Failed to set UDID and update START for KEY %s: %v", key, err)
			return "0", false, false, err
		}
		// log.Printf("UDID set to %s and START updated for KEY %s", udid, key)
	} else {
		if dbUDID.String != udid {
			// log.Printf("UDID mismatch for KEY %s: expected %s, got %s", key, dbUDID.String, udid)
			return "0", false, false, nil
		}

		updateQuery := "UPDATE `FOZU` SET `START` = NOW() WHERE `KEY` = ?"
		_, err = tx.Exec(updateQuery, key)
		if err != nil {
			// log.Printf("Failed to update START for KEY %s: %v", key, err)
			return "0", false, false, err
		}
		// log.Printf("START updated for KEY %s", key)
	}

	if err := tx.Commit(); err != nil {
		// log.Printf("Transaction commit error: %v", err)
		return "0", false, false, err
	}

	if !endTime.Valid {
		// log.Printf("END time is NULL for KEY %s", key)
		return "0", true, false, nil
	}

	now := time.Now()
	if endTime.Time.Before(now) {
		return "0", true, false, nil
	}

	duration := endTime.Time.Sub(now)
	timeLeft := formatDuration(duration)
	return timeLeft, true, false, nil
}

type checkReq struct {
	Index int    `json:"index"`
	Data  string `json:"data"`
}

func handleCheck(w http.ResponseWriter, r *http.Request, db *sql.DB) {
	// TODO: Implement your own authenticated request protocol and key management.
}

func respondEncryptedJSON(w http.ResponseWriter, resp Response, key []byte) {
	jsonData, err := json.Marshal(resp)
	if err != nil {
		// log.Printf("JSON Marshal error: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
	// log.Printf("Response JSON before encryption: %s", string(jsonData))

	ciphertext, err := EncryptPayloadWithKey(string(jsonData), key)
	if err != nil {
		// log.Printf("Encryption failed: %v", err)
		http.Error(w, "Encryption Failed", http.StatusInternalServerError)
		return
	}
	// log.Printf("Encrypted response (hex): %x", ciphertext)

	encodedCiphertext := base64.StdEncoding.EncodeToString(ciphertext)
	// log.Printf("Encrypted response base64: %s", encodedCiphertext)

	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(encodedCiphertext))
	log.Println("Encrypted response sent to client")
}

func formatDuration(d time.Duration) string {
	days := int(d.Hours()) / 24
	hours := int(d.Hours()) % 24
	minutes := int(d.Minutes()) % 60
	seconds := int(d.Seconds()) % 60
	return fmt.Sprintf("%d Days, %dh, %dm, %ds", days, hours, minutes, seconds)
}

func PKCS(S, KEY, UDID string, Iterate int) []byte {
	// log.Printf("PBKDF2 Salt (hex): %x", []byte(KEY+UDID))
	derivedKey := pbkdf2.Key([]byte(S), []byte(KEY+UDID), Iterate, pbkdf2KeyLen, sha256.New)
	// log.Printf("PBKDF2 Derived Key (hex): %x", derivedKey)
	return derivedKey
}

func GEAK(DerivedKey []byte, KEY, UDID string) string {
	message := KEY + UDID
	// log.Printf("HMAC Message: %s", message)
	mac := hmac.New(sha256.New, DerivedKey)
	mac.Write([]byte(message))
	hmacBytes := mac.Sum(nil)
	// log.Printf("Generated HMAC (bytes): %x", hmacBytes)
	return base64.StdEncoding.EncodeToString(hmacBytes)
}

func EncryptPayloadWithKey(plaintext string, key []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		// log.Printf("AES NewCipher error: %v", err)
		return nil, err
	}

	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		// log.Printf("AES GCM error: %v", err)
		return nil, err
	}

	nonce := make([]byte, aesGCM.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		// log.Printf("Nonce generation error: %v", err)
		return nil, err
	}
	// log.Printf("Generated Nonce (hex): %x", nonce)

	ciphertext := aesGCM.Seal(nonce, nonce, []byte(plaintext), nil)
	// log.Printf("Ciphertext (hex): %x", ciphertext)
	return ciphertext, nil
}

func DecryptPayloadWithKey(ciphertext []byte, key []byte) (string, error) {
	// log.Printf("Ciphertext received (hex): %x", ciphertext)

	block, err := aes.NewCipher(key)
	if err != nil {
		// log.Printf("AES NewCipher error: %v", err)
		return "", err
	}

	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		// log.Printf("AES GCM error: %v", err)
		return "", err
	}

	nonceSize := aesGCM.NonceSize()
	if len(ciphertext) < nonceSize+16 {
		// log.Printf("Ciphertext too short: length %d", len(ciphertext))
		return "", fmt.Errorf("ciphertext too short")
	}

	nonce, ciphertextData := ciphertext[:nonceSize], ciphertext[nonceSize:]
	// log.Printf("Extracted Nonce (hex): %x", nonce)
	// log.Printf("Ciphertext Data (hex): %x", ciphertextData)

	plaintext, err := aesGCM.Open(nil, nonce, ciphertextData, nil)
	if err != nil {
		// log.Printf("AES GCM decryption error: %v", err)
		return "", err
	}

	// log.Printf("Decrypted Plaintext: %s", string(plaintext))
	return string(plaintext), nil
}
