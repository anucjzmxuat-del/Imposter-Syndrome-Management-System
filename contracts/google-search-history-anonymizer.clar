;; Google Search History Anonymizer
;; Obfuscates embarrassingly basic programming questions from senior developer search logs
;; Helps manage imposter syndrome by protecting against embarrassing search history exposure

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u200))
(define-constant ERR-NOT-FOUND (err u201))
(define-constant ERR-INVALID-QUERY (err u202))
(define-constant ERR-ANONYMIZATION-FAILED (err u203))
(define-constant ERR-ALREADY-PROCESSED (err u204))

(define-constant MAX-QUERY-LENGTH u500)
(define-constant MIN-QUERY-LENGTH u3)
(define-constant ANONYMIZATION-SCORE-MULTIPLIER u10)

;; Data structures
(define-map search-queries
    { query-id: uint }
    { original-hash: (buff 32),
      anonymized-query: (string-ascii 200),
      embarrassment-level: uint,
      category: (string-ascii 30),
      timestamp: uint,
      user: principal
    }
)

(define-map user-search-stats
    { user: principal }
    { total-searches: uint,
      anonymized-count: uint,
      embarrassment-points: uint,
      knowledge-gaps: (list 10 (string-ascii 50)),
      improvement-score: uint
    }
)

(define-map embarrassing-keywords
    { keyword: (string-ascii 50) }
    { embarrassment-weight: uint,
      category: (string-ascii 30),
      suggested-replacement: (string-ascii 100)
    }
)

(define-map learning-resources
    { topic: (string-ascii 50) }
    { resource-url: (string-ascii 200),
      difficulty-level: uint,
      estimated-time: uint,
      description: (string-ascii 150)
    }
)

(define-map knowledge-gaps
    { user: principal, topic: (string-ascii 50) }
    { gap-level: uint,
      first-identified: uint,
      times-searched: uint,
      improvement-progress: uint
    }
)

;; Data variables
(define-data-var next-query-id uint u1)
(define-data-var total-anonymizations uint u0)
(define-data-var privacy-protection-level uint u75)

;; Private functions

(define-private (validate-query (query (string-ascii 200)))
    (and 
        (>= (len query) MIN-QUERY-LENGTH)
        (<= (len query) MAX-QUERY-LENGTH)
    )
)

(define-private (calculate-embarrassment-level (query (string-ascii 200)))
    (let
        ((basic-terms-count (if (> (len query) u7)
                               (if (is-eq (unwrap-panic (slice? query u0 u6)) "how to")
                                   u15
                                   (if (> (len query) u8)
                                       (if (is-eq (unwrap-panic (slice? query u0 u7)) "what is")
                                           u10
                                           u0)
                                       u0))
                               u0))
         (beginner-indicators (if (> (len query) u11)
                                 (if (is-eq (unwrap-panic (slice? query (- (len query) u11) (len query))) "for dummies")
                                     u20
                                     u0)
                                 u0))
         (senior-shame u5))
        (+ basic-terms-count beginner-indicators senior-shame)
    )
)

(define-private (categorize-query (query (string-ascii 200)))
    (if (> (len query) u3)
        (if (is-eq (unwrap-panic (slice? query u0 u3)) "git")
            "version-control"
            (if (> (len query) u3)
                (if (is-eq (unwrap-panic (slice? query u0 u3)) "css")
                    "frontend"
                    "general"
                )
                "general"
            )
        )
        "general"
    )
)

(define-private (generate-anonymized-query (original-query (string-ascii 200)) (embarrassment-level uint))
    (if (> embarrassment-level u20)
        "Advanced architectural pattern research query"
        (if (> embarrassment-level u10)
            "Complex technical implementation investigation"
            "Professional development research topic"
        )
    )
)

(define-private (create-query-hash (query (string-ascii 200)))
    (sha256 (concat (unwrap-panic (to-consensus-buff? query)) (unwrap-panic (to-consensus-buff? stacks-block-height))))
)

(define-private (update-user-knowledge-gaps (user principal) (category (string-ascii 30)) (embarrassment-level uint))
    (let
        ((current-stats (default-to
                           { total-searches: u0,
                             anonymized-count: u0,
                             embarrassment-points: u0,
                             knowledge-gaps: (list),
                             improvement-score: u0 }
                           (map-get? user-search-stats { user: user })))
         (new-embarrassment-points (+ (get embarrassment-points current-stats) embarrassment-level))
         (new-total-searches (+ (get total-searches current-stats) u1))
         (new-anonymized-count (+ (get anonymized-count current-stats) u1)))
        (map-set user-search-stats
            { user: user }
            (merge current-stats
                { total-searches: new-total-searches,
                  anonymized-count: new-anonymized-count,
                  embarrassment-points: new-embarrassment-points,
                  improvement-score: (/ (* new-anonymized-count u100) new-total-searches)
                }
            )
        )
    )
)

;; Public functions

