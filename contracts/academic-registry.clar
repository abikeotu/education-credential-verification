;; Academic Registry - Student Records and Transcript Management System
;; This contract manages academic transcripts, grade records, and institutional verification

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-STUDENT-NOT-FOUND (err u201))
(define-constant ERR-TRANSCRIPT-NOT-FOUND (err u202))
(define-constant ERR-COURSE-NOT-FOUND (err u203))
(define-constant ERR-INVALID-GRADE (err u204))
(define-constant ERR-DUPLICATE-ENROLLMENT (err u205))
(define-constant ERR-SEMESTER-CLOSED (err u206))
(define-constant ERR-INSUFFICIENT-PERMISSIONS (err u207))

;; Grade Scale Constants
(define-constant GRADE-A u95)
(define-constant GRADE-B u85)
(define-constant GRADE-C u75)
(define-constant GRADE-D u65)
(define-constant GRADE-F u0)

;; Academic Status
(define-constant STATUS-ENROLLED u1)
(define-constant STATUS-GRADUATED u2)
(define-constant STATUS-SUSPENDED u3)
(define-constant STATUS-WITHDRAWN u4)
(define-constant STATUS-TRANSFER u5)

;; Data Variables
(define-data-var student-counter uint u0)
(define-data-var course-counter uint u0)
(define-data-var transcript-counter uint u0)
(define-data-var semester-counter uint u0)

;; Student Records
(define-map students
  { student-id: uint }
  {
    student-address: principal,
    student-name: (string-ascii 100),
    student-email: (string-ascii 100),
    enrollment-date: uint,
    expected-graduation: uint,
    major: (string-ascii 100),
    minor: (string-ascii 100),
    academic-status: uint,
    current-gpa: uint, ;; Stored as percentage (e.g., 85 = 3.4 GPA)
    total-credits-earned: uint,
    total-credits-attempted: uint,
    graduation-date: uint,
    honors: (string-ascii 50)
  }
)

;; Course Catalog
(define-map courses
  { course-id: uint }
  {
    course-code: (string-ascii 20),
    course-title: (string-ascii 200),
    credit-hours: uint,
    department: (string-ascii 100),
    course-level: uint, ;; 100-400 for undergraduate, 500+ for graduate
    prerequisites: (list 10 uint),
    description: (string-ascii 500),
    instructor: principal,
    is-active: bool
  }
)

;; Academic Semesters
(define-map semesters
  { semester-id: uint }
  {
    semester-name: (string-ascii 50),
    start-date: uint,
    end-date: uint,
    registration-deadline: uint,
    is-current: bool,
    is-closed: bool
  }
)

;; Student Enrollments
(define-map enrollments
  { student-id: uint, course-id: uint, semester-id: uint }
  {
    enrollment-date: uint,
    final-grade: uint,
    grade-points: uint,
    attendance-percentage: uint,
    is-completed: bool,
    withdrawal-date: uint,
    withdrawal-reason: (string-ascii 200)
  }
)

;; Academic Transcripts
(define-map transcripts
  { transcript-id: uint }
  {
    student-id: uint,
    issue-date: uint,
    semester-records: (list 50 uint), ;; List of semester IDs
    cumulative-gpa: uint,
    total-credits: uint,
    class-rank: uint,
    honors-received: (string-ascii 200),
    transcript-hash: (string-ascii 64),
    is-official: bool,
    recipient: (string-ascii 200)
  }
)

;; Grade History
(define-map grade-history
  { student-id: uint, semester-id: uint }
  {
    courses-taken: uint,
    semester-gpa: uint,
    credits-earned: uint,
    credits-attempted: uint,
    academic-standing: (string-ascii 50),
    dean-list: bool,
    probation: bool
  }
)

;; Degree Requirements
(define-map degree-requirements
  { program-id: uint }
  {
    program-name: (string-ascii 200),
    required-credits: uint,
    core-courses: (list 20 uint),
    elective-credits: uint,
    minimum-gpa: uint,
    residency-requirement: uint,
    capstone-required: bool,
    internship-required: bool
  }
)

;; Academic Achievements
(define-map achievements
  { student-id: uint, achievement-id: uint }
  {
    achievement-type: (string-ascii 100),
    award-name: (string-ascii 200),
    award-date: uint,
    issuing-body: (string-ascii 200),
    verification-status: bool,
    description: (string-ascii 300)
  }
)

;; Public Functions

