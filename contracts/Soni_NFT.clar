(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)


(define-constant contract-owner tx-sender)
(define-constant sonichain-contract 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.Sonichain)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))

(define-non-fungible-token Soni_NFT uint)

(define-data-var last-token-id uint u0)

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (ok (some ""))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? Soni_NFT token-id))
)

(define-public (transfer
    (token-id uint)
    (sender principal)
    (recipient principal)
  )
  (begin
    (nft-transfer? Soni_NFT token-id sender recipient)
  )
)

(define-public (mint (recipient principal))
  (let ((token-id (+ (var-get last-token-id) u1)))
    (asserts! (or (is-eq tx-sender contract-owner) (is-eq contract-caller sonichain-contract)) err-owner-only)
    (try! (nft-mint? Soni_NFT token-id recipient))
    (var-set last-token-id token-id)
    (ok token-id)
  )
)

(define-public (burn (token-id uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (let ((owner (nft-get-owner? Soni_NFT token-id)))
      (asserts! (is-some owner) err-not-token-owner)

      (try! (nft-burn? Soni_NFT token-id (unwrap-panic owner)))
      (ok true)
    )
  )
)
