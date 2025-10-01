;; Credential Vault - Tamper-proof Academic and Professional Credential System
;; This contract manages digital certificates, instant verification, and accreditation authorities

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-CREDENTIAL-NOT-FOUND (err u101))
(define-constant ERR-INSTITUTION-NOT-AUTHORIZED (err u102))
(define-constant ERR-CREDENTIAL-REVOKED (err u103))
(define-constant ERR-INVALID-CREDENTIAL-TYPE (err u104))
(define-constant ERR-ALREADY-VERIFIED (err u105))
(define-constant ERR-VERIFICATION-FAILED (err u106))
(define-constant ERR-ACCREDITOR-NOT-FOUND (err u107))

;; Credential Types
(define-constant ACADEMIC-DEGREE u1)
(define-constant PROFESSIONAL-CERTIFICATION u2)
(define-constant CONTINUING-EDUCATION u3)
(define-constant SKILL-CERTIFICATION u4)
(define-constant MICRO-CREDENTIAL u5)
(define-constant RESEARCH-PUBLICATION u6)

;; Verification Levels
(define-constant BASIC-VERIFICATION u1)
(define-constant STANDARD-VERIFICATION u2)
(define-constant PREMIUM-VERIFICATION u3)
(define-constant ENTERPRISE-VERIFICATION u4)

;; Data Variables
(define-data-var credential-counter uint u0)
(define-data-var institution-counter uint u0)
(define-data-var verification-counter uint u0)
(define-data-var accreditor-counter uint u0)

;; Digital Credentials
(define-map credentials
  { credential-id: uint }
  {
    holder: principal,
    issuing-institution: uint,
    credential-type: uint,
    title: (string-ascii 200),
    description: (string-ascii 500),
    issue-date: uint,
    expiry-date: uint,
    credential-hash: (string-ascii 64), ;; SHA-256 hash of credential data
    verification-level: uint,
    is-revoked: bool,
    revocation-date: uint,
    revocation-reason: (string-ascii 200),
    metadata: (string-ascii 300) ;; Additional credential metadata
  }
)

;; Authorized Educational Institutions
(define-map institutions
  { institution-id: uint }
  {
    name: (string-ascii 200),
    authorized-representative: principal,
    accreditor-id: uint,
    institution-type: (string-ascii 50),
    location: (string-ascii 100),
    accreditation-date: uint,
    is-authorized: bool,
    credentials-issued: uint,
    reputation-score: uint, ;; Out of 100
    contact-info: (string-ascii 200)
  }
)

;; Accreditation Bodies
(define-map accreditors
  { accreditor-id: uint }
  {
    name: (string-ascii 200),
    representative: principal,
    jurisdiction: (string-ascii 100),
    accreditation-standards: (string-ascii 300),
    recognition-date: uint,
    is-active: bool,
    institutions-accredited: uint,
    website: (string-ascii 100)
  }
)

;; Credential Verifications
(define-map verifications
  { verification-id: uint }
  {
    credential-id: uint,
    verifier: principal,
    verification-date: uint,
    verification-type: uint,
    result: bool,
    additional-notes: (string-ascii 300),
    employer-organization: (string-ascii 200)
  }
)

;; Continuing Education Requirements
(define-map ce-requirements
  { credential-id: uint }
  {
    required-hours: uint,
    completed-hours: uint,
    deadline: uint,
    is-compliant: bool,
    last-updated: uint,
    tracking-period: uint ;; In blocks (e.g., annually)
  }
)

;; Credential Sharing Permissions
(define-map sharing-permissions
  { holder: principal, verifier: principal, credential-id: uint }
  {
    permission-granted: bool,
    grant-date: uint,
    expiry-date: uint,
    access-level: uint, ;; 1=basic info, 2=detailed, 3=full access
    usage-count: uint
  }
)

;; Institution Performance Metrics
(define-map institution-metrics
  { institution-id: uint }
  {
    total-issued: uint,
    verified-successfully: uint,
    revoked-credentials: uint,
    average-verification-time: uint,
    last-audit-date: uint,
    compliance-score: uint
  }
)

;; Public Functions