;; Register a new student
(define-public (register-student
  (student-address principal)
  (student-name (string-ascii 100))
  (student-email (string-ascii 100))
  (major (string-ascii 100))
  (expected-graduation uint))
  (let
    (
      (student-id (+ (var-get student-counter) u1))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (map-set students
      { student-id: student-id }
      {
        student-address: student-address,
        student-name: student-name,
        student-email: student-email,
        enrollment-date: stacks-block-height,
        expected-graduation: expected-graduation,
        major: major,
        minor: "",
        academic-status: STATUS-ENROLLED,
        current-gpa: u0,
        total-credits-earned: u0,
        total-credits-attempted: u0,
        graduation-date: u0,
        honors: ""
      }
    )
    
    (var-set student-counter student-id)
    
    (ok student-id)
  )
)

;; Add a new course to catalog
(define-public (add-course
  (course-code (string-ascii 20))
  (course-title (string-ascii 200))
  (credit-hours uint)
  (department (string-ascii 100))
  (course-level uint)
  (prerequisites (list 10 uint))
  (description (string-ascii 500)))
  (let
    (
      (course-id (+ (var-get course-counter) u1))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= credit-hours u1) (<= credit-hours u6)) ERR-INVALID-GRADE)
    
    (map-set courses
      { course-id: course-id }
      {
        course-code: course-code,
        course-title: course-title,
        credit-hours: credit-hours,
        department: department,
        course-level: course-level,
        prerequisites: prerequisites,
        description: description,
        instructor: tx-sender,
        is-active: true
      }
    )
    
    (var-set course-counter course-id)
    
    (ok course-id)
  )
)

;; Create academic semester
(define-public (create-semester
  (semester-name (string-ascii 50))
  (duration-blocks uint)
  (registration-period uint))
  (let
    (
      (semester-id (+ (var-get semester-counter) u1))
      (start-date stacks-block-height)
      (end-date (+ stacks-block-height duration-blocks))
      (registration-deadline (+ stacks-block-height registration-period))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (map-set semesters
      { semester-id: semester-id }
      {
        semester-name: semester-name,
        start-date: start-date,
        end-date: end-date,
        registration-deadline: registration-deadline,
        is-current: true,
        is-closed: false
      }
    )
    
    (var-set semester-counter semester-id)
    
    (ok semester-id)
  )
)

;; Enroll student in course
(define-public (enroll-student
  (student-id uint)
  (course-id uint)
  (semester-id uint))
  (let
    (
      (student (unwrap! (map-get? students { student-id: student-id }) ERR-STUDENT-NOT-FOUND))
      (course (unwrap! (map-get? courses { course-id: course-id }) ERR-COURSE-NOT-FOUND))
      (semester (unwrap! (map-get? semesters { semester-id: semester-id }) ERR-SEMESTER-CLOSED))
    )
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-eq tx-sender (get student-address student))) ERR-NOT-AUTHORIZED)
    (asserts! (not (get is-closed semester)) ERR-SEMESTER-CLOSED)
    (asserts! (<= stacks-block-height (get registration-deadline semester)) ERR-SEMESTER-CLOSED)
    (asserts! (get is-active course) ERR-COURSE-NOT-FOUND)
    
    ;; Check if already enrolled
    (asserts! (is-none (map-get? enrollments { student-id: student-id, course-id: course-id, semester-id: semester-id })) ERR-DUPLICATE-ENROLLMENT)
    
    (map-set enrollments
      { student-id: student-id, course-id: course-id, semester-id: semester-id }
      {
        enrollment-date: stacks-block-height,
        final-grade: u0,
        grade-points: u0,
        attendance-percentage: u0,
        is-completed: false,
        withdrawal-date: u0,
        withdrawal-reason: ""
      }
    )
    
    (ok true)
  )
)

;; Submit final grade for student
(define-public (submit-grade
  (student-id uint)
  (course-id uint)
  (semester-id uint)
  (final-grade uint)
  (attendance-percentage uint))
  (let
    (
      (enrollment (unwrap! (map-get? enrollments { student-id: student-id, course-id: course-id, semester-id: semester-id }) ERR-STUDENT-NOT-FOUND))
      (course (unwrap! (map-get? courses { course-id: course-id }) ERR-COURSE-NOT-FOUND))
      (credit-hours (get credit-hours course))
      (grade-points (* final-grade credit-hours))
    )
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-eq tx-sender (get instructor course))) ERR-NOT-AUTHORIZED)
    (asserts! (<= final-grade u100) ERR-INVALID-GRADE)
    
    (map-set enrollments
      { student-id: student-id, course-id: course-id, semester-id: semester-id }
      (merge enrollment {
        final-grade: final-grade,
        grade-points: grade-points,
        attendance-percentage: attendance-percentage,
        is-completed: true
      })
    )
    
    ;; Update student GPA and credits
    (update-student-gpa student-id)
    
    (ok true)
  )
)

