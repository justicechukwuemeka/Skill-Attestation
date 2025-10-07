;; Decentralized Skill Certification Platform Smart Contract
;; A blockchain-based peer-to-peer skill validation system enabling transparent 
;; professional certification through consensus-driven evaluations. The platform
;; leverages distributed assessment to create immutable, verifiable credentials
;; while maintaining evaluator accountability through reputation mechanisms.

;; Platform administrator who can create skill categories
(define-constant contract-owner tx-sender)

;; Assessment configuration: minimum evaluators needed for valid certification
(define-constant min-evaluators-required u3)

;; Score threshold: minimum average score needed to pass certification (out of 100)
(define-constant passing-score-threshold u70)

;; Maximum number of evaluators allowed per assessment to prevent spam
(define-constant max-evaluators-per-assessment u20)

;; Consensus tolerance: acceptable score deviation for reputation rewards
(define-constant consensus-variance-tolerance u15)

;; Reputation penalty for evaluations that deviate from consensus
(define-constant reputation-penalty-amount u5)

;; Reputation reward for evaluations that align with consensus
(define-constant reputation-reward-amount u2)

;; Error returned when caller lacks required permissions
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))

;; Error returned when attempting to register an already registered user
(define-constant ERR-USER-ALREADY-REGISTERED (err u101))

;; Error returned when user profile cannot be found
(define-constant ERR-USER-NOT-FOUND (err u102))

;; Error returned when finalizing assessment without minimum evaluators
(define-constant ERR-INSUFFICIENT-EVALUATOR-COUNT (err u103))

;; Error returned when assessment already exists for user-skill combination
(define-constant ERR-ASSESSMENT-ALREADY-ACTIVE (err u104))

;; Error returned when evaluator limit reached for assessment
(define-constant ERR-EVALUATOR-CAPACITY-EXCEEDED (err u105))

;; Error returned when score value is invalid (above 100)
(define-constant ERR-INVALID-SCORE-VALUE (err u106))

;; Error returned when skill category does not exist
(define-constant ERR-SKILL-DOES-NOT-EXIST (err u107))

;; Error returned when input parameters fail validation
(define-constant ERR-INVALID-INPUT-PARAMETERS (err u108))

;; Stores comprehensive profile data for each registered platform member
;; Tracks certification achievements, reputation, and evaluation history
(define-map user-profiles 
    principal 
    {
        is-registered: bool,
        certified-skill-ids: (list 20 uint),
        overall-reputation: uint,
        total-evaluations-performed: uint,
        consensus-deviation-count: uint
    }
)

;; Tracks evaluator expertise and performance within specific skill domains
;; Enables reputation differentiation across different professional areas
(define-map skill-specific-evaluator-stats
    {evaluator: principal, skill-id: uint}
    {
        domain-reputation: uint,
        evaluations-in-domain: uint,
        consensus-aligned-evaluations: uint
    }
)

;; Defines available skill categories with requirements and metadata
;; Created by platform administrator to expand certification offerings
(define-map skill-categories 
    uint 
    {
        name: (string-ascii 50),
        description: (string-ascii 200),
        min-passing-score: uint,
        domain: (string-ascii 50)
    }
)

;; Tracks active assessment sessions with evaluator participation and results
;; Stores cumulative scores and statistical measures for consensus analysis
(define-map active-assessments
    {skill-id: uint, candidate: principal}
    {
        evaluators: (list 20 principal),
        scores: (list 20 uint),
        is-certified: bool,
        created-at-block: uint,
        average-score: uint,
        score-standard-deviation: uint
    }
)

;; Counter for generating unique skill category identifiers
(define-data-var skill-id-counter uint u0)

;; Checks if a skill category exists in the system
(define-private (does-skill-exist (skill-id uint))
    (match (map-get? skill-categories skill-id)
        skill-data true
        false
    )
)

;; Validates that description text is non-empty and within length limit
(define-private (is-valid-description (text (string-ascii 200)))
    (and 
        (not (is-eq text ""))
        (<= (len text) u200)
    )
)

