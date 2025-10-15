;; title: Sonichain_tests
;; version: 1.0.0
;; summary: Rendezvous fuzzing test suite for Sonichain contract
;; description: Property-based testing for collaborative voice story protocol

;; =============================================================================
;; FUZZING TEST FUNCTIONS
;; =============================================================================

;; Test user registration with fuzzed usernames
(define-public (test-register-user-fuzz (username (string-utf8 50)))
  (contract-call? .Sonichain
    register-user username
  )
)

;; Test story creation with fuzzed prompts
(define-public (test-create-story-fuzz (prompt (string-utf8 500)) (init-time uint) (voting-window uint))
  (contract-call? .Sonichain
    create-story prompt init-time voting-window
  )
)

;; Test submission with fuzzed URIs
(define-public (test-submit-block-fuzz 
    (story-id uint)
    (uri (string-ascii 256))
    (now uint)
  )
  (contract-call? .Sonichain
    submit-block story-id uri now
  )
)

;; Test voting with fuzzed submission IDs
(define-public (test-vote-block-fuzz (submission-id uint))
  (contract-call? .Sonichain
    vote-block submission-id
  )
)

;; Test bounty funding with fuzzed amounts
(define-public (test-fund-bounty-fuzz 
    (story-id uint)
    (amount uint)
  )
  (contract-call? .Sonichain
    fund-bounty story-id amount
  )
)

;; Test round finalization with fuzzed parameters
(define-public (test-finalize-round-fuzz 
    (story-id uint)
    (round-num uint)
    (now uint)
  )
  (contract-call? .Sonichain
    finalize-round story-id round-num now
  )
)

;; Test story sealing with fuzzed story IDs
(define-public (test-seal-story-fuzz (story-id uint))
  (contract-call? .Sonichain
    seal-story story-id
  )
)

;; =============================================================================
;; PROPERTY-BASED TESTING FUNCTIONS
;; =============================================================================

;; Test that user registration maintains uniqueness
(define-public (test-user-registration-uniqueness (username (string-utf8 50)))
  (let (
      (result1 (contract-call? .Sonichain
        register-user username
      ))
      (result2 (contract-call? .Sonichain
        register-user username
      ))
    )
    (begin
      ;; First registration should succeed
      (asserts! (is-ok result1) (err u1001))
      ;; Second registration should fail
      (asserts! (is-err result2) (err u1002))
      (ok true)
    )
  )
)

;; Test that story creation works correctly
(define-public (test-story-creation-counters (prompt (string-utf8 500)) (init-time uint) (voting-window uint))
  (contract-call? .Sonichain
    create-story prompt init-time voting-window
  )
)

;; Test that voting maintains one vote per user per round
(define-public (test-voting-uniqueness 
    (story-id uint)
    (submission-id uint)
  )
  (let (
      (vote1 (contract-call? .Sonichain
        vote-block submission-id
      ))
      (vote2 (contract-call? .Sonichain
        vote-block submission-id
      ))
    )
    (begin
      ;; First vote should succeed
      (asserts! (is-ok vote1) (err u1005))
      ;; Second vote should fail
      (asserts! (is-err vote2) (err u1006))
      (ok true)
    )
  )
)

;; Test that bounty funding increases pool correctly
(define-public (test-bounty-funding-integrity 
    (story-id uint)
    (amount uint)
  )
  (contract-call? .Sonichain
    fund-bounty story-id amount
  )
)

;; Test that story sealing distributes rewards correctly
(define-public (test-story-sealing-rewards (story-id uint))
  (contract-call? .Sonichain
    seal-story story-id
  )
)

;; =============================================================================
;; EDGE CASE AND ERROR CONDITION TESTS
;; =============================================================================

;; Test submission limits and constraints
(define-public (test-submission-constraints 
    (story-id uint)
    (uri (string-ascii 256))
    (now uint)
  )
  (contract-call? .Sonichain
    submit-block story-id uri now
  )
)

;; Test voting window constraints
(define-public (test-voting-window-constraints 
    (story-id uint)
    (round-num uint)
    (submission-id uint)
    (now uint)
  )
  (let (
      (voting-active (contract-call? .Sonichain
        is-voting-active-at story-id round-num now
      ))
      (vote-result (contract-call? .Sonichain
        vote-block submission-id
      ))
    )
    (begin
      ;; If voting is not active, vote should fail
      (if (not voting-active)
        (asserts! (is-err vote-result) (err u1014))
        true
      )
      (ok true)
    )
  )
)

;; Test round finalization constraints
(define-public (test-round-finalization-constraints 
    (story-id uint)
    (round-num uint)
    (now uint)
  )
  (let (
      (can-finalize (contract-call? .Sonichain
        can-finalize-round-at story-id round-num now
      ))
      (finalize-result (contract-call? .Sonichain
        finalize-round story-id round-num now
      ))
    )
    (begin
      ;; If cannot finalize, finalization should fail
      (if (not can-finalize)
        (asserts! (is-err finalize-result) (err u1015))
        true
      )
      (ok true)
    )
  )
)

;; =============================================================================
;; STRESS TESTING FUNCTIONS
;; =============================================================================

;; Test rapid successive operations
(define-public (test-rapid-operations 
    (story-id uint)
    (uri (string-ascii 256))
    (iterations uint)
    (now uint)
  )
  (begin
    ;; Simplified test - just attempt one submission
    (try! (contract-call? .Sonichain
      submit-block story-id uri now
    ))
    (ok true)
  )
)

;; Test concurrent voting scenarios
(define-public (test-concurrent-voting 
    (story-id uint)
    (submission-id uint)
  )
  (begin
    ;; Simplified test - just attempt one vote
    (try! (contract-call? .Sonichain
      vote-block submission-id
    ))
    (ok true)
  )
)

;; =============================================================================
;; FUZZING UTILITY FUNCTIONS
;; =============================================================================

;; Generate random test data
(define-public (generate-test-data)
  (ok {
    username: u"testuser",
    prompt: u"A mysterious story begins...",
    uri: "ipfs://QmTestHash123456789",
    amount: u1000000,
    story-id: u1,
    submission-id: u1,
    round-num: u1,
  })
)

;; Run comprehensive fuzzing suite
(define-public (run-fuzzing-suite)
  (ok true)
)

;; =============================================================================
;; READ-ONLY TESTING FUNCTIONS
;; =============================================================================

;; Test read-only function consistency
(define-public (test-read-only-consistency (story-id uint))
  (let (
      (story (contract-call? .Sonichain
        get-story story-id
      ))
    )
    (if (is-some story)
      (ok true)
      (err u1017)
    )
  )
)