(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_CHANNEL_NOT_FOUND (err u101))
(define-constant ERR_CHANNEL_CLOSED (err u102))
(define-constant ERR_INVALID_SIGNATURE (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERR_INVALID_NONCE (err u105))
(define-constant ERR_CHALLENGE_PERIOD_ACTIVE (err u106))
(define-constant ERR_CHALLENGE_PERIOD_EXPIRED (err u107))
(define-constant ERR_INVALID_PARTICIPANT (err u108))
(define-constant ERR_CHANNEL_ALREADY_EXISTS (err u109))

(define-constant CHALLENGE_PERIOD u144)

(define-data-var next-channel-id uint u1)

(define-map channels
    uint
    {
        participant-a: principal,
        participant-b: principal,
        balance-a: uint,
        balance-b: uint,
        nonce: uint,
        is-closed: bool,
        challenge-expiry: (optional uint),
        closer: (optional principal)
    }
)

(define-map channel-deposits
    { channel-id: uint, participant: principal }
    uint
)

(define-map pending-withdrawals
    { channel-id: uint, participant: principal }
    uint
)

(define-public (open-channel (participant-b principal) (initial-deposit uint))
    (let
        (
            (channel-id (var-get next-channel-id))
            (sender tx-sender)
        )
        (asserts! (> initial-deposit u0) ERR_INSUFFICIENT_BALANCE)
        (asserts! (not (is-eq sender participant-b)) ERR_INVALID_PARTICIPANT)
        
        (try! (stx-transfer? initial-deposit sender (as-contract tx-sender)))
        
        (map-set channels channel-id
            {
                participant-a: sender,
                participant-b: participant-b,
                balance-a: initial-deposit,
                balance-b: u0,
                nonce: u0,
                is-closed: false,
                challenge-expiry: none,
                closer: none
            }
        )
        
        (map-set channel-deposits { channel-id: channel-id, participant: sender } initial-deposit)
        (var-set next-channel-id (+ channel-id u1))
        
        (ok channel-id)
    )
)

(define-public (deposit-to-channel (channel-id uint) (amount uint))
    (let
        (
            (channel (unwrap! (map-get? channels channel-id) ERR_CHANNEL_NOT_FOUND))
            (sender tx-sender)
        )
        (asserts! (> amount u0) ERR_INSUFFICIENT_BALANCE)
        (asserts! (is-eq (get is-closed channel) false) ERR_CHANNEL_CLOSED)
        (asserts! (or (is-eq sender (get participant-a channel)) 
                     (is-eq sender (get participant-b channel))) ERR_UNAUTHORIZED)
        
        (try! (stx-transfer? amount sender (as-contract tx-sender)))
        
        (let
            (
                (current-deposit (default-to u0 (map-get? channel-deposits { channel-id: channel-id, participant: sender })))
                (new-deposit (+ current-deposit amount))
                (updated-channel 
                    (if (is-eq sender (get participant-a channel))
                        (merge channel { balance-a: (+ (get balance-a channel) amount) })
                        (merge channel { balance-b: (+ (get balance-b channel) amount) })
                    )
                )
            )
            (map-set channel-deposits { channel-id: channel-id, participant: sender } new-deposit)
            (map-set channels channel-id updated-channel)
            (ok true)
        )
    )
)

(define-public (update-channel-state (channel-id uint) (new-balance-a uint) (new-balance-b uint) (new-nonce uint))
    (let
        (
            (channel (unwrap! (map-get? channels channel-id) ERR_CHANNEL_NOT_FOUND))
            (total-balance (+ (get balance-a channel) (get balance-b channel)))
            (sender tx-sender)
        )
        (asserts! (is-eq (get is-closed channel) false) ERR_CHANNEL_CLOSED)
        (asserts! (> new-nonce (get nonce channel)) ERR_INVALID_NONCE)
        (asserts! (is-eq (+ new-balance-a new-balance-b) total-balance) ERR_INSUFFICIENT_BALANCE)
        (asserts! (or (is-eq sender (get participant-a channel)) 
                     (is-eq sender (get participant-b channel))) ERR_UNAUTHORIZED)
        
        (map-set channels channel-id
            (merge channel {
                balance-a: new-balance-a,
                balance-b: new-balance-b,
                nonce: new-nonce
            })
        )
        (ok true)
    )
)

(define-public (cooperative-close (channel-id uint) (final-balance-a uint) (final-balance-b uint))
    (let
        (
            (channel (unwrap! (map-get? channels channel-id) ERR_CHANNEL_NOT_FOUND))
            (total-balance (+ (get balance-a channel) (get balance-b channel)))
            (sender tx-sender)
            (participant-a (get participant-a channel))
            (participant-b (get participant-b channel))
        )
        (asserts! (is-eq (get is-closed channel) false) ERR_CHANNEL_CLOSED)
        (asserts! (is-eq (+ final-balance-a final-balance-b) total-balance) ERR_INSUFFICIENT_BALANCE)
        (asserts! (or (is-eq sender participant-a) (is-eq sender participant-b)) ERR_UNAUTHORIZED)
        
        (map-set channels channel-id (merge channel { is-closed: true }))
        
        (if (> final-balance-a u0)
            (try! (as-contract (stx-transfer? final-balance-a tx-sender participant-a)))
            true)
        
        (if (> final-balance-b u0)
            (try! (as-contract (stx-transfer? final-balance-b tx-sender participant-b)))
            true)
        
        (ok true)
    )
)

(define-public (initiate-challenge (channel-id uint))
    (let
        (
            (channel (unwrap! (map-get? channels channel-id) ERR_CHANNEL_NOT_FOUND))
            (sender tx-sender)
        )
        (asserts! (is-eq (get is-closed channel) false) ERR_CHANNEL_CLOSED)
        (asserts! (or (is-eq sender (get participant-a channel)) 
                     (is-eq sender (get participant-b channel))) ERR_UNAUTHORIZED)
        (asserts! (is-none (get challenge-expiry channel)) ERR_CHALLENGE_PERIOD_ACTIVE)
        
        (map-set channels channel-id
            (merge channel {
                challenge-expiry: (some (+ burn-block-height CHALLENGE_PERIOD)),
                closer: (some sender)
            })
        )
        (ok true)
    )
)

(define-public (respond-to-challenge (channel-id uint) (new-balance-a uint) (new-balance-b uint) (new-nonce uint))
    (let
        (
            (channel (unwrap! (map-get? channels channel-id) ERR_CHANNEL_NOT_FOUND))
            (sender tx-sender)
        )
        (asserts! (is-eq (get is-closed channel) false) ERR_CHANNEL_CLOSED)
        (asserts! (is-some (get challenge-expiry channel)) ERR_CHALLENGE_PERIOD_EXPIRED)
        (asserts! (< burn-block-height (unwrap-panic (get challenge-expiry channel))) ERR_CHALLENGE_PERIOD_EXPIRED)
        (asserts! (or (is-eq sender (get participant-a channel)) 
                     (is-eq sender (get participant-b channel))) ERR_UNAUTHORIZED)
        
        (try! (update-channel-state channel-id new-balance-a new-balance-b new-nonce))
        
        (map-set channels channel-id
            (merge (unwrap-panic (map-get? channels channel-id)) {
                challenge-expiry: none,
                closer: none
            })
        )
        (ok true)
    )
)

(define-public (finalize-challenge (channel-id uint))
    (let
        (
            (channel (unwrap! (map-get? channels channel-id) ERR_CHANNEL_NOT_FOUND))
            (balance-a (get balance-a channel))
            (balance-b (get balance-b channel))
            (participant-a (get participant-a channel))
            (participant-b (get participant-b channel))
        )
        (asserts! (is-eq (get is-closed channel) false) ERR_CHANNEL_CLOSED)
        (asserts! (is-some (get challenge-expiry channel)) ERR_CHALLENGE_PERIOD_ACTIVE)
        (asserts! (>= burn-block-height (unwrap-panic (get challenge-expiry channel))) ERR_CHALLENGE_PERIOD_ACTIVE)
        
        (map-set channels channel-id (merge channel { is-closed: true }))
        
        (if (> balance-a u0)
            (try! (as-contract (stx-transfer? balance-a tx-sender participant-a)))
            true)
        
        (if (> balance-b u0)
            (try! (as-contract (stx-transfer? balance-b tx-sender participant-b)))
            true)
        
        (ok true)
    )
)

(define-read-only (get-channel (channel-id uint))
    (map-get? channels channel-id)
)

(define-read-only (get-channel-deposit (channel-id uint) (participant principal))
    (map-get? channel-deposits { channel-id: channel-id, participant: participant })
)

(define-read-only (get-next-channel-id)
    (var-get next-channel-id)
)

(define-read-only (is-participant (channel-id uint) (user principal))
    (match (map-get? channels channel-id)
        channel (or (is-eq user (get participant-a channel)) 
                   (is-eq user (get participant-b channel)))
        false
    )
)

(define-read-only (get-challenge-status (channel-id uint))
    (match (map-get? channels channel-id)
        channel (some {
            has-challenge: (is-some (get challenge-expiry channel)),
            expiry: (get challenge-expiry channel),
            closer: (get closer channel),
            blocks-remaining: (match (get challenge-expiry channel)
                expiry (if (> expiry burn-block-height) (some (- expiry burn-block-height)) (some u0))
                none
            )
        })
        none
    )
)