;; Generate official transcript
(define-public (generate-transcript
  (student-id uint)
  (recipient (string-ascii 200)))
  (let
    (
      (student (unwrap! (map-get? students { student-id: student-id }) ERR-STUDENT-NOT-FOUND))
      (transcript-id (+ (var-get transcript-counter) u1))
      (transcript-hash (generate-transcript-hash student-id))
    )
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-eq tx-sender (get student-address student))) ERR-NOT-AUTHORIZED)
    
    (map-set transcripts
      { transcript-id: transcript-id }
      {
        student-id: student-id,
        issue-date: stacks-block-height,
        semester-records: (list),
        cumulative-gpa: (get current-gpa student),
        total-credits: (get total-credits-earned student),
        class-rank: u0, ;; Would be calculated based on cohort
        honors-received: (get honors student),
        transcript-hash: transcript-hash,
        is-official: true,
        recipient: recipient
      }
    )
    
    (var-set transcript-counter transcript-id)
    
    (ok transcript-id)
  )
)

;; Award academic achievement
(define-public (award-achievement
  (student-id uint)
  (achievement-type (string-ascii 100))
  (award-name (string-ascii 200))
  (issuing-body (string-ascii 200))
  (description (string-ascii 300)))
  (let
    (
      (student (unwrap! (map-get? students { student-id: student-id }) ERR-STUDENT-NOT-FOUND))
      (achievement-id (+ student-id u1000000)) ;; Simple ID generation
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (map-set achievements
      { student-id: student-id, achievement-id: achievement-id }
      {
        achievement-type: achievement-type,
        award-name: award-name,
        award-date: stacks-block-height,
        issuing-body: issuing-body,
        verification-status: true,
        description: description
      }
    )
    
    (ok achievement-id)
  )
)

;; Graduate student
(define-public (graduate-student (student-id uint) (honors (string-ascii 50)))
  (let
    (
      (student (unwrap! (map-get? students { student-id: student-id }) ERR-STUDENT-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get academic-status student) STATUS-ENROLLED) ERR-NOT-AUTHORIZED)
    
    (map-set students
      { student-id: student-id }
      (merge student {
        academic-status: STATUS-GRADUATED,
        graduation-date: stacks-block-height,
        honors: honors
      })
    )
    
    (ok true)
  )
)

;; Private helper functions

;; Update student GPA (simplified calculation)
(define-private (update-student-gpa (student-id uint))
  (match (map-get? students { student-id: student-id })
    student
    (begin
      ;; Simplified GPA calculation - in production, would iterate through all grades
      (map-set students
        { student-id: student-id }
        (merge student {
          total-credits-attempted: (+ (get total-credits-attempted student) u3),
          total-credits-earned: (+ (get total-credits-earned student) u3),
          current-gpa: u85 ;; Placeholder calculation
        })
      )
      true
    )
    false
  )
)

;; Generate transcript hash (simplified)
(define-private (generate-transcript-hash (student-id uint))
  ;; In production, would hash all transcript data
  "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
)

;; Read-only Functions

;; Get student details
(define-read-only (get-student (student-id uint))
  (map-get? students { student-id: student-id })
)

;; Get course details
(define-read-only (get-course (course-id uint))
  (map-get? courses { course-id: course-id })
)

;; Get semester details
(define-read-only (get-semester (semester-id uint))
  (map-get? semesters { semester-id: semester-id })
)

;; Get enrollment details
(define-read-only (get-enrollment (student-id uint) (course-id uint) (semester-id uint))
  (map-get? enrollments { student-id: student-id, course-id: course-id, semester-id: semester-id })
)

;; Get transcript details
(define-read-only (get-transcript (transcript-id uint))
  (map-get? transcripts { transcript-id: transcript-id })
)

;; Get grade history
(define-read-only (get-grade-history (student-id uint) (semester-id uint))
  (map-get? grade-history { student-id: student-id, semester-id: semester-id })
)

;; Get achievement details
(define-read-only (get-achievement (student-id uint) (achievement-id uint))
  (map-get? achievements { student-id: student-id, achievement-id: achievement-id })
)

;; Get degree requirements
(define-read-only (get-degree-requirements (program-id uint))
  (map-get? degree-requirements { program-id: program-id })
)

;; Get platform statistics
(define-read-only (get-platform-stats)
  {
    total-students: (var-get student-counter),
    total-courses: (var-get course-counter),
    total-transcripts: (var-get transcript-counter),
    total-semesters: (var-get semester-counter)
  }
)

;; Check student graduation eligibility
(define-read-only (check-graduation-eligibility (student-id uint))
  (match (map-get? students { student-id: student-id })
    student
    (and
      (is-eq (get academic-status student) STATUS-ENROLLED)
      (>= (get total-credits-earned student) u120) ;; Minimum credits
      (>= (get current-gpa student) u70) ;; Minimum GPA
    )
    false
  )
)

;; Verify transcript authenticity
(define-read-only (verify-transcript (transcript-id uint) (expected-hash (string-ascii 64)))
  (match (map-get? transcripts { transcript-id: transcript-id })
    transcript
    (is-eq (get transcript-hash transcript) expected-hash)
    false
  )
)

;; title: academic-registry
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