;; Validates that short text field is non-empty and within length limit
(define-private (is-valid-short-text (text (string-ascii 50)))
    (and 
        (not (is-eq text ""))
        (<= (len text) u50)
    )
)

;; Validates skill name meets requirements
(define-private (is-valid-skill-name (name (string-ascii 50)))
    (and 
        (not (is-eq name ""))
        (<= (len name) u50)
    )
)

;; Validates category name meets requirements
(define-private (is-valid-category-name (name (string-ascii 50)))
    (and 
        (not (is-eq name ""))
        (<= (len name) u50)
    )
)

;; Validates description field meets requirements
(define-private (is-valid-description-field (desc (string-ascii 200)))
    (and 
        (not (is-eq desc ""))
        (<= (len desc) u200)
    )
)

;; Calculates the square of a number for variance computation
(define-private (square (value uint))
    (* value value)
)

;; Computes arithmetic mean of a list of numeric values
(define-private (calculate-average (numbers (list 20 uint)))
    (let (
        (sum (fold + numbers u0))
        (count (len numbers))
    )
    (if (> count u0)
        (/ sum count)
        u0
    ))
)

;; Calculates squared difference from mean for variance computation
(define-private (squared-deviation (value uint) (mean uint))
    (square (if (> value mean) 
        (- value mean)
        (- mean value)
    ))
)

;; Computes standard deviation to measure score distribution consistency
(define-private (calculate-std-deviation (values (list 20 uint)) (mean uint))
    (let (
        (count (len values))
        (squared-devs (map squared-deviation values (list count mean)))
        (variance-sum (fold + squared-devs u0))
    )
    (if (> count u1)
        (integer-sqrt (/ variance-sum (- count u1)))
        u0
    ))
)

;; Approximates square root using integer arithmetic
(define-private (integer-sqrt (n uint))
    (let ((estimate (/ n u2)))
        (if (>= estimate n)
            u1
            estimate
        )
    )
)

;; Updates evaluator reputation based on consensus alignment
;; Rewards evaluators who align with group consensus, penalizes outliers
(define-private (update-evaluator-reputation (evaluator principal) (skill-id uint) (in-consensus bool))
    (begin
        (let (
            (user-profile (unwrap! (map-get? user-profiles evaluator) false))
            (skill-stats (default-to 
                {domain-reputation: u0, evaluations-in-domain: u0, consensus-aligned-evaluations: u0}
                (map-get? skill-specific-evaluator-stats {evaluator: evaluator, skill-id: skill-id})))
        )
            ;; Update overall user profile with reputation changes
            (map-set user-profiles evaluator
                (merge user-profile {
                    overall-reputation: (if in-consensus
                        (+ (get overall-reputation user-profile) reputation-reward-amount)
                        (if (> (get overall-reputation user-profile) reputation-penalty-amount)
                            (- (get overall-reputation user-profile) reputation-penalty-amount)
                            u0
                        )),
                    total-evaluations-performed: (+ (get total-evaluations-performed user-profile) u1),
                    consensus-deviation-count: (if in-consensus
                        (get consensus-deviation-count user-profile)
                        (+ (get consensus-deviation-count user-profile) u1)
                    )
                })
            )
            
            ;; Update skill-specific reputation metrics
            (map-set skill-specific-evaluator-stats
                {evaluator: evaluator, skill-id: skill-id}
                {
                    domain-reputation: (if in-consensus
                        (+ (get domain-reputation skill-stats) reputation-reward-amount)
                        (if (> (get domain-reputation skill-stats) reputation-penalty-amount)
                            (- (get domain-reputation skill-stats) reputation-penalty-amount)
                            u0
                        )),
                    evaluations-in-domain: (+ (get evaluations-in-domain skill-stats) u1),
                    consensus-aligned-evaluations: (if in-consensus
                        (+ (get consensus-aligned-evaluations skill-stats) u1)
                        (get consensus-aligned-evaluations skill-stats)
                    )
                }
            )
        )
        true
    )
)

;; Generates unique identifier for new skill categories
(define-private (generate-skill-id)
    (let ((current-id (var-get skill-id-counter)))
        (var-set skill-id-counter (+ current-id u1))
        current-id
    )
)

;; Processes reputation updates for individual evaluator after assessment finalization
;; Determines if evaluator's score was within consensus tolerance range
(define-private (process-single-evaluator (evaluator principal) (score uint) (avg-score uint) (std-dev uint) (skill-id uint))
    (let (
        (score-deviation (if (> score avg-score)
            (- score avg-score)
            (- avg-score score)
        ))
    )
        (update-evaluator-reputation 
            evaluator 
            skill-id
            (< score-deviation consensus-variance-tolerance)
        )
    )
)

;; Registers a new user on the platform with initial empty profile
;; Users must register before participating as candidates or evaluators
(define-public (register-user)
    (let ((caller tx-sender))
        (asserts! (not (default-to false (get is-registered (map-get? user-profiles caller)))) ERR-USER-ALREADY-REGISTERED)
        (ok (map-set user-profiles 
            caller
            {
                is-registered: true,
                certified-skill-ids: (list ),
                overall-reputation: u0,
                total-evaluations-performed: u0,
                consensus-deviation-count: u0
            }
        ))
    )
)

;; Creates a new skill category available for certification
;; Only platform administrator can add new skill categories
(define-public (create-skill (skill-name (string-ascii 50)) (skill-desc (string-ascii 200)) (min-score uint) (skill-domain (string-ascii 50)))
    (let ((new-skill-id (generate-skill-id)))
        (asserts! (is-eq tx-sender contract-owner) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-valid-skill-name skill-name) ERR-INVALID-INPUT-PARAMETERS)
        (asserts! (is-valid-description-field skill-desc) ERR-INVALID-INPUT-PARAMETERS)
        (asserts! (is-valid-category-name skill-domain) ERR-INVALID-INPUT-PARAMETERS)
        (asserts! (<= min-score max-evaluators-per-assessment) ERR-INVALID-SCORE-VALUE)
        (asserts! (> min-score u0) ERR-INVALID-INPUT-PARAMETERS)
        
        (ok (map-set skill-categories 
            new-skill-id
            {
                name: skill-name,
                description: skill-desc,
                min-passing-score: min-score,
                domain: skill-domain
            }
        ))
    )
)

;; Initiates a new certification assessment for a specific skill
;; Creates assessment session that evaluators can submit scores to
(define-public (start-assessment (skill-id uint))
    (let ((caller tx-sender))
        (asserts! (does-skill-exist skill-id) ERR-SKILL-DOES-NOT-EXIST)
        (asserts! (default-to false (get is-registered (map-get? user-profiles caller))) ERR-USER-NOT-FOUND)
        (asserts! (is-none (map-get? active-assessments {skill-id: skill-id, candidate: caller})) ERR-ASSESSMENT-ALREADY-ACTIVE)
        
        (ok (map-set active-assessments
            {skill-id: skill-id, candidate: caller}
            {
                evaluators: (list ),
                scores: (list ),
                is-certified: false,
                created-at-block: block-height,
                average-score: u0,
                score-standard-deviation: u0
            }
        ))
    )
)