;; Register an accreditation body
(define-public (register-accreditor
  (name (string-ascii 200))
  (jurisdiction (string-ascii 100))
  (accreditation-standards (string-ascii 300))
  (website (string-ascii 100)))
  (let
    (
      (accreditor-id (+ (var-get accreditor-counter) u1))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (map-set accreditors
      { accreditor-id: accreditor-id }
      {
        name: name,
        representative: tx-sender,
        jurisdiction: jurisdiction,
        accreditation-standards: accreditation-standards,
        recognition-date: stacks-block-height,
        is-active: true,
        institutions-accredited: u0,
        website: website
      }
    )
    
    (var-set accreditor-counter accreditor-id)
    
    (ok accreditor-id)
  )
)

;; Register an educational institution
(define-public (register-institution
  (name (string-ascii 200))
  (accreditor-id uint)
  (institution-type (string-ascii 50))
  (location (string-ascii 100))
  (contact-info (string-ascii 200)))
  (let
    (
      (institution-id (+ (var-get institution-counter) u1))
      (accreditor (unwrap! (map-get? accreditors { accreditor-id: accreditor-id }) ERR-ACCREDITOR-NOT-FOUND))
    )
    (asserts! (get is-active accreditor) ERR-ACCREDITOR-NOT-FOUND)
    
    (map-set institutions
      { institution-id: institution-id }
      {
        name: name,
        authorized-representative: tx-sender,
        accreditor-id: accreditor-id,
        institution-type: institution-type,
        location: location,
        accreditation-date: stacks-block-height,
        is-authorized: false, ;; Requires accreditor approval
        credentials-issued: u0,
        reputation-score: u75, ;; Start with good score
        contact-info: contact-info
      }
    )
    
    ;; Initialize performance metrics
    (map-set institution-metrics
      { institution-id: institution-id }
      {
        total-issued: u0,
        verified-successfully: u0,
        revoked-credentials: u0,
        average-verification-time: u0,
        last-audit-date: stacks-block-height,
        compliance-score: u100
      }
    )
    
    (var-set institution-counter institution-id)
    
    (ok institution-id)
  )
)

;; Authorize an institution (accreditor only)
(define-public (authorize-institution (institution-id uint))
  (let
    (
      (institution (unwrap! (map-get? institutions { institution-id: institution-id }) ERR-INSTITUTION-NOT-AUTHORIZED))
      (accreditor-id (get accreditor-id institution))
      (accreditor (unwrap! (map-get? accreditors { accreditor-id: accreditor-id }) ERR-ACCREDITOR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get representative accreditor)) ERR-NOT-AUTHORIZED)
    
    (map-set institutions
      { institution-id: institution-id }
      (merge institution { is-authorized: true })
    )
    
    ;; Update accreditor stats
    (map-set accreditors
      { accreditor-id: accreditor-id }
      (merge accreditor { institutions-accredited: (+ (get institutions-accredited accreditor) u1) })
    )
    
    (ok true)
  )
)

;; Issue a digital credential
(define-public (issue-credential
  (holder principal)
  (credential-type uint)
  (title (string-ascii 200))
  (description (string-ascii 500))
  (duration-blocks uint)
  (credential-hash (string-ascii 64))
  (verification-level uint)
  (metadata (string-ascii 300)))
  (let
    (
      (credential-id (+ (var-get credential-counter) u1))
      (institution-id (get-institution-by-representative tx-sender))
      (institution (unwrap! (map-get? institutions { institution-id: institution-id }) ERR-INSTITUTION-NOT-AUTHORIZED))
      (expiry-date (if (> duration-blocks u0) (+ stacks-block-height duration-blocks) u0))
    )
    (asserts! (get is-authorized institution) ERR-INSTITUTION-NOT-AUTHORIZED)
    (asserts! (and (>= credential-type u1) (<= credential-type u6)) ERR-INVALID-CREDENTIAL-TYPE)
    (asserts! (and (>= verification-level u1) (<= verification-level u4)) ERR-INVALID-CREDENTIAL-TYPE)
    
    ;; Create the credential
    (map-set credentials
      { credential-id: credential-id }
      {
        holder: holder,
        issuing-institution: institution-id,
        credential-type: credential-type,
        title: title,
        description: description,
        issue-date: stacks-block-height,
        expiry-date: expiry-date,
        credential-hash: credential-hash,
        verification-level: verification-level,
        is-revoked: false,
        revocation-date: u0,
        revocation-reason: "",
        metadata: metadata
      }
    )
    
    ;; Set up continuing education requirements if applicable
    (if (or (is-eq credential-type PROFESSIONAL-CERTIFICATION) (is-eq credential-type SKILL-CERTIFICATION))
      (map-set ce-requirements
        { credential-id: credential-id }
        {
          required-hours: u40, ;; Default 40 hours annually
          completed-hours: u0,
          deadline: (+ stacks-block-height u52560), ;; Approximately 1 year
          is-compliant: true,
          last-updated: stacks-block-height,
          tracking-period: u52560
        }
      )
      true
    )
    
    ;; Update institution stats
    (map-set institutions
      { institution-id: institution-id }
      (merge institution { credentials-issued: (+ (get credentials-issued institution) u1) })
    )
    
    ;; Update metrics
    (let ((metrics (unwrap! (map-get? institution-metrics { institution-id: institution-id }) ERR-INSTITUTION-NOT-AUTHORIZED)))
      (map-set institution-metrics
        { institution-id: institution-id }
        (merge metrics { total-issued: (+ (get total-issued metrics) u1) })
      )
    )
    
    (var-set credential-counter credential-id)
    
    (ok credential-id)
  )
)

;; Verify a credential
(define-public (verify-credential
  (credential-id uint)
  (verification-type uint)
  (employer-organization (string-ascii 200)))
  (let
    (
      (credential (unwrap! (map-get? credentials { credential-id: credential-id }) ERR-CREDENTIAL-NOT-FOUND))
      (verification-id (+ (var-get verification-counter) u1))
      (is-valid (and
        (not (get is-revoked credential))
        (or (is-eq (get expiry-date credential) u0) (<= stacks-block-height (get expiry-date credential)))
      ))
    )
    
    ;; Record verification attempt
    (map-set verifications
      { verification-id: verification-id }
      {
        credential-id: credential-id,
        verifier: tx-sender,
        verification-date: stacks-block-height,
        verification-type: verification-type,
        result: is-valid,
        additional-notes: "",
        employer-organization: employer-organization
      }
    )
    
    ;; Update institution metrics
    (let
      (
        (institution-id (get issuing-institution credential))
        (metrics (unwrap! (map-get? institution-metrics { institution-id: institution-id }) ERR-INSTITUTION-NOT-AUTHORIZED))
      )
      (if is-valid
        (map-set institution-metrics
          { institution-id: institution-id }
          (merge metrics { verified-successfully: (+ (get verified-successfully metrics) u1) })
        )
        true
      )
    )
    
    (var-set verification-counter verification-id)
    
    (ok { verification-id: verification-id, is-valid: is-valid })
  )
)

;; Revoke a credential (institution only)
(define-public (revoke-credential
  (credential-id uint)
  (reason (string-ascii 200)))
  (let
    (
      (credential (unwrap! (map-get? credentials { credential-id: credential-id }) ERR-CREDENTIAL-NOT-FOUND))
      (institution-id (get-institution-by-representative tx-sender))
    )
    (asserts! (is-eq (get issuing-institution credential) institution-id) ERR-NOT-AUTHORIZED)
    (asserts! (not (get is-revoked credential)) ERR-CREDENTIAL-REVOKED)
    
    (map-set credentials
      { credential-id: credential-id }
      (merge credential {
        is-revoked: true,
        revocation-date: stacks-block-height,
        revocation-reason: reason
      })
    )
    
    ;; Update metrics
    (let ((metrics (unwrap! (map-get? institution-metrics { institution-id: institution-id }) ERR-INSTITUTION-NOT-AUTHORIZED)))
      (map-set institution-metrics
        { institution-id: institution-id }
        (merge metrics { revoked-credentials: (+ (get revoked-credentials metrics) u1) })
      )
    )
    
    (ok true)
  )
)

;; Grant sharing permission
(define-public (grant-sharing-permission
  (verifier principal)
  (credential-id uint)
  (duration-blocks uint)
  (access-level uint))
  (let
    (
      (credential (unwrap! (map-get? credentials { credential-id: credential-id }) ERR-CREDENTIAL-NOT-FOUND))
      (expiry-date (+ stacks-block-height duration-blocks))
    )
    (asserts! (is-eq tx-sender (get holder credential)) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= access-level u1) (<= access-level u3)) ERR-INVALID-CREDENTIAL-TYPE)
    
    (map-set sharing-permissions
      { holder: tx-sender, verifier: verifier, credential-id: credential-id }
      {
        permission-granted: true,
        grant-date: stacks-block-height,
        expiry-date: expiry-date,
        access-level: access-level,
        usage-count: u0
      }
    )
    
    (ok true)
  )
)

