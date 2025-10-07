;; Sonichain - Collaborative Voice Story Protocol
;; A decentralized story-building game where players contribute voice memos
;; to create evolving narrative chains with voting consensus and rewards.

;; =============================================================================
;; CONSTANTS & ERROR CODES
;; =============================================================================

(use-trait nft-tokens 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; Error codes
(define-constant ERR-NOT-FOUND (err u100))        ;; requested entity does not exist
(define-constant ERR-UNAUTHORIZED (err u101))     ;; caller is not allowed to perform the operation
(define-constant ERR-STORY-SEALED (err u102))     ;; story is sealed or action would seal-bypass
(define-constant ERR-ALREADY-VOTED (err u103))    ;; voter already voted in the given round
(define-constant ERR-NO-SUBMISSIONS (err u104))    ;; no submissions available to select a winner
(define-constant ERR-INSUFFICIENT-BLOCKS (err u105))  ;; not enough finalized blocks to seal
(define-constant ERR-INVALID-AMOUNT (err u106))    ;; invalid amount (e.g., zero) for bounty funding
(define-constant ERR-TRANSFER-FAILED (err u107))   ;; token/STX transfer failure
(define-constant ERR-VOTING-CLOSED (err u108))     ;; voting window has closed or not active.
(define-constant ERR-ALREADY-FINALIZED (err u109)) ;; round already finalized
(define-constant ERR-VOTING-NOT-ENDED (err u110))  ;; cannot finalize before round end
(define-constant ERR-ALREADY-SUBMITTED (err u111)) ;; user already submitted in this round
(define-constant ERR-USERNAME-EXISTS (err u112)) ;; username already taken
(define-constant ERR-USER-ALREADY-REGISTERED (err u113)) ;; user already registered

;; Configuration
(define-constant CONTRACT-OWNER tx-sender)
(define-constant VOTING-PERIOD u144) ;; number of blocks the round stays open for voting.
(define-constant MIN-BLOCKS-TO-SEAL u5) ;;minimum finalized blocks required to seal a story.
(define-constant MAX-BLOCKS-PER-STORY u50) ;; hard cap on blocks in a story.
(define-constant PLATFORM-FEE-BPS u250) ;; platform fee in basis points taken from bounty on sealing.

;; =============================================================================
;; DATA STRUCTURES
;; =============================================================================

;; Global counters
(define-data-var story-counter uint u0)    ;; counter for story-id
(define-data-var submission-counter uint u0) ;; counter for submission-id
(define-data-var round-counter uint u0)      ;; counter for round-id

;; Story metadata
(define-map stories
  { story-id: uint }
  {
    prompt: (string-utf8 500),     ;; story prompt
    creator: principal,             ;; creator of the story
    is-sealed: bool,                ;; whether the story is sealed
    created-at: uint,              ;; block height when story was created
    total-blocks: uint,            ;; total blocks in the story
    bounty-pool: uint,             ;; bounty pool for the story
    current-round: uint,            ;; current round of the story
  }
)

;; Voting rounds per story
(define-map rounds
  {
    story-id: uint,                 ;; story-id
    round-num: uint,                ;; round number
  }
  {
    round-id: uint,                 ;; round-id
    start-block: uint,              ;; block height when the round starts
    end-block: uint,                ;; block height when the round ends
    is-finalized: bool,             ;; whether the round is finalized
    winning-submission: (optional uint), ;; winning submission id
    total-votes: uint,
  }
)

;; Submissions for each round
(define-map submissions
  { submission-id: uint }             ;; submission-id
  {
    story-id: uint,                 ;; story-id
    round-num: uint,                ;; round number
    uri: (string-ascii 512),         ;; uri of the submission
    contributor: principal,          ;; contributor of the submission
    submitted-at: uint,              ;; block height when the submission was made
    vote-count: uint,                ;; number of votes the submission has
  }
)

;; Submission indexing: track all submissions per round
(define-map round-submissions
  {
    story-id: uint,                 ;; story-id
    round-num: uint,                ;; round number
    index: uint,                     ;; index of the submission
  }
  { submission-id: uint }             ;; submission-id
)

(define-map round-submission-count
  {
    story-id: uint,                 ;; story-id
    round-num: uint,                ;; round number
  }
  { count: uint }                     ;; number of submissions in the round
)

;; Vote tracking: one vote per user per round
(define-map votes
  {
    story-id: uint,                 ;; story-id
    round-num: uint,                ;; round number
    voter: principal,                ;; voter of the submission
  }
  { submission-id: uint }             ;; submission-id
)

;; Finalized story chain (immutable history)
(define-map story-chain
  {
    story-id: uint,                 ;; story-id
    block-index: uint,              ;; block index of the submission
  }
  {
    submission-id: uint,            ;; submission-id
    contributor: principal,          ;; contributor of the submission
    finalized-at: uint,              ;; block height when the submission was finalized
  }
)

;; Track contributors for reward distribution
(define-map contributor-blocks
  {
    story-id: uint,                 ;; story-id
    contributor: principal,          ;; contributor of the submission
  }
  { block-count: uint }             ;; number of blocks the contributor has contributed to the story
)

;; Submission tracking per user per round (prevent duplicate submissions)
(define-map user-round-submissions
  {
    story-id: uint,                 ;; story-id
    round-num: uint,                ;; round number
    user: principal,                 ;; user of the submission
  }
  { submission-id: uint }             ;; submission-id
)

;; User registration: map principal to username and registration data
(define-map users
  { user: principal }                 ;; user principal
  {
    username: (string-utf8 50),       ;; username (max 50 chars)
    registered-at: uint,              ;; block height when registered
  }
)

;; Username to principal mapping (for uniqueness check)
(define-map usernames
  { username: (string-utf8 50) }      ;; username
  { user: principal }                 ;; user principal
)

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================
;; Read-only functions to get story, round, submission, etc.
(define-read-only (get-story (story-id uint))
  (map-get? stories { story-id: story-id })
)
;; Get round data
(define-read-only (get-round
    (story-id uint)
    (round-num uint)
  )
  (map-get? rounds {
    story-id: story-id,
    round-num: round-num,
  })
)
;; Get submission data
(define-read-only (get-submission (submission-id uint))
  (map-get? submissions { submission-id: submission-id })
)
;; Get story chain block data
(define-read-only (get-story-chain-block
    (story-id uint)
    (block-index uint)
  )
  (map-get? story-chain {
    story-id: story-id,
    block-index: block-index,
  })
)
;; Check if a voter has voted for a submission
(define-read-only (has-voted
    (story-id uint)
    (round-num uint)
    (voter principal)
  )
  (is-some (map-get? votes {
    story-id: story-id,
    round-num: round-num,
    voter: voter,
  }))
)
;; Get user vote
(define-read-only (get-user-vote
    (story-id uint)
    (round-num uint)
    (voter principal)
  )
  (map-get? votes {
    story-id: story-id,
    round-num: round-num,
    voter: voter,
  })
)
;; Get contributor stats
(define-read-only (get-contributor-stats
    (story-id uint)
    (contributor principal)
  )
  (default-to { block-count: u0 }
    (map-get? contributor-blocks {
      story-id: story-id,
      contributor: contributor,
    })
  )
)
;; Get round submission count
(define-read-only (get-round-submission-count
    (story-id uint)
    (round-num uint)
  )
  (get count
    (default-to { count: u0 }
      (map-get? round-submission-count {
        story-id: story-id,
        round-num: round-num,
      })
    ))
)
;; Get round submission at index
(define-read-only (get-round-submission-at
    (story-id uint)
    (round-num uint)
    (index uint)
  )
  (map-get? round-submissions {
    story-id: story-id,
    round-num: round-num,
    index: index,
  })
)
;; Check if voting is active
(define-read-only (is-voting-active
    (story-id uint)
    (round-num uint)
  )
  (match (get-round story-id round-num)
    round-data (and
      (not (get is-finalized round-data))
      (<= stacks-block-height (get end-block round-data))
      (>= stacks-block-height (get start-block round-data))
    )
    false
  )
)
;; Check if a round can be finalized
(define-read-only (can-finalize-round
    (story-id uint)
    (round-num uint)
  )
  (match (get-round story-id round-num)
    round-data (and
      (not (get is-finalized round-data))
      (> stacks-block-height (get end-block round-data))
    )
    false
  )
)

;; Get user registration data by principal
(define-read-only (get-user (user principal))
  (map-get? users { user: user })
)




;; =============================================================================
;; PUBLIC FUNCTIONS - USER REGISTRATION
;; =============================================================================

;; register-user(username)
;; Purpose: Register a user with a unique username.
;; Params:
;;  - username: (string-utf8 50) desired username (max 50 characters).
;; Preconditions:
;;  - User (tx-sender) is not already registered.
;;  - Username is not already taken by another user.
;; Effects:
;;  - Creates user record in `users` map with username and registration timestamp.
;;  - Creates reverse mapping in `usernames` map for uniqueness enforcement.
;; Events: Emits "user-registered" with user principal and username.
;; Returns: (ok true) on success, or appropriate error code.
(define-public (register-user (username (string-utf8 50)))
  (let (
      (existing-user (map-get? users { user: tx-sender }))
      (existing-username (map-get? usernames { username: username }))
    )
    (begin
      ;; Validations
      (asserts! (is-none existing-user) ERR-USER-ALREADY-REGISTERED)
      (asserts! (is-none existing-username) ERR-USERNAME-EXISTS)

      ;; Register user
      (map-set users { user: tx-sender } {
        username: username,
        registered-at: stacks-block-height,
      })

      ;; Track username for uniqueness
      (map-set usernames { username: username } { user: tx-sender })

      (print {
        event: "user-registered",
        user: tx-sender,
        username: username,
      })

      (ok true)
    )
  )
)

;; =============================================================================
;; PUBLIC FUNCTIONS - STORY LIFECYCLE
;; =============================================================================

;; Create a new story with initial prompt (genesis block)
;; create-story(prompt)
;; Purpose: Initializes a new story and its first voting round.
;; Params:
;;  - prompt: (string-utf8 500) human-readable genesis prompt for the story.
;; Effects:
;;  - Increments global counters and writes a new entry into `stories` with
;;    default fields (is-sealed = false, bounty-pool = u0, total-blocks = u0,
;;    current-round = u1).
;;  - Creates round #1 in `rounds` with start/end window derived from current
;;    block height and `VOTING-PERIOD`.
;;  - Emits `story-created` event.
;; Returns: (ok new-story-id)
(define-public (create-story (prompt (string-utf8 500)))  
  (let (
      (new-story-id (+ (var-get story-counter) u1))
      (initial-round-id (+ (var-get round-counter) u1))
    )
    (begin
      ;; Create story
      (map-set stories { story-id: new-story-id } {
        prompt: prompt,
        creator: tx-sender,
        is-sealed: false,
        created-at: stacks-block-height,
        total-blocks: u0,
        bounty-pool: u0,
        current-round: u1,
      })

      ;; Initialize first voting round
      (map-set rounds {
        story-id: new-story-id,
        round-num: u1,
      } {
        round-id: initial-round-id,
        start-block: stacks-block-height,
        end-block: (+ stacks-block-height VOTING-PERIOD),
        is-finalized: false,
        winning-submission: none,
        total-votes: u0,
      })

      ;; Update counters
      (var-set story-counter new-story-id)
      (var-set round-counter initial-round-id)

      (print {
        event: "story-created",
        story-id: new-story-id,
        creator: tx-sender,
        prompt: prompt,
      })

      (ok new-story-id)
    )
  )
)

;; Submit a voice memo for the current round
;; submit-block(story-id, uri)
;; Purpose: Adds a new voice memo submission to the story's current round.
;; Params:
;;  - story-id: uint identifier of the story to submit to.
;;  - uri: (string-ascii 512) content reference for the voice memo (e.g., IPFS).
;; Preconditions:
;;  - Story exists and is not sealed.
;;  - Caller has not already submitted in the current round.
;;  - Current block height is within the round's voting window.
;;  - Story has not reached MAX-BLOCKS-PER-STORY.
;; Effects:
;;  - Creates a new submission with vote-count = 0 and indexes it in the round.
;;  - Increments the per-round submission count and global submission counter.
;;  - Tracks that the caller has submitted for this round.
;; Events: Emits "submission-created" with submission, story, round, contributor.
;; Returns: (ok submission-id) on success, appropriate error otherwise.
(define-public (submit-block
    (story-id uint)
    (uri (string-ascii 512))
  )
  (let (
      (story (unwrap! (get-story story-id) ERR-NOT-FOUND))
      (current-round (get current-round story))
      (round-data (unwrap! (get-round story-id current-round) ERR-NOT-FOUND))
      (new-submission-id (+ (var-get submission-counter) u1))
      (existing-submission (map-get? user-round-submissions {
        story-id: story-id,
        round-num: current-round,
        user: tx-sender,
      }))
      (current-sub-count (get-round-submission-count story-id current-round))
    )
    (begin
      ;; Validations
      (asserts! (not (get is-sealed story)) ERR-STORY-SEALED)
      (asserts! (is-none existing-submission) ERR-ALREADY-SUBMITTED)
      (asserts! (<= stacks-block-height (get end-block round-data))
        ERR-VOTING-CLOSED
      )
      (asserts! (< (get total-blocks story) MAX-BLOCKS-PER-STORY)
        ERR-STORY-SEALED
      )

      ;; Create submission
      (map-set submissions { submission-id: new-submission-id } {
        story-id: story-id,
        round-num: current-round,
        uri: uri,
        contributor: tx-sender,
        submitted-at: stacks-block-height,
        vote-count: u0,
      })

      ;; Index submission for this round
      (map-set round-submissions {
        story-id: story-id,
        round-num: current-round,
        index: current-sub-count,
      } { submission-id: new-submission-id }
      )

      ;; Update submission count
      (map-set round-submission-count {
        story-id: story-id,
        round-num: current-round,
      } { count: (+ current-sub-count u1) }
      )

      ;; Track user submission for this round
      (map-set user-round-submissions {
        story-id: story-id,
        round-num: current-round,
        user: tx-sender,
      } { submission-id: new-submission-id }
      )

      (var-set submission-counter new-submission-id)

      (print {
        event: "submission-created",
        submission-id: new-submission-id,
        story-id: story-id,
        round: current-round,
        contributor: tx-sender,
      })

      (ok new-submission-id)
    )
  )
)

;; vote-block(submission-id)
;; Purpose: Cast a vote for a specific submission in its story round.
;; Params:
;;  - submission-id: uint identifier of the submission to vote for.
;; Preconditions:
;;  - Submission exists; its story and round exist.
;;  - Story is not sealed; round is currently voting-active.
;;  - Caller has not already voted in that round.
;; Effects:
;;  - Records caller's vote in `votes` for the round.
;;  - Increments the submission's `vote-count` and the round's `total-votes`.
;; Events: Emits "vote-cast" with submission, voter, story, and round.
;; Returns: (ok true) on success, or appropriate error code.
(define-public (vote-block (submission-id uint))
  (let (
      (submission (unwrap! (get-submission submission-id) ERR-NOT-FOUND))
      (story-id (get story-id submission))
      (round-num (get round-num submission))
      (story (unwrap! (get-story story-id) ERR-NOT-FOUND))
      (round-data (unwrap! (get-round story-id round-num) ERR-NOT-FOUND))
    )
    (begin
      ;; Validations
      (asserts! (not (get is-sealed story)) ERR-STORY-SEALED)
      (asserts! (not (has-voted story-id round-num tx-sender)) ERR-ALREADY-VOTED)
      (asserts! (is-voting-active story-id round-num) ERR-VOTING-CLOSED)

      ;; Record vote
      (map-set votes {
        story-id: story-id,
        round-num: round-num,
        voter: tx-sender,
      } { submission-id: submission-id }
      )

      ;; Increment vote count
      (map-set submissions { submission-id: submission-id }
        (merge submission { vote-count: (+ (get vote-count submission) u1) })
      )

      ;; Update round vote total
      (map-set rounds {
        story-id: story-id,
        round-num: round-num,
      }
        (merge round-data { total-votes: (+ (get total-votes round-data) u1) })
      )

      (print {
        event: "vote-cast",
        submission-id: submission-id,
        voter: tx-sender,
        story-id: story-id,
        round: round-num,
      })

      (ok true)
    )
  )
)

;; Build list of submission IDs for a round without self-recursion
;; Precomputed index list for folding up to 100 items
(define-constant INDEXES-100 (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
  u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40
  u41 u42 u43 u44 u45 u46 u47 u48 u49 u50 u51 u52 u53 u54 u55 u56 u57 u58 u59 u60
  u61 u62 u63 u64 u65 u66 u67 u68 u69 u70 u71 u72 u73 u74 u75 u76 u77 u78 u79 u80
  u81 u82 u83 u84 u85 u86 u87 u88 u89 u90 u91 u92 u93 u94 u95 u96 u97 u98 u99))

;; Collector used with fold to gather submission ids up to `count`
(define-private (collect-submission-ids
    (idx uint)
    (acc {
      items: (list 100 uint),
      story-id: uint,
      round-num: uint,
      count: uint,
      start: uint,
    })
  )
  (if (or (< idx (get start acc)) (>= idx (get count acc)))
    acc
    (match (get-round-submission-at (get story-id acc) (get round-num acc) idx)
      entry (let ((new-items (unwrap-panic (as-max-len? (concat (get items acc) (list (get submission-id entry)))
          u100
        ))))
        (merge acc { items: new-items })
      )
      acc
    )
  )
)

(define-private (build-submission-list
    (story-id uint)
    (round-num uint)
    (count uint)
    (index uint)
  )
  (let (
      (start-index index)
      (acc0 {
        items: (list),
        story-id: story-id,
        round-num: round-num,
        count: count,
        start: start-index,
      })
    )
    ;; We fold across all possible indices, but the collector ignores those < start-index or >= count
    (ok (get items (fold collect-submission-ids INDEXES-100 acc0)))
  )
)

;; Fold iterator to find submission with highest votes
(define-private (find-highest-voted-submission
    (submission-id uint)
    (acc {
      best-id: uint,
      best-votes: uint,
      story-id: uint,
      round-num: uint,
    })
  )
  (match (get-submission submission-id)
    submission (let ((vote-count (get vote-count submission)))
      (if (>= vote-count (get best-votes acc))
        (merge acc {
          best-id: submission-id,
          best-votes: vote-count,
        })
        acc
      )
    )
    acc
  )
)

(define-read-only (get-winning-submission
    (story-id uint)
    (round-num uint)
  )
  (let ((submission-count (get-round-submission-count story-id round-num)))
    (if (<= submission-count u0)
      ERR-NO-SUBMISSIONS
      (ok (get best-id
        (fold find-highest-voted-submission
          (unwrap-panic (build-submission-list story-id round-num submission-count u0)) {
          best-id: u0,
          best-votes: u0,
          story-id: story-id,
          round-num: round-num,
        })
      ))
    )
  )
)

;; Finalize a round by selecting the winning submission
;; finalize-round(story-nft, story-id, round-num)
;; Purpose: Finalizes a voting round by selecting the winning submission,
;;          minting a reward NFT to its contributor, and progressing the story.
;; Params:
;;  - story-nft: <nft-tokens> trait reference for the NFT contract.
;;  - story-id: uint identifier of the story.
;;  - round-num: uint round number to finalize.
;; Preconditions:
;;  - Round exists, is not already finalized, and voting period has ended.
;;  - At least one submission exists for the round.
;; Effects:
;;  - Determines the winner by highest vote-count (ties resolved by reducer order).
;;  - Marks round finalized and records winning submission.
;;  - Appends a block to `story-chain` and mints an NFT to the winner.
;;  - Updates contributor stats and increments story `total-blocks`.
;;  - Starts the next round unless max blocks reached; bumps `round-counter`.
;; Events: Emits "round-finalized" with story, round, winner, contributor.
;; Returns: (ok winning-submission-id) on success, or appropriate error.
(define-public (finalize-round
    (story-nft <nft-tokens>)
    (story-id uint)
    (round-num uint)
  )
  (let (
      (story (unwrap! (get-story story-id) ERR-NOT-FOUND))
      (round-data (unwrap! (get-round story-id round-num) ERR-NOT-FOUND))
      (current-blocks (get total-blocks story))
    )
    (begin
      ;; Validations
      (asserts! (not (get is-finalized round-data)) ERR-ALREADY-FINALIZED)
      (asserts! (can-finalize-round story-id round-num) ERR-VOTING-NOT-ENDED)

      ;; Get winning submission
      (match (get-winning-submission story-id round-num)
        winning-id (match (get-submission winning-id)
          winner (let (
              (contributor (get contributor winner))
              (new-round-num (+ round-num u1))
              (new-round-id (+ (var-get round-counter) u1))
            )
            (begin
              ;; Mark round as finalized
              (map-set rounds {
                story-id: story-id,
                round-num: round-num,
              }
                (merge round-data {
                  is-finalized: true,
                  winning-submission: (some winning-id),
                })
              )

              ;; Add to story chain
              (map-set story-chain {
                story-id: story-id,
                block-index: current-blocks,
              } {
                submission-id: winning-id,
                contributor: contributor,
                finalized-at: stacks-block-height,
              })

              ;; mint the story to the winner 
              (try! (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.Soni_NFT
                mint contributor
              ))

              ;; Update contributor stats
              (let (
                  (contributor-stats (get-contributor-stats story-id contributor))
                  (current-count (get block-count contributor-stats))
                )
                (map-set contributor-blocks {
                  story-id: story-id,
                  contributor: contributor,
                } { block-count: (+ current-count u1) }
                )
              )

              ;; Update story
              (map-set stories { story-id: story-id }
                (merge story {
                  total-blocks: (+ current-blocks u1),
                  current-round: new-round-num,
                })
              )

              ;; Start next round (if not at max blocks)
              (if (< (+ current-blocks u1) MAX-BLOCKS-PER-STORY)
                (begin
                  (map-set rounds {
                    story-id: story-id,
                    round-num: new-round-num,
                  } {
                    round-id: new-round-id,
                    start-block: stacks-block-height,
                    end-block: (+ stacks-block-height VOTING-PERIOD),
                    is-finalized: false,
                    winning-submission: none,
                    total-votes: u0,
                  })
                  (var-set round-counter new-round-id)
                )
                true
              )

              (print {
                event: "round-finalized",
                story-id: story-id,
                round: round-num,
                winner: winning-id,
                contributor: contributor,
              })

              (ok winning-id)
            )
          )
          ERR-NOT-FOUND
        )
        err-code (err err-code)
      )
    )
  )
)

;; =============================================================================
;; BOUNTY & REWARDS SYSTEM
;; =============================================================================

;; Add funds to story bounty pool
;; fund-bounty(story-id, amount)
;; Purpose: Adds STX funds to the story's bounty pool held by this contract.
;; Params:
;;  - story-id: uint identifier of the story to fund.
;;  - amount: uint amount of microSTX to transfer into the bounty pool.
;; Preconditions:
;;  - Story exists and is not sealed.
;;  - amount > 0.
;; Effects:
;;  - Transfers `amount` STX from caller to the contract.
;;  - Increases `stories.bounty-pool` by `amount`.
;; Events: Emits "bounty-funded" with story id, amount, funder, and new total.
;; Returns: (ok true) on success, or error on invalid amount / sealed story / transfer failure.
(define-public (fund-bounty
    (story-id uint)
    (amount uint)
  )
  (let ((story (unwrap! (get-story story-id) ERR-NOT-FOUND)))
    (begin
      (asserts! (> amount u0) ERR-INVALID-AMOUNT)
      (asserts! (not (get is-sealed story)) ERR-STORY-SEALED)

      ;; Transfer STX to contract
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

      ;; Update bounty pool
      (map-set stories { story-id: story-id }
        (merge story { bounty-pool: (+ (get bounty-pool story) amount) })
      )

      (print {
        event: "bounty-funded",
        story-id: story-id,
        amount: amount,
        funder: tx-sender,
        new-total: (+ (get bounty-pool story) amount),
      })

      (ok true)
    )
  )
)

;; Fold-based reward distribution step (avoids recursion)
(define-private (distribute-rewards-step
    (i uint)
    (acc {
      story-id: uint,
      share: uint,
      total-blocks: uint,
    })
  )
  (if (>= i (get total-blocks acc))
    acc
    (match (get-story-chain-block (get story-id acc) i)
      chain-entry (let (
          (contributor (get contributor chain-entry))
          (transfer-result (as-contract (stx-transfer? (get share acc) tx-sender contributor)))
        )
        (match transfer-result
          success (begin
            (print {
              event: "reward-distributed",
              story-id: (get story-id acc),
              block-index: i,
              contributor: contributor,
              amount: (get share acc),
            })
            acc
          )
          error-val
          acc
        )
      )
      acc
    )
  )
)

;; Distribute rewards to all contributors
(define-private (distribute-rewards
    (story-id uint)
    (total-amount uint)
    (total-blocks uint)
  )
  (if (<= total-blocks u0)
    true
    (let (
        (share-per-block (/ total-amount total-blocks))
        (acc0 {
          story-id: story-id,
          share: share-per-block,
          total-blocks: total-blocks,
        })
      )
      (fold distribute-rewards-step INDEXES-100 acc0)
      true
    )
  )
)

;; Seal story and distribute rewards to contributors
;; seal-story(story-id)
;; Purpose: Finalizes the entire story after minimum finalized blocks are met,
;;          marks it sealed, charges platform fee, and distributes bounty.
;; Params:
;;  - story-id: uint identifier of the story to seal.
;; Preconditions:
;;  - Caller is the story creator.
;;  - Story is not already sealed.
;;  - Story has at least `MIN-BLOCKS-TO-SEAL` finalized blocks.
;; Effects:
;;  - Sets `is-sealed = true` on the story.
;;  - Transfers platform fee to `CONTRACT-OWNER` and distributes remaining bounty
;;    proportionally across finalized blocks to contributors.
;; Events: Emits "story-sealed" including story id, total blocks, distributed bounty,
;;         and platform fee.
;; Returns: (ok story-id) on success, or an appropriate error code.
(define-public (seal-story (story-id uint))
  (let (
      (story (unwrap! (get-story story-id) ERR-NOT-FOUND))
      (total-blocks (get total-blocks story))
      (bounty (get bounty-pool story))
      (platform-fee (/ (* bounty PLATFORM-FEE-BPS) u10000))
      (distributable (- bounty platform-fee))
    )
    (begin
      ;; Validations
      (asserts! (is-eq tx-sender (get creator story)) ERR-UNAUTHORIZED)
      (asserts! (not (get is-sealed story)) ERR-STORY-SEALED)
      (asserts! (>= total-blocks MIN-BLOCKS-TO-SEAL) ERR-INSUFFICIENT-BLOCKS)

      ;; Mark as sealed
      (map-set stories { story-id: story-id } (merge story { is-sealed: true }))

      ;; Transfer platform fee
      (if (> platform-fee u0)
        (try! (as-contract (stx-transfer? platform-fee tx-sender CONTRACT-OWNER)))
        true
      )

      ;; Distribute rewards
      (if (> distributable u0)
        (begin
          (distribute-rewards story-id distributable total-blocks)
          true
        )
        true
      )

      (print {
        event: "story-sealed",
        story-id: story-id,
        total-blocks: total-blocks,
        bounty-distributed: distributable,
        platform-fee: platform-fee,
      })

      (ok story-id)
    )
  )
)

;; Helper to check submission votes (used in fold)
(define-private (check-submission-votes
    (submission-id uint)
    (acc {
      best-id: uint,
      best-votes: uint,
    })
  )
  (match (get-submission submission-id)
    submission (if (> (get vote-count submission) (get best-votes acc))
      {
        best-id: submission-id,
        best-votes: (get vote-count submission),
      }
      acc
    )
    acc
  )
)


