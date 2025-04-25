;; DeVenture: Decentralized Venture DAO Smart Contract
;; A fully decentralized platform for community-driven venture capital investments with 
;; democratic governance, staking rewards, and pool management capabilities.

;; Constants & Configuration

;; Ownership and administrative constants
(define-constant contract-admin tx-sender)

;; Financial thresholds and parameters
(define-constant minimum-contribution-amount u1000000) ;; 1 STX minimum in microSTX
(define-constant proposal-funding-threshold u100000000) ;; 100 STX minimum pool size
(define-constant voting-duration-blocks u144) ;; ~24 hours in blocks

;; Reward system parameters
(define-data-var staking-reward-rate uint u5000) ;; 0.005 STX per block per unit

;; Error codes with descriptive names
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-INSUFFICIENT-BALANCE (err u101))
(define-constant ERR-POOL-DOES-NOT-EXIST (err u102))
(define-constant ERR-INVALID-CONTRIBUTION-AMOUNT (err u103))
(define-constant ERR-DUPLICATE-VOTE (err u104))
(define-constant ERR-VOTING-PERIOD-ENDED (err u105))
(define-constant ERR-BELOW-FUNDING-THRESHOLD (err u106))
(define-constant ERR-INVALID-METADATA-FORMAT (err u107))
(define-constant ERR-NO-ACTIVE-STAKE (err u108))
(define-constant ERR-ALREADY-STAKING (err u109))
(define-constant ERR-POOL-MERGER-FAILED (err u110))
(define-constant ERR-IDENTICAL-POOL-MERGER (err u111))
(define-constant ERR-STAKING-LOCK-PERIOD (err u112))

;; Data Structures

;; Global counters
(define-data-var next-pool-id uint u0)
(define-data-var next-proposal-id uint u0)

;; Pool storage and management
(define-map investment-pools
    { pool-id: uint }
    {
        total-capital: uint,
        is-active: bool,
        pool-creator: principal,
        creation-block: uint
    }
)

;; Individual contributions tracking
(define-map investor-contributions
    { pool-id: uint, investor-address: principal }
    { investment-amount: uint }
)

;; Investment proposals
(define-map investment-proposals
    { pool-id: uint, proposal-id: uint }
    {
        recipient-address: principal,
        requested-amount: uint,
        proposal-description: (string-utf8 256),
        support-votes: uint,
        opposition-votes: uint,
        proposal-status: (string-utf8 20),
        submission-block: uint
    }
)

;; Vote registry
(define-map investor-votes
    { pool-id: uint, proposal-id: uint, voter-address: principal }
    { vote-decision: bool }
)

;; Pool descriptive information
(define-map pool-descriptive-data
    { pool-id: uint }
    {
        pool-name: (string-utf8 64),
        pool-description: (string-utf8 256),
        investment-category: (string-utf8 64),
        brand-image-url: (string-utf8 256)
    }
)

;; Staking registry and rewards
(define-map investor-stakes
    { pool-id: uint, staker-address: principal }
    {
        staked-amount: uint,
        stake-initiation-block: uint,
        last-reward-block: uint
    }
)

;; Pool consolidation proposals
(define-map pool-merger-proposals
    { source-pool-id: uint, destination-pool-id: uint }
    {
        merger-proposer: principal,
        support-votes: uint,
        opposition-votes: uint,
        proposal-date: uint,
        merger-status: (string-utf8 20)
    }
)

;; Read-Only Functions

;; Pool information retrieval
(define-read-only (get-pool-details (pool-id uint))
    (map-get? investment-pools { pool-id: pool-id })
)

;; Contribution lookup
(define-read-only (get-investor-contribution (pool-id uint) (investor-address principal))
    (map-get? investor-contributions { pool-id: pool-id, investor-address: investor-address })
)

;; Proposal details
(define-read-only (get-proposal-details (pool-id uint) (proposal-id uint))
    (map-get? investment-proposals { pool-id: pool-id, proposal-id: proposal-id })
)

;; Vote record lookup
(define-read-only (get-investor-vote (pool-id uint) (proposal-id uint) (voter-address principal))
    (map-get? investor-votes { pool-id: pool-id, proposal-id: proposal-id, voter-address: voter-address })
)

;; Pool metadata retrieval
(define-read-only (get-pool-descriptive-data (pool-id uint))
    (map-get? pool-descriptive-data { pool-id: pool-id })
)

;; Staking information lookup
(define-read-only (get-investor-stake (pool-id uint) (staker-address principal))
    (map-get? investor-stakes { pool-id: pool-id, staker-address: staker-address })
)