;; Update continuing education progress
(define-public (update-ce-progress
  (credential-id uint)
  (additional-hours uint))
  (let
    (
      (credential (unwrap! (map-get? credentials { credential-id: credential-id }) ERR-CREDENTIAL-NOT-FOUND))
      (ce-req (unwrap! (map-get? ce-requirements { credential-id: credential-id }) ERR-CREDENTIAL-NOT-FOUND))
      (new-completed (+ (get completed-hours ce-req) additional-hours))
    )
    (asserts! (is-eq tx-sender (get holder credential)) ERR-NOT-AUTHORIZED)
    
    (map-set ce-requirements
      { credential-id: credential-id }
      (merge ce-req {
        completed-hours: new-completed,
        is-compliant: (>= new-completed (get required-hours ce-req)),
        last-updated: stacks-block-height
      })
    )
    
    (ok new-completed)
  )
)

;; Private helper function to get institution by representative
(define-private (get-institution-by-representative (representative principal))
  ;; This is a simplified implementation - in production, you'd maintain a reverse lookup
  u1 ;; Placeholder - would need proper implementation
)

;; Read-only Functions

;; Get credential details
(define-read-only (get-credential (credential-id uint))
  (map-get? credentials { credential-id: credential-id })
)

;; Get institution details
(define-read-only (get-institution (institution-id uint))
  (map-get? institutions { institution-id: institution-id })
)

