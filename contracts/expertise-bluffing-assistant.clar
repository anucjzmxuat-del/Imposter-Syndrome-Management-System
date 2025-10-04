;; Expertise Bluffing Assistant
;; Real-time coaching for nodding knowingly at technologies you've never heard of
;; Helps manage imposter syndrome by providing confident-sounding responses to technical discussions

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u300))
(define-constant ERR-NOT-FOUND (err u301))
(define-constant ERR-INVALID-INPUT (err u302))
(define-constant ERR-RESPONSE-GENERATION-FAILED (err u303))
(define-constant ERR-SCENARIO-EXISTS (err u304))

(define-constant MAX-RESPONSE-LENGTH u300)
(define-constant MAX-TECHNOLOGY-NAME u50)
(define-constant DEFAULT-CONFIDENCE-BOOST u15)

;; Data structures
(define-map technology-buzzwords
    { tech: (string-ascii 50) }
    { buzzword-phrases: (list 5 (string-ascii 100)),
      credibility-score: uint,
      difficulty-level: uint,
      category: (string-ascii 30),
      trend-status: (string-ascii 20)
    }
)

(define-map conversation-responses
    { response-id: uint }
    { technology: (string-ascii 50),
      context: (string-ascii 100),
      generated-response: (string-ascii 300),
      confidence-level: uint,
      believability-score: uint,
      timestamp: uint,
      user: principal
    }
)

(define-map user-bluffing-stats
    { user: principal }
    { total-responses-generated: uint,
      successful-bluffs: uint,
      confidence-boost-total: uint,
      favorite-technologies: (list 5 (string-ascii 50)),
      expertise-reputation: uint
    }
)

(define-map networking-scenarios
    { scenario: (string-ascii 30) }
    { context-description: (string-ascii 200),
      recommended-responses: (list 3 (string-ascii 150)),
      success-rate: uint,
      difficulty: uint
    }
)

(define-map industry-trends
    { trend-id: uint }
    { technology: (string-ascii 50),
      trend-description: (string-ascii 200),
      hype-level: uint,
      adoption-rate: uint,
      buzzword-density: uint
    }
)

;; Data variables
(define-data-var next-response-id uint u1)
(define-data-var total-bluffs-generated uint u0)
(define-data-var next-trend-id uint u1)
(define-data-var global-confidence-multiplier uint u125)

;; Private functions

(define-private (validate-technology-name (tech (string-ascii 50)))
    (and
        (> (len tech) u0)
        (<= (len tech) MAX-TECHNOLOGY-NAME)
    )
)

(define-private (generate-confidence-score (tech (string-ascii 50)) (context (string-ascii 100)))
    (let
        ((tech-data (map-get? technology-buzzwords { tech: tech }))
         (base-confidence (if (is-some tech-data)
                             (get credibility-score (unwrap-panic tech-data))
                             u50))
         (context-bonus (if (> (len context) u12)
                           (if (is-eq (unwrap-panic (slice? context u0 u12)) "architecture")
                               u20
                               u5)
                           u5)))
        (if (<= (+ base-confidence context-bonus) u100)
            (+ base-confidence context-bonus)
            u100)
    )
)

(define-private (generate-technical-response (tech (string-ascii 50)) (context (string-ascii 100)))
    (let
        ((tech-data (map-get? technology-buzzwords { tech: tech })))
        (if (is-some tech-data)
            (let
                ((buzzwords (get buzzword-phrases (unwrap-panic tech-data)))
                 (category (get category (unwrap-panic tech-data))))
                (if (is-eq category "frontend")
                    "Interesting approach. Have you considered the performance implications of the virtual DOM reconciliation process?"
                    (if (is-eq category "backend")
                        "That's a solid choice. The horizontal scaling capabilities and microservice orchestration patterns are quite mature."
                        "Absolutely, the ecosystem integration and developer experience optimizations are really compelling."
                    )
                )
            )
            "Fascinating technology. The architectural patterns and implementation strategies seem quite innovative."
        )
    )
)

(define-private (calculate-believability-score (response (string-ascii 300)) (confidence-level uint))
    (let
        ((buzzword-count (if (> (len response) u12)
                            (if (is-eq (unwrap-panic (slice? response u0 u12)) "architecture")
                                u8
                                u3)
                            u3))
         (confidence-factor (/ (* confidence-level u2) u10)))
        (if (<= (+ buzzword-count confidence-factor) u100)
            (+ buzzword-count confidence-factor)
            u100)
    )
)

(define-private (update-user-bluffing-stats (user principal) (confidence-boost uint))
    (let
        ((current-stats (default-to
                           { total-responses-generated: u0,
                             successful-bluffs: u0,
                             confidence-boost-total: u0,
                             favorite-technologies: (list),
                             expertise-reputation: u50 }
                           (map-get? user-bluffing-stats { user: user })))
         (new-total (+ (get total-responses-generated current-stats) u1))
         (new-confidence-total (+ (get confidence-boost-total current-stats) confidence-boost))
         (new-reputation (if (<= (+ (get expertise-reputation current-stats) u2) u100)
                            (+ (get expertise-reputation current-stats) u2)
                            u100)))
        (map-set user-bluffing-stats
            { user: user }
            (merge current-stats
                { total-responses-generated: new-total,
                  successful-bluffs: (+ (get successful-bluffs current-stats) u1),
                  confidence-boost-total: new-confidence-total,
                  expertise-reputation: new-reputation
                }
            )
        )
    )
)

;; Public functions

;; Generate contextually appropriate response for unknown technology
(define-public (generate-response (technology (string-ascii 50)) (context (string-ascii 100)))
    (let
        ((user tx-sender)
         (response-id (var-get next-response-id))
         (confidence-level (generate-confidence-score technology context))
         (generated-text (generate-technical-response technology context))
         (believability (calculate-believability-score generated-text confidence-level)))
        (asserts! (validate-technology-name technology) ERR-INVALID-INPUT)
        (map-set conversation-responses
            { response-id: response-id }
            { technology: technology,
              context: context,
              generated-response: generated-text,
              confidence-level: confidence-level,
              believability-score: believability,
              timestamp: stacks-block-height,
              user: user
            }
        )
        (update-user-bluffing-stats user confidence-level)
        (var-set next-response-id (+ response-id u1))
        (var-set total-bluffs-generated (+ (var-get total-bluffs-generated) u1))
        (ok { response-id: response-id,
              generated-response: generated-text,
              confidence-level: confidence-level,
              believability-score: believability,
              coaching-tip: "Nod confidently while speaking, maintain eye contact, and use hand gestures for emphasis."
            }
        )
    )
)

;; Update technology buzzwords database
(define-public (update-buzzwords (technology (string-ascii 50)) (phrases (list 5 (string-ascii 100))) (credibility uint) (difficulty uint) (category (string-ascii 30)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (asserts! (validate-technology-name technology) ERR-INVALID-INPUT)
        (asserts! (<= credibility u100) ERR-INVALID-INPUT)
        (asserts! (<= difficulty u5) ERR-INVALID-INPUT)
        (map-set technology-buzzwords
            { tech: technology }
            { buzzword-phrases: phrases,
              credibility-score: credibility,
              difficulty-level: difficulty,
              category: category,
              trend-status: "trending"
            }
        )
        (ok true)
    )
)

;; Practice networking conversation scenarios
(define-public (practice-scenarios (scenario (string-ascii 30)))
    (let
        ((scenario-data (map-get? networking-scenarios { scenario: scenario }))
         (user tx-sender))
        (if (is-some scenario-data)
            (let
                ((scenario-info (unwrap-panic scenario-data)))
                (ok { scenario: scenario,
                      context: (get context-description scenario-info),
                      recommended-responses: (get recommended-responses scenario-info),
                      success-rate: (get success-rate scenario-info),
                      practice-tip: "Practice in front of a mirror, record yourself, or role-play with a trusted colleague."
                    }
                )
            )
            (ok { scenario: scenario,
                  context: "General professional networking conversation",
                  recommended-responses: (list "That's an interesting perspective" "I'd love to learn more about your approach" "How has that worked out for your team?"),
                  success-rate: u70,
                  practice-tip: "Ask thoughtful questions to shift focus away from your own knowledge gaps."
                }
            )
        )
    )
)

;; Get real-time confidence coaching for professional interactions
(define-public (confidence-coaching (interaction-type (string-ascii 30)))
    (let
        ((user tx-sender)
         (user-stats (map-get? user-bluffing-stats { user: user }))
         (base-coaching "Stand tall, speak clearly, and remember that everyone is learning something new every day."))
        (if (is-eq interaction-type "technical-interview")
            (ok "Focus on problem-solving approach rather than memorized answers. It's okay to think out loud and ask clarifying questions.")
            (if (is-eq interaction-type "team-meeting")
                (ok "Listen actively, take notes, and contribute thoughtful questions. Your perspective as someone still learning is valuable.")
                (if (is-eq interaction-type "conference-networking")
                    (ok "Ask others about their work and experiences. People love talking about what they do, and you'll learn while appearing engaged.")
                    (ok base-coaching)
                )
            )
        )
    )
)

;; Admin function: Add networking scenario
(define-public (add-scenario (scenario (string-ascii 30)) (description (string-ascii 200)) (responses (list 3 (string-ascii 150))) (success-rate uint) (difficulty uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (asserts! (<= success-rate u100) ERR-INVALID-INPUT)
        (asserts! (<= difficulty u5) ERR-INVALID-INPUT)
        (map-set networking-scenarios
            { scenario: scenario }
            { context-description: description,
              recommended-responses: responses,
              success-rate: success-rate,
              difficulty: difficulty
            }
        )
        (ok true)
    )
)

;; Add industry trend information
(define-public (add-industry-trend (technology (string-ascii 50)) (description (string-ascii 200)) (hype-level uint) (adoption-rate uint) (buzzword-density uint))
    (let
        ((trend-id (var-get next-trend-id)))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (asserts! (validate-technology-name technology) ERR-INVALID-INPUT)
        (asserts! (<= hype-level u100) ERR-INVALID-INPUT)
        (asserts! (<= adoption-rate u100) ERR-INVALID-INPUT)
        (map-set industry-trends
            { trend-id: trend-id }
            { technology: technology,
              trend-description: description,
              hype-level: hype-level,
              adoption-rate: adoption-rate,
              buzzword-density: buzzword-density
            }
        )
        (var-set next-trend-id (+ trend-id u1))
        (ok trend-id)
    )
)

;; Read-only functions

;; Get generated response by ID
(define-read-only (get-response (response-id uint))
    (map-get? conversation-responses { response-id: response-id })
)

;; Get user bluffing statistics
(define-read-only (get-user-bluffing-stats (user principal))
    (map-get? user-bluffing-stats { user: user })
)

;; Get technology buzzwords
(define-read-only (get-technology-buzzwords (tech (string-ascii 50)))
    (map-get? technology-buzzwords { tech: tech })
)

;; Get networking scenario info
(define-read-only (get-scenario-info (scenario (string-ascii 30)))
    (map-get? networking-scenarios { scenario: scenario })
)

;; Get industry trend by ID
(define-read-only (get-industry-trend (trend-id uint))
    (map-get? industry-trends { trend-id: trend-id })
)

;; Get system bluffing statistics
(define-read-only (get-system-stats)
    (ok { total-bluffs-generated: (var-get total-bluffs-generated),
          next-response-id: (var-get next-response-id),
          global-confidence-multiplier: (var-get global-confidence-multiplier),
          next-trend-id: (var-get next-trend-id)
        }
    )
)