;; Anonymize a search query
(define-public (anonymize-query (query (string-ascii 200)))
    (let
        ((user tx-sender)
         (query-id (var-get next-query-id))
         (query-hash (create-query-hash query))
         (embarrassment-level (calculate-embarrassment-level query))
         (category (categorize-query query))
         (anonymized-text (generate-anonymized-query query embarrassment-level)))
        (asserts! (validate-query query) ERR-INVALID-QUERY)
        (map-set search-queries
            { query-id: query-id }
            { original-hash: query-hash,
              anonymized-query: anonymized-text,
              embarrassment-level: embarrassment-level,
              category: category,
              timestamp: stacks-block-height,
              user: user
            }
        )
        (update-user-knowledge-gaps user category embarrassment-level)
        (var-set next-query-id (+ query-id u1))
        (var-set total-anonymizations (+ (var-get total-anonymizations) u1))
        (ok { query-id: query-id,
              anonymized-query: anonymized-text,
              embarrassment-level: embarrassment-level,
              privacy-protected: true
            }
        )
    )
)

;; Analyze knowledge gaps for a user
(define-public (analyze-knowledge-gaps)
    (let
        ((user tx-sender)
         (user-stats (unwrap! (map-get? user-search-stats { user: user }) ERR-NOT-FOUND))
         (embarrassment-points (get embarrassment-points user-stats))
         (total-searches (get total-searches user-stats))
         (improvement-score (get improvement-score user-stats))
         (average-embarrassment (if (> total-searches u0)
                                   (/ embarrassment-points total-searches)
                                   u0)))
        (ok { total-searches: total-searches,
              embarrassment-points: embarrassment-points,
              average-embarrassment: average-embarrassment,
              improvement-score: improvement-score,
              analysis-complete: true
            }
        )
    )
)

;; Suggest learning resources based on knowledge gaps
(define-public (suggest-resources (topic (string-ascii 50)))
    (let
        ((user tx-sender)
         (user-stats (map-get? user-search-stats { user: user }))
         (resource-info (map-get? learning-resources { topic: topic })))
        (if (is-some resource-info)
            (ok (unwrap-panic resource-info))
            (ok { resource-url: "https://developer.mozilla.org",
                  difficulty-level: u1,
                  estimated-time: u30,
                  description: "General web development resources for skill improvement"
                }
            )
        )
    )
)

;; Track improvement in knowledge areas
(define-public (track-improvement (topic (string-ascii 50)) (progress-score uint))
    (let
        ((user tx-sender)
         (existing-gap (map-get? knowledge-gaps { user: user, topic: topic })))
        (asserts! (<= progress-score u100) ERR-INVALID-QUERY)
        (if (is-some existing-gap)
            (let
                ((gap-data (unwrap-panic existing-gap)))
                (map-set knowledge-gaps
                    { user: user, topic: topic }
                    (merge gap-data
                        { improvement-progress: progress-score }
                    )
                )
            )
            (map-set knowledge-gaps
                { user: user, topic: topic }
                { gap-level: u50,
                  first-identified: stacks-block-height,
                  times-searched: u1,
                  improvement-progress: progress-score
                }
            )
        )
        (ok progress-score)
    )
)

;; Admin function: Add embarrassing keyword
(define-public (add-embarrassing-keyword (keyword (string-ascii 50)) (weight uint) (category (string-ascii 30)) (replacement (string-ascii 100)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (asserts! (<= weight u50) ERR-INVALID-QUERY)
        (map-set embarrassing-keywords
            { keyword: keyword }
            { embarrassment-weight: weight,
              category: category,
              suggested-replacement: replacement
            }
        )
        (ok true)
    )
)

;; Admin function: Add learning resource
(define-public (add-learning-resource (topic (string-ascii 50)) (url (string-ascii 200)) (difficulty uint) (time uint) (description (string-ascii 150)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (asserts! (<= difficulty u5) ERR-INVALID-QUERY)
        (map-set learning-resources
            { topic: topic }
            { resource-url: url,
              difficulty-level: difficulty,
              estimated-time: time,
              description: description
            }
        )
        (ok true)
    )
)

;; Read-only functions

;; Get anonymized query by ID
(define-read-only (get-anonymized-query (query-id uint))
    (map-get? search-queries { query-id: query-id })
)

;; Get user search statistics
(define-read-only (get-user-stats (user principal))
    (map-get? user-search-stats { user: user })
)

;; Get embarrassing keyword info
(define-read-only (get-keyword-info (keyword (string-ascii 50)))
    (map-get? embarrassing-keywords { keyword: keyword })
)

;; Get learning resource
(define-read-only (get-learning-resource (topic (string-ascii 50)))
    (map-get? learning-resources { topic: topic })
)

;; Get knowledge gap information
(define-read-only (get-knowledge-gap (user principal) (topic (string-ascii 50)))
    (map-get? knowledge-gaps { user: user, topic: topic })
)

;; Get system anonymization stats
(define-read-only (get-anonymization-stats)
    (ok { total-anonymizations: (var-get total-anonymizations),
          privacy-protection-level: (var-get privacy-protection-level),
          next-query-id: (var-get next-query-id)
        }
    )
)