;; Get accreditor details
(define-read-only (get-accreditor (accreditor-id uint))
  (map-get? accreditors { accreditor-id: accreditor-id })
)

;; Get verification details
(define-read-only (get-verification (verification-id uint))
  (map-get? verifications { verification-id: verification-id })
)

;; Get continuing education requirements
(define-read-only (get-ce-requirements (credential-id uint))
  (map-get? ce-requirements { credential-id: credential-id })
)

;; Get sharing permissions
(define-read-only (get-sharing-permission (holder principal) (verifier principal) (credential-id uint))
  (map-get? sharing-permissions { holder: holder, verifier: verifier, credential-id: credential-id })
)

;; Get institution metrics
(define-read-only (get-institution-metrics (institution-id uint))
  (map-get? institution-metrics { institution-id: institution-id })
)

;; Check credential validity
(define-read-only (is-credential-valid (credential-id uint))
  (match (map-get? credentials { credential-id: credential-id })
    credential
    (and
      (not (get is-revoked credential))
      (or (is-eq (get expiry-date credential) u0) (<= stacks-block-height (get expiry-date credential)))
    )
    false
  )
)

;; Get platform statistics
(define-read-only (get-platform-stats)
  {
    total-credentials: (var-get credential-counter),
    total-institutions: (var-get institution-counter),
    total-verifications: (var-get verification-counter),
    total-accreditors: (var-get accreditor-counter)
  }
)

;; Get current counters
(define-read-only (get-credential-counter)
  (var-get credential-counter)
)

(define-read-only (get-institution-counter)
  (var-get institution-counter)
)

(define-read-only (get-verification-counter)
  (var-get verification-counter)
)

(define-read-only (get-accreditor-counter)
  (var-get accreditor-counter)
)

;; title: credential-vault
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

