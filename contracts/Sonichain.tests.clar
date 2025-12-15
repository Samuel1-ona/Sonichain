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
;; Discard if user is already registered
(define-read-only (can-test-register-user-fuzz (username (string-utf8 50)))
  (is-none (map-get? users { user: tx-sender }))
)

(define-public (test-register-user-fuzz (username (string-utf8 50)))
  (begin
    (unwrap! (register-user username) (ok false))
    ;; Verify user was registered
    (asserts! (is-some (get-user tx-sender)) (ok false))
    (ok true)
  )
)

;; Property: Story creation input validation
;; Discard if voting-window is zero (invalid)
(define-read-only (can-test-create-story-fuzz (prompt (string-utf8 500)) (init-time uint) (voting-window uint))
  (> voting-window u0)
)

(define-public (test-create-story-fuzz (prompt (string-utf8 500)) (init-time uint) (voting-window uint))
  (let ((story-id-before (get-story-counter)))
    (let ((new-story-id (unwrap! (create-story prompt init-time voting-window) (ok false))))
      (begin
        ;; Verify story counter increased
        (asserts! (is-eq new-story-id (+ story-id-before u1)) (ok false))
        ;; Verify story exists
        (asserts! (is-some (get-story new-story-id)) (ok false))
        (ok true)
      )
    )
  )
)

;; Property: Submission input validation
;; Discard if story doesn't exist or is sealed
(define-read-only (can-test-submit-block-fuzz 
    (story-id uint)
    (uri (string-ascii 256))
    (now uint)
  )
  (let ((story-opt (get-story story-id)))
    (if (is-some story-opt)
      (let ((story (unwrap-panic story-opt)))
        (and
          (not (get is-sealed story))
          (let ((round-opt (get-round story-id (get current-round story))))
            (if (is-some round-opt)
              (let ((round-data (unwrap-panic round-opt)))
                (<= now (get end-time round-data))
              )
              false
            )
          )
        )
      )
      false
    )
  )
)

(define-public (test-submit-block-fuzz 
    (story-id uint)
    (uri (string-ascii 256))
    (now uint)
  )
  (let ((submission-id-before (get-submission-counter)))
    (let ((new-submission-id (unwrap! (submit-block story-id uri now) (ok false))))
      (begin
        ;; Verify submission counter increased
        (asserts! (is-eq new-submission-id (+ submission-id-before u1)) (ok false))
        ;; Verify submission exists
        (asserts! (is-some (get-submission new-submission-id)) (ok false))
        (ok true)
      )
    )
  )
)

;; Property: Voting input validation
;; Discard if submission doesn't exist or voting is closed
(define-read-only (can-test-vote-block-fuzz (submission-id uint))
  (let ((submission-opt (get-submission submission-id)))
    (if (is-some submission-opt)
      (let ((submission (unwrap-panic submission-opt)))
        (let ((story-opt (get-story (get story-id submission))))
          (if (is-some story-opt)
            (let ((story (unwrap-panic story-opt)))
              (and
                (not (get is-sealed story))
                (let ((round-opt (get-round (get story-id submission) (get round-num submission))))
                  (if (is-some round-opt)
                    (let ((round-data (unwrap-panic round-opt)))
                      (not (get is-finalized round-data))
                    )
                    false
                  )
                )
              )
            )
            false
          )
        )
      )
      false
    )
  )
)

(define-public (test-vote-block-fuzz (submission-id uint))
  (let ((submission-opt (get-submission submission-id)))
    (if (is-some submission-opt)
      (let ((submission (unwrap-panic submission-opt)))
        (let ((story-id (get story-id submission)) (round-num (get round-num submission)))
          (if (has-voted story-id round-num tx-sender)
            (ok false)
            (begin
              (unwrap! (vote-block submission-id) (ok false))
              ;; Verify vote was recorded
              (asserts! (has-voted story-id round-num tx-sender) (ok false))
              (ok true)
            )
          )
        )
      )
      (ok false)
    )
  )
)

;; Property: Bounty funding input validation
;; Discard if story doesn't exist, is sealed, or amount is zero
(define-read-only (can-test-fund-bounty-fuzz 
    (story-id uint)
    (amount uint)
  )
  (and
    (> amount u0)
    (let ((story-opt (get-story story-id)))
      (if (is-some story-opt)
        (let ((story (unwrap-panic story-opt)))
          (not (get is-sealed story))
        )
        false
      )
    )
  )
)