;; Submits an evaluation score for a candidate's skill assessment
;; Evaluators cannot assess themselves and scores must be 0-100
(define-public (submit-evaluation (skill-id uint) (candidate principal) (score uint))
    (let (
        (evaluator tx-sender)
        (assessment (unwrap! (map-get? active-assessments {skill-id: skill-id, candidate: candidate}) ERR-USER-NOT-FOUND))
        (current-evaluators (get evaluators assessment))
        (current-scores (get scores assessment))
        )
        (asserts! (does-skill-exist skill-id) ERR-SKILL-DOES-NOT-EXIST)
        (asserts! (default-to false (get is-registered (map-get? user-profiles evaluator))) ERR-USER-NOT-FOUND)
        (asserts! (not (is-eq evaluator candidate)) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (< score u101) ERR-INVALID-SCORE-VALUE)
        (asserts! (not (is-some (index-of current-evaluators evaluator))) ERR-ASSESSMENT-ALREADY-ACTIVE)
        (asserts! (< (len current-evaluators) max-evaluators-per-assessment) ERR-EVALUATOR-CAPACITY-EXCEEDED)
        
        (asserts! (< (len current-evaluators) u20) ERR-EVALUATOR-CAPACITY-EXCEEDED)
        (asserts! (< (len current-scores) u20) ERR-EVALUATOR-CAPACITY-EXCEEDED)
        
        (let (
            (updated-evaluators (unwrap! (as-max-len? (append current-evaluators evaluator) u20) ERR-EVALUATOR-CAPACITY-EXCEEDED))
            (updated-scores (unwrap! (as-max-len? (append current-scores score) u20) ERR-EVALUATOR-CAPACITY-EXCEEDED))
            (new-average (calculate-average updated-scores))
        )
            (ok (map-set active-assessments
                {skill-id: skill-id, candidate: candidate}
                (merge assessment {
                    evaluators: updated-evaluators,
                    scores: updated-scores,
                    average-score: new-average,
                    score-standard-deviation: (calculate-std-deviation updated-scores new-average)
                })
            ))
        )
    )
)

;; Finalizes assessment and determines certification status
;; Processes reputation updates for all evaluators based on consensus
(define-public (finalize-assessment (skill-id uint))
    (let (
        (candidate tx-sender)
        (assessment (unwrap! (map-get? active-assessments {skill-id: skill-id, candidate: candidate}) ERR-USER-NOT-FOUND))
        (all-scores (get scores assessment))
        (all-evaluators (get evaluators assessment))
        (avg-score (get average-score assessment))
        (std-dev (get score-standard-deviation assessment))
        (evaluator-count (len all-evaluators))
        )
        (asserts! (does-skill-exist skill-id) ERR-SKILL-DOES-NOT-EXIST)
        (asserts! (>= evaluator-count min-evaluators-required) ERR-INSUFFICIENT-EVALUATOR-COUNT)
        
        ;; Update reputation for all participating evaluators
        (map process-single-evaluator 
            all-evaluators 
            all-scores
            (list evaluator-count avg-score)
            (list evaluator-count std-dev)
            (list evaluator-count skill-id)
        )
        
        ;; Set final certification status based on average score
        (ok (map-set active-assessments
            {skill-id: skill-id, candidate: candidate}
            (merge assessment {
                is-certified: (>= avg-score passing-score-threshold)
            })
        ))
    )
)

;; Returns complete profile data for a registered user
(define-read-only (get-user-profile (user principal))
    (map-get? user-profiles user)
)

;; Returns detailed information about a skill category
(define-read-only (get-skill-info (skill-id uint))
    (map-get? skill-categories skill-id)
)

;; Returns current state of an assessment session
(define-read-only (get-assessment-details (skill-id uint) (candidate principal))
    (map-get? active-assessments {skill-id: skill-id, candidate: candidate})
)

;; Returns number of evaluators who have submitted scores for an assessment
(define-read-only (get-evaluator-count (skill-id uint) (candidate principal))
    (match (map-get? active-assessments {skill-id: skill-id, candidate: candidate})
        assessment (len (get evaluators assessment))
        u0
    )
)

;; Returns overall reputation score for a user across all domains
(define-read-only (get-user-reputation (user principal))
    (match (map-get? user-profiles user)
        profile (get overall-reputation profile)
        u0
    )
)

;; Returns domain-specific reputation for a user in a particular skill area
(define-read-only (get-skill-domain-reputation (user principal) (skill-id uint))
    (get domain-reputation (default-to 
        {domain-reputation: u0, evaluations-in-domain: u0, consensus-aligned-evaluations: u0}
        (map-get? skill-specific-evaluator-stats {evaluator: user, skill-id: skill-id})))
)

;; Returns comprehensive analytics for an assessment including statistical measures
(define-read-only (get-assessment-analytics (skill-id uint) (candidate principal))
    (map-get? active-assessments {skill-id: skill-id, candidate: candidate})
)