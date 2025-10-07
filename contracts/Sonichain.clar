;; EchoChain V2 - Collaborative Voice Story Protocol
;; A decentralized story-building game where players contribute voice memos
;; to create evolving narrative chains with voting consensus and rewards.

;; =============================================================================
;; CONSTANTS & ERROR CODES
;; =============================================================================

(use-trait nft-tokens 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; Error codes
(define-constant ERR-NOT-FOUND (err u100))
(define-constant ERR-UNAUTHORIZED (err u101))
(define-constant ERR-STORY-SEALED (err u102))
(define-constant ERR-ALREADY-VOTED (err u103))
(define-constant ERR-NO-SUBMISSIONS (err u104))
(define-constant ERR-INSUFFICIENT-BLOCKS (err u105))
(define-constant ERR-INVALID-AMOUNT (err u106))
(define-constant ERR-TRANSFER-FAILED (err u107))
(define-constant ERR-VOTING-CLOSED (err u108))
(define-constant ERR-ALREADY-FINALIZED (err u109))
(define-constant ERR-VOTING-NOT-ENDED (err u110))
(define-constant ERR-ALREADY-SUBMITTED (err u111))

;; Configuration
(define-constant CONTRACT-OWNER tx-sender)
(define-constant VOTING-PERIOD u120) ;; ~2 hours in blocks
(define-constant MIN-BLOCKS-TO-SEAL u5) ;; Minimum story length
(define-constant MAX-BLOCKS-PER-STORY u50) ;; Maximum story length
(define-constant PLATFORM-FEE-BPS u250) ;; 2.5% platform fee (basis points)

;; =============================================================================
;; DATA STRUCTURES
;; =============================================================================

;; Global counters
(define-data-var story-counter uint u0)
(define-data-var submission-counter uint u0)
(define-data-var round-counter uint u0)

;; Story metadata
(define-map stories
  { story-id: uint }
  {
    prompt: (string-utf8 500),
    creator: principal,
    is-sealed: bool,
    created-at: uint,
    total-blocks: uint,
    bounty-pool: uint,
    current-round: uint,
  }
)

;; Voting rounds per story
(define-map rounds
  {
    story-id: uint,
    round-num: uint,
  }
  {
    round-id: uint,
    start-block: uint,
    end-block: uint,
    is-finalized: bool,
    winning-submission: (optional uint),
    total-votes: uint,
  }
)

;; Submissions for each round
(define-map submissions
  { submission-id: uint }
  {
    story-id: uint,
    round-num: uint,
    uri: (string-ascii 512),
    contributor: principal,
    submitted-at: uint,
    vote-count: uint,
  }
)

;; Submission indexing: track all submissions per round
(define-map round-submissions
  {
    story-id: uint,
    round-num: uint,
    index: uint,
  }
  { submission-id: uint }
)

(define-map round-submission-count
  {
    story-id: uint,
    round-num: uint,
  }
  { count: uint }
)

;; Vote tracking: one vote per user per round
(define-map votes
  {
    story-id: uint,
    round-num: uint,
    voter: principal,
  }
  { submission-id: uint }
)

;; Finalized story chain (immutable history)
(define-map story-chain
  {
    story-id: uint,
    block-index: uint,
  }
  {
    submission-id: uint,
    contributor: principal,
    finalized-at: uint,
  }
)

;; Track contributors for reward distribution
(define-map contributor-blocks
  {
    story-id: uint,
    contributor: principal,
  }
  { block-count: uint }
)

;; Submission tracking per user per round (prevent duplicate submissions)
(define-map user-round-submissions
  {
    story-id: uint,
    round-num: uint,
    user: principal,
  }
  { submission-id: uint }
)

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-story (story-id uint))
  (map-get? stories { story-id: story-id })
)

(define-read-only (get-round
    (story-id uint)
    (round-num uint)
  )
  (map-get? rounds {
    story-id: story-id,
    round-num: round-num,
  })
)

(define-read-only (get-submission (submission-id uint))
  (map-get? submissions { submission-id: submission-id })
)

(define-read-only (get-story-chain-block
    (story-id uint)
    (block-index uint)
  )
  (map-get? story-chain {
    story-id: story-id,
    block-index: block-index,
  })
)

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

;; =============================================================================
;; PUBLIC FUNCTIONS - STORY LIFECYCLE
;; =============================================================================

;; Create a new story with initial prompt (genesis block)
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

;; Vote for a submission (one vote per user per round)
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

;; (duplicate distribute-rewards and distribute-rewards-iter removed)

;; =============================================================================
;; CONTRACT INITIALIZATION
;; =============================================================================

(begin
  (print {
    event: "contract-deployed",
    contract: "EchoChain-V2",
    owner: CONTRACT-OWNER,
    voting-period: VOTING-PERIOD,
    min-blocks: MIN-BLOCKS-TO-SEAL,
    max-blocks: MAX-BLOCKS-PER-STORY,
  })
)
