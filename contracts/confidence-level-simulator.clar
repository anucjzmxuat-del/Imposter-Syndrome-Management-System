;; Confidence Level Simulator
;; Artificial self-assurance generator for job interviews and performance reviews
;; Helps manage imposter syndrome by providing dynamic confidence scoring and boosting

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-INVALID-CONFIDENCE (err u102))
(define-constant ERR-INVALID-SCENARIO (err u103))
(define-constant ERR-ALREADY-EXISTS (err u104))

(define-constant MIN-CONFIDENCE u0)
(define-constant MAX-CONFIDENCE u100)
(define-constant DEFAULT-BOOST u10)
(define-constant MAX-BOOST u25)

;; Data structures
(define-map user-confidence
    { user: principal }
    { base-confidence: uint,
      current-confidence: uint,
      profession: (string-ascii 50),
      last-updated: uint,
      total-boosts: uint
    }
)

(define-map confidence-scenarios
    { scenario: (string-ascii 30) }
    { boost-amount: uint,
      description: (string-ascii 100),
      success-rate: uint
    }
)

(define-map user-affirmations
    { user: principal, scenario: (string-ascii 30) }
    { affirmation: (string-ascii 200),
      confidence-boost: uint,
      times-used: uint
    }
)

(define-map confidence-history
    { user: principal, timestamp: uint }
    { confidence-level: uint,
      scenario: (string-ascii 30),
      action: (string-ascii 20)
    }
)

;; Data variables
(define-data-var total-users uint u0)
(define-data-var total-boosts uint u0)
(define-data-var confidence-multiplier uint u100)

;; Private functions

(define-private (validate-confidence (confidence uint))
    (and (>= confidence MIN-CONFIDENCE) (<= confidence MAX-CONFIDENCE))
)

(define-private (calculate-confidence-boost (base-confidence uint) (boost-amount uint))
    (let
        ((new-confidence (+ base-confidence boost-amount)))
        (if (<= new-confidence MAX-CONFIDENCE)
            new-confidence
            MAX-CONFIDENCE
        )
    )
)

(define-private (generate-affirmation-text (profession (string-ascii 50)) (scenario (string-ascii 30)))
    (if (is-eq scenario "technical-interview")
        "I am a competent developer with valuable skills and experience"
        (if (is-eq scenario "performance-review")
            "My contributions are meaningful and my growth is evident"
            "I belong here and deserve my position in this field"
        )
    )
)

(define-private (record-confidence-change (user principal) (scenario (string-ascii 30)) (action (string-ascii 20)) (confidence uint))
    (map-set confidence-history
        { user: user, timestamp: stacks-block-height }
        { confidence-level: confidence, scenario: scenario, action: action }
    )
)

;; Public functions

;; Initialize user confidence profile
(define-public (initialize-confidence (base-confidence uint) (profession (string-ascii 50)))
    (let
        ((user tx-sender))
        (asserts! (validate-confidence base-confidence) ERR-INVALID-CONFIDENCE)
        (asserts! (is-none (map-get? user-confidence { user: user })) ERR-ALREADY-EXISTS)
        (map-set user-confidence
            { user: user }
            { base-confidence: base-confidence,
              current-confidence: base-confidence,
              profession: profession,
              last-updated: stacks-block-height,
              total-boosts: u0
            }
        )
        (var-set total-users (+ (var-get total-users) u1))
        (record-confidence-change user "initialization" "create" base-confidence)
        (ok true)
    )
)

;; Boost confidence for specific scenario
(define-public (boost-confidence (scenario (string-ascii 30)) (boost-amount uint))
    (let
        ((user tx-sender)
         (user-data (unwrap! (map-get? user-confidence { user: user }) ERR-NOT-FOUND))
         (current-confidence (get current-confidence user-data))
         (scenario-data (map-get? confidence-scenarios { scenario: scenario }))
         (actual-boost (if (is-some scenario-data)
                          (get boost-amount (unwrap-panic scenario-data))
                          boost-amount))
         (new-confidence (calculate-confidence-boost current-confidence actual-boost)))
        (asserts! (<= boost-amount MAX-BOOST) ERR-INVALID-CONFIDENCE)
        (map-set user-confidence
            { user: user }
            (merge user-data
                { current-confidence: new-confidence,
                  last-updated: stacks-block-height,
                  total-boosts: (+ (get total-boosts user-data) u1)
                }
            )
        )
        (var-set total-boosts (+ (var-get total-boosts) u1))
        (record-confidence-change user scenario "boost" new-confidence)
        (ok new-confidence)
    )
)

