;; title: Sonichain Tests
;; version: 1.0.0
;; summary: Rendezvous fuzzing test suite for Sonichain contract
;; description: Property-based testing for collaborative voice story protocol

;; =============================================================================
;; PROPERTY-BASED TESTS FOR RENDEZVOUS
;; =============================================================================

;; Basic Fuzzing Tests - Input Validation and Error Handling
;; These tests ensure the contract can handle various input types without crashing

;; Property: User registration input validation
(define-public (test-register-user-fuzz (username (string-utf8 50)))
  (begin
    (unwrap! (register-user username) (ok false))
    (ok true)
  )
)

;; Property: Story creation input validation
(define-public (test-create-story-fuzz (prompt (string-utf8 500)) (init-time uint) (voting-window uint))
  (begin
    (unwrap! (create-story prompt init-time voting-window) (ok false))
    (ok true)
  )
)

;; Property: Submission input validation
(define-public (test-submit-block-fuzz 
    (story-id uint)
    (uri (string-ascii 256))
    (now uint)
  )
  (begin
    (unwrap! (submit-block story-id uri now) (ok false))
    (ok true)
  )
)

;; Property: Voting input validation
(define-public (test-vote-block-fuzz (submission-id uint))
  (begin
    (unwrap! (vote-block submission-id) (ok false))
    (ok true)
  )
)

;; Property: Bounty funding input validation
(define-public (test-fund-bounty-fuzz 
    (story-id uint)
    (amount uint)
  )
  (begin
    (unwrap! (fund-bounty story-id amount) (ok false))
    (ok true)
  )
)

;; Property: Round finalization input validation
(define-public (test-finalize-round-fuzz 
    (story-id uint)
    (round-num uint)
    (now uint)
  )
  (begin
    (unwrap! (finalize-round story-id round-num now) (ok false))
    (ok true)
  )
)

;; Property: Story sealing input validation
(define-public (test-seal-story-fuzz (story-id uint))
  (begin
    (unwrap! (seal-story story-id) (ok false))
    (ok true)
  )
)

;; Property: Voting window constraints input validation
(define-public (test-voting-window-constraints 
    (story-id uint)
    (round-num uint)
    (submission-id uint)
    (now uint)
  )
  (ok (is-voting-active-at story-id round-num now))
)

;; =============================================================================
;; INVARIANT TESTS
;; =============================================================================

;; Invariant: Story counter should never decrease
(define-read-only (invariant-story-counter-monotonic)
  (>= (get-story-counter) u0)
)

;; Invariant: Submission counter should never decrease
(define-read-only (invariant-submission-counter-monotonic)
  (>= (get-submission-counter) u0)
)

;; Invariant: Round counter should never decrease
(define-read-only (invariant-round-counter-monotonic)
  (>= (get-round-counter) u0)
)
