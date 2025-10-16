(impl-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.Soni_NFT_Trait.Soni_NFT_Trait)


(define-constant contract-owner tx-sender)
(define-constant sonichain-contract .Sonichain)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))

(define-non-fungible-token Soni_NFT uint)

(define-data-var last-token-id uint u0)

;; Map token-id to metadata URI (ascii to match trait)
(define-map token-uris
  { token-id: uint }
  { uri: (string-ascii 256) }
)

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (let ((entry (map-get? token-uris { token-id: token-id })))
    (ok (match entry e (some (get uri e)) none))
  )
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

(define-public (mint (recipient principal) (uri (string-ascii 256)))
  (let ((token-id (+ (var-get last-token-id) u1)))
    (asserts! (is-eq contract-caller sonichain-contract) err-owner-only)
    (try! (nft-mint? Soni_NFT token-id recipient))
    (map-set token-uris { token-id: token-id } { uri: uri })
    (var-set last-token-id token-id)

    (print {
      event: "Story winner minted Soni NFT",
      token-id: token-id,
      recipient: recipient,
      uri: uri,
    })
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