;; Generate personalized affirmation
(define-public (generate-affirmation (scenario (string-ascii 30)))
    (let
        ((user tx-sender)
         (user-data (unwrap! (map-get? user-confidence { user: user }) ERR-NOT-FOUND))
         (profession (get profession user-data))
         (affirmation-text (generate-affirmation-text profession scenario))
         (existing-affirmation (map-get? user-affirmations { user: user, scenario: scenario })))
        (if (is-some existing-affirmation)
            (let
                ((current-affirmation (unwrap-panic existing-affirmation)))
                (map-set user-affirmations
                    { user: user, scenario: scenario }
                    (merge current-affirmation
                        { times-used: (+ (get times-used current-affirmation) u1) }
                    )
                )
            )
            (map-set user-affirmations
                { user: user, scenario: scenario }
                { affirmation: affirmation-text,
                  confidence-boost: DEFAULT-BOOST,
                  times-used: u1
                }
            )
        )
        (ok affirmation-text)
    )
)

;; Track confidence progress over time
(define-public (track-progress)
    (let
        ((user tx-sender)
         (user-data (unwrap! (map-get? user-confidence { user: user }) ERR-NOT-FOUND))
         (base-confidence (get base-confidence user-data))
         (current-confidence (get current-confidence user-data))
         (user-total-boosts (get total-boosts user-data))
         (progress-ratio (if (> base-confidence u0)
                            (/ (* (- current-confidence base-confidence) u100) base-confidence)
                            u0)))
        (ok { base-confidence: base-confidence,
              current-confidence: current-confidence,
              total-boosts: user-total-boosts,
              progress-percentage: progress-ratio,
              profession: (get profession user-data),
              last-updated: (get last-updated user-data)
            }
        )
    )
)

;; Admin function: Add confidence scenario
(define-public (add-scenario (scenario (string-ascii 30)) (boost-amount uint) (description (string-ascii 100)) (success-rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (asserts! (validate-confidence boost-amount) ERR-INVALID-CONFIDENCE)
        (asserts! (<= success-rate u100) ERR-INVALID-CONFIDENCE)
        (map-set confidence-scenarios
            { scenario: scenario }
            { boost-amount: boost-amount,
              description: description,
              success-rate: success-rate
            }
        )
        (ok true)
    )
)

;; Reset confidence to base level (for testing or emergency)
(define-public (reset-confidence)
    (let
        ((user tx-sender)
         (user-data (unwrap! (map-get? user-confidence { user: user }) ERR-NOT-FOUND))
         (base-confidence (get base-confidence user-data)))
        (map-set user-confidence
            { user: user }
            (merge user-data
                { current-confidence: base-confidence,
                  last-updated: stacks-block-height
                }
            )
        )
        (record-confidence-change user "reset" "reset" base-confidence)
        (ok base-confidence)
    )
)

;; Read-only functions

;; Get user confidence data
(define-read-only (get-user-confidence (user principal))
    (map-get? user-confidence { user: user })
)

;; Get scenario information
(define-read-only (get-scenario-info (scenario (string-ascii 30)))
    (map-get? confidence-scenarios { scenario: scenario })
)

;; Get user affirmation
(define-read-only (get-user-affirmation (user principal) (scenario (string-ascii 30)))
    (map-get? user-affirmations { user: user, scenario: scenario })
)

;; Get confidence history entry
(define-read-only (get-confidence-history (user principal) (timestamp uint))
    (map-get? confidence-history { user: user, timestamp: timestamp })
)

;; Get system stats
(define-read-only (get-system-stats)
    (ok { total-users: (var-get total-users),
          total-boosts: (var-get total-boosts),
          confidence-multiplier: (var-get confidence-multiplier)
        }
    )
)