;; Calculate pending staking rewards
(define-read-only (calculate-pending-rewards (pool-id uint))
    (let
        ((stake-record (unwrap! (get-investor-stake pool-id tx-sender) ERR-NO-ACTIVE-STAKE)))
        
        (let
            ((elapsed-blocks (- block-height (get last-reward-block stake-record)))
             (staked-capital (get staked-amount stake-record))
             (block-reward-base (* elapsed-blocks (var-get staking-reward-rate))))
            
            (ok (* block-reward-base staked-capital))
        )
    )
)

;; Public Functions - Pool Management

;; Initialize a new investment pool
(define-public (create-investment-pool)
    (let
        ((pool-id (+ (var-get next-pool-id) u1)))
        (map-set investment-pools
            { pool-id: pool-id }
            {
                total-capital: u0,
                is-active: true,
                pool-creator: tx-sender,
                creation-block: block-height
            }
        )
        (var-set next-pool-id pool-id)
        (ok pool-id)
    )
)

;; Add funds to an investment pool
(define-public (contribute-to-pool (pool-id uint) (contribution-amount uint))
    (let
        ((pool-record (unwrap! (get-pool-details pool-id) ERR-POOL-DOES-NOT-EXIST))
         (existing-contribution (default-to { investment-amount: u0 }
            (get-investor-contribution pool-id tx-sender))))

        ;; Validate contribution
        (asserts! (>= contribution-amount minimum-contribution-amount) ERR-INVALID-CONTRIBUTION-AMOUNT)
        (asserts! (get is-active pool-record) ERR-POOL-DOES-NOT-EXIST)

        ;; Process STX transfer
        (try! (stx-transfer? contribution-amount tx-sender (as-contract tx-sender)))

        ;; Update pool records
        (map-set investment-pools
            { pool-id: pool-id }
            (merge pool-record { total-capital: (+ (get total-capital pool-record) contribution-amount) })
        )
        (map-set investor-contributions
            { pool-id: pool-id, investor-address: tx-sender }
            { investment-amount: (+ contribution-amount (get investment-amount existing-contribution)) }
        )
        (ok true)
    )
)

;; Update pool metadata
(define-public (update-pool-metadata 
    (pool-id uint)
    (pool-name (string-utf8 64))
    (pool-description (string-utf8 256))
    (investment-category (string-utf8 64))
    (brand-image-url (string-utf8 256)))

    (let
        ((pool-record (unwrap! (get-pool-details pool-id) ERR-POOL-DOES-NOT-EXIST)))

        ;; Authorization check
        (asserts! (is-eq tx-sender (get pool-creator pool-record)) ERR-UNAUTHORIZED-ACCESS)
        
        ;; Input validation
        (asserts! (> (len pool-name) u0) ERR-INVALID-METADATA-FORMAT)
        (asserts! (> (len pool-description) u0) ERR-INVALID-METADATA-FORMAT)
        
        ;; Store metadata
        (ok (map-set pool-descriptive-data
            { pool-id: pool-id }
            {
                pool-name: pool-name,
                pool-description: pool-description,
                investment-category: investment-category,
                brand-image-url: brand-image-url
            }
        ))
    )
)

;; Public Functions - Proposals & Voting

;; Create new investment proposal
(define-public (submit-investment-proposal 
    (pool-id uint)
    (recipient-address principal)
    (requested-amount uint)
    (proposal-description (string-utf8 256)))

    (let
        ((pool-record (unwrap! (get-pool-details pool-id) ERR-POOL-DOES-NOT-EXIST))
         (proposal-id (+ (var-get next-proposal-id) u1)))

        ;; Validate proposal requirements
        (asserts! (>= (get total-capital pool-record) proposal-funding-threshold) ERR-BELOW-FUNDING-THRESHOLD)
        (asserts! (<= requested-amount (get total-capital pool-record)) ERR-INSUFFICIENT-BALANCE)

        ;; Create proposal record
        (map-set investment-proposals
            { pool-id: pool-id, proposal-id: proposal-id }
            {
                recipient-address: recipient-address,
                requested-amount: requested-amount,
                proposal-description: proposal-description,
                support-votes: u0,
                opposition-votes: u0,
                proposal-status: u"active",
                submission-block: block-height
            }
        )
        (var-set next-proposal-id proposal-id)
        (ok proposal-id)
    )
)