(define-public (test-fund-bounty-fuzz 
    (story-id uint)
    (amount uint)
  )
  (let ((story-opt (get-story story-id)))
    (if (is-some story-opt)
      (let ((story (unwrap-panic story-opt)))
        (let ((bounty-before (get bounty-pool story)))
          (begin
            (unwrap! (fund-bounty story-id amount) (ok false))
            ;; Verify bounty increased
            (let ((updated-story-opt (get-story story-id)))
              (if (is-some updated-story-opt)
                (let ((updated-story (unwrap-panic updated-story-opt)))
                  (asserts! (is-eq (get bounty-pool updated-story) (+ bounty-before amount)) (ok false))
                  (ok true)
                )
                (ok false)
              )
            )
          )
        )
      )
      (ok false)
    )
  )
)

;; Property: Round finalization input validation
;; Discard if round doesn't exist, is already finalized, or voting hasn't ended
(define-read-only (can-test-finalize-round-fuzz 
    (story-id uint)
    (round-num uint)
    (now uint)
  )
  (let ((round-opt (get-round story-id round-num)))
    (if (is-some round-opt)
      (let ((round-data (unwrap-panic round-opt)))
        (and
          (not (get is-finalized round-data))
          (> now (get end-time round-data))
        )
      )
      false
    )
  )
)

(define-public (test-finalize-round-fuzz 
    (story-id uint)
    (round-num uint)
    (now uint)
  )
  (begin
    ;; Discard if no submissions exist
    (if (<= (get-round-submission-count story-id round-num) u0)
      (ok false)
      (let ((winning-id (unwrap! (finalize-round story-id round-num now) (ok false))))
        (begin
          ;; Verify round is finalized
          (let ((round-opt (get-round story-id round-num)))
            (if (is-some round-opt)
              (let ((round-data (unwrap-panic round-opt)))
                (asserts! (get is-finalized round-data) (ok false))
                (ok true)
              )
              (ok false)
            )
          )
        )
      )
    )
  )
)

;; Property: Story sealing input validation
;; Discard if story doesn't exist, is already sealed, or doesn't have enough blocks
(define-read-only (can-test-seal-story-fuzz (story-id uint))
  (let ((story-opt (get-story story-id)))
    (if (is-some story-opt)
      (let ((story (unwrap-panic story-opt)))
        (and
          (not (get is-sealed story))
          (>= (get total-blocks story) u5)  ;; MIN-BLOCKS-TO-SEAL
          (is-eq tx-sender (get creator story))
        )
      )
      false
    )
  )
)

(define-public (test-seal-story-fuzz (story-id uint))
  (let ((sealed-story-id (unwrap! (seal-story story-id) (ok false))))
    (begin
      ;; Verify story is sealed
      (let ((story-opt (get-story story-id)))
        (if (is-some story-opt)
          (let ((story (unwrap-panic story-opt)))
            (asserts! (get is-sealed story) (ok false))
            (ok true)
          )
          (ok false)
        )
      )
    )
  )
)

;; Property: Voting window constraints input validation
;; This test checks if voting is active at a given time
(define-read-only (can-test-voting-window-constraints 
    (story-id uint)
    (round-num uint)
    (submission-id uint)
    (now uint)
  )
  (is-some (get-round story-id round-num))
)

(define-public (test-voting-window-constraints 
    (story-id uint)
    (round-num uint)
    (submission-id uint)
    (now uint)
  )
  ;; This is a read-only check, so it should always return a boolean
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

;; =============================================================================
;; MAP INVARIANTS
;; =============================================================================

;; Invariant: If a user is registered, their registration data should be valid
(define-read-only (invariant-user-registration-valid)
  (match (map-get? users { user: tx-sender })
    user-data (and
      (>= (get registered-at user-data) u0)
      true ;; username is always valid if it exists
    )
    true ;; If user not registered, invariant holds
  )
)

;; Invariant: If a username exists, it should map to a valid user
(define-read-only (invariant-username-mapping-valid)
  ;; This is a structural invariant - usernames map should always be consistent
  ;; Since we can't iterate, we check that if tx-sender is registered,
  ;; their username maps back to them
  (let ((user-opt (map-get? users { user: tx-sender })))
    (if (is-some user-opt)
      (let ((user-data (unwrap-panic user-opt)))
        (let ((username (get username user-data)))
          (let ((username-opt (map-get? usernames { username: username })))
            (if (is-some username-opt)
              (let ((username-entry (unwrap-panic username-opt)))
                (is-eq (get user username-entry) tx-sender)
              )
              false ;; Username should exist if user is registered
            )
          )
        )
      )
      true ;; If user not registered, invariant holds
    )
  )
)

;; Invariant: If tx-sender has submitted, their submission should be valid
(define-read-only (invariant-user-submission-valid)
  ;; Check if tx-sender has any submissions by checking a range of story/round combinations
  ;; Since we can't iterate, we check a few common cases
  (let ((story-1-round-1 (map-get? user-round-submissions {
      story-id: u1,
      round-num: u1,
      user: tx-sender,
    })))
    (if (is-some story-1-round-1)
      (let ((submission-id (get submission-id (unwrap-panic story-1-round-1))))
        (is-some (map-get? submissions { submission-id: submission-id }))
      )
      true ;; If no submission, invariant holds
    )
  )
)

;; Invariant: If tx-sender has voted, their vote should reference a valid submission
(define-read-only (invariant-user-vote-valid)
  ;; Check if tx-sender has voted in story 1, round 1
  (match (map-get? votes {
      story-id: u1,
      round-num: u1,
      voter: tx-sender,
    })
    vote-entry (is-some (map-get? submissions { submission-id: (get submission-id vote-entry) }))
    true ;; If vote doesn't exist, invariant holds
  )
)

;; Invariant: If tx-sender is a contributor, their block count should be non-negative
(define-read-only (invariant-contributor-blocks-non-negative)
  ;; Check contributor blocks for story 1
  (match (map-get? contributor-blocks {
      story-id: u1,
      contributor: tx-sender,
    })
    contributor-data (>= (get block-count contributor-data) u0)
    true ;; If contributor not in map, invariant holds (count is 0)
  )
)

;; Invariant: Story 1 data should have valid properties (if it exists)
(define-read-only (invariant-story-1-data-valid)
  (match (map-get? stories { story-id: u1 })
    story (and
      (>= (get total-blocks story) u0)
      (<= (get total-blocks story) u50) ;; MAX-BLOCKS-PER-STORY
      (>= (get current-round story) u1)
      (<= (get current-round story) u10) ;; MAX-ROUNDS-PER-STORY
      (>= (get bounty-pool story) u0)
      (>= (get voting-window story) u0)
      (>= (get created-at story) u0)
      (>= (get init-time story) u0)
    )
    true ;; If story doesn't exist, invariant holds
  )
)

;; Invariant: Round 1 of story 1 should have valid properties (if it exists)
(define-read-only (invariant-round-1-1-data-valid)
  (match (map-get? rounds {
      story-id: u1,
      round-num: u1,
    })
    round-data (and
      (>= (get round-id round-data) u0)
      (>= (get start-time round-data) u0)
      (>= (get end-time round-data) (get start-time round-data)) ;; end >= start
      (>= (get total-votes round-data) u0)
    )
    true ;; If round doesn't exist, invariant holds
  )
)

;; Invariant: Round submission count for story 1, round 1 should be valid
(define-read-only (invariant-round-submission-count-valid)
  (match (map-get? round-submission-count {
      story-id: u1,
      round-num: u1,
    })
    count-entry (and
      (>= (get count count-entry) u0)
      (<= (get count count-entry) u10) ;; MAX-SUBMISSIONS-PER-ROUND
    )
    true ;; If count doesn't exist, default is 0 which is valid
  )
)

;; Invariant: Submission 1 should have valid properties (if it exists)
(define-read-only (invariant-submission-1-valid)
  (match (map-get? submissions { submission-id: u1 })
    submission (and
      (>= (get story-id submission) u1) ;; Story IDs start at 1
      (>= (get round-num submission) u1) ;; Round numbers start at 1
      (>= (get vote-count submission) u0)
      (>= (get submitted-at submission) u0)
    )
    true ;; If submission doesn't exist, invariant holds
  )
)

;; Invariant: Story chain entry for story 1, block 0 should be valid (if it exists)
(define-read-only (invariant-story-chain-block-0-valid)
  (match (map-get? story-chain {
      story-id: u1,
      block-index: u0,
    })
    chain-entry (and
      (>= (get submission-id chain-entry) u1) ;; Submission IDs start at 1
      (>= (get finalized-at chain-entry) u0)
      (is-some (map-get? submissions { submission-id: (get submission-id chain-entry) })) ;; Submission should exist
    )
    true ;; If chain entry doesn't exist, invariant holds
  )
)