;; Cast vote on a proposal
(define-public (cast-vote-on-proposal (pool-id uint) (proposal-id uint) (support-proposal bool))
    (let
        ((proposal-record (unwrap! (get-proposal-details pool-id proposal-id) ERR-POOL-DOES-NOT-EXIST))
         (investor-record (unwrap! (get-investor-contribution pool-id tx-sender) ERR-UNAUTHORIZED-ACCESS))
         (voting-power (get investment-amount investor-record)))

        ;; Check voting eligibility
        (asserts! (is-eq (get proposal-status proposal-record) u"active") ERR-VOTING-PERIOD-ENDED)
        (asserts! (is-none (get-investor-vote pool-id proposal-id tx-sender)) ERR-DUPLICATE-VOTE)

        ;; Record this vote
        (map-set investor-votes
            { pool-id: pool-id, proposal-id: proposal-id, voter-address: tx-sender }
            { vote-decision: support-proposal }
        )

        ;; Update vote tallies
        (map-set investment-proposals
            { pool-id: pool-id, proposal-id: proposal-id }
            (merge proposal-record {
                support-votes: (if support-proposal 
                    (+ (get support-votes proposal-record) voting-power)
                    (get support-votes proposal-record)),
                opposition-votes: (if support-proposal
                    (get opposition-votes proposal-record)
                    (+ (get opposition-votes proposal-record) voting-power))
            })
        )
        (ok true)
    )
)

;; Process the outcome of a proposal
(define-public (finalize-proposal (pool-id uint) (proposal-id uint))
    (let
        ((proposal-record (unwrap! (get-proposal-details pool-id proposal-id) ERR-POOL-DOES-NOT-EXIST))
         (pool-record (unwrap! (get-pool-details pool-id) ERR-POOL-DOES-NOT-EXIST)))

        ;; Validate proposal status
        (asserts! (is-eq (get proposal-status proposal-record) u"active") ERR-VOTING-PERIOD-ENDED)
        (asserts! (>= (- block-height (get submission-block proposal-record)) voting-duration-blocks) ERR-VOTING-PERIOD-ENDED)

        ;; Determine and execute outcome
        (if (> (get support-votes proposal-record) (get opposition-votes proposal-record))
            (begin
                ;; Transfer funds to recipient
                (try! (as-contract (stx-transfer? 
                    (get requested-amount proposal-record)
                    (as-contract tx-sender)
                    (get recipient-address proposal-record))))

                ;; Update proposal record
                (map-set investment-proposals
                    { pool-id: pool-id, proposal-id: proposal-id }
                    (merge proposal-record { proposal-status: u"executed" })
                )
                (ok true)
            )
            (begin
                ;; Mark proposal as rejected
                (map-set investment-proposals
                    { pool-id: pool-id, proposal-id: proposal-id }
                    (merge proposal-record { proposal-status: u"rejected" })
                )
                (ok false)
            )
        )
    )
)

;; Public Functions - Staking & Rewards

;; Update staking reward rate (admin only)
(define-public (update-staking-reward-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-admin) ERR-UNAUTHORIZED-ACCESS)
        (ok (var-set staking-reward-rate new-rate))
    )
)

;; Stake funds in a pool
(define-public (stake-pool-contribution (pool-id uint) (stake-amount uint))
    (let
        ((pool-record (unwrap! (get-pool-details pool-id) ERR-POOL-DOES-NOT-EXIST))
         (investor-record (unwrap! (get-investor-contribution pool-id tx-sender) ERR-UNAUTHORIZED-ACCESS))
         (existing-stake (get-investor-stake pool-id tx-sender)))
        
        ;; Validate staking request
        (asserts! (get is-active pool-record) ERR-POOL-DOES-NOT-EXIST)
        (asserts! (<= stake-amount (get investment-amount investor-record)) ERR-INSUFFICIENT-BALANCE)
        (asserts! (> stake-amount u0) ERR-INVALID-CONTRIBUTION-AMOUNT)
        
        ;; Process existing rewards if already staking
        (if (is-some existing-stake)
            (try! (claim-staking-rewards pool-id))
            true)
        
        ;; Create or update stake record
        (ok (map-set investor-stakes
            { pool-id: pool-id, staker-address: tx-sender }
            {
                staked-amount: (+ (default-to u0 (get staked-amount existing-stake)) stake-amount),
                stake-initiation-block: block-height,
                last-reward-block: block-height
            }
        ))
    )
)

;; Claim staking rewards
(define-public (claim-staking-rewards (pool-id uint))
    (let
        ((stake-record (unwrap! (get-investor-stake pool-id tx-sender) ERR-NO-ACTIVE-STAKE)))

        (let
            ((elapsed-blocks (- block-height (get last-reward-block stake-record)))
             (staked-capital (get staked-amount stake-record))
             (reward-amount (* (* elapsed-blocks (var-get staking-reward-rate)) staked-capital)))

            ;; Update last claim timestamp
            (map-set investor-stakes
                { pool-id: pool-id, staker-address: tx-sender }
                (merge stake-record { last-reward-block: block-height })
            )

            ;; Process reward transfer if earned
            (if (> reward-amount u0)
                (as-contract (stx-transfer? reward-amount tx-sender tx-sender))
                (ok true))
        )
    )
)