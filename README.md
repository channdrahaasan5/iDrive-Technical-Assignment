# iDriver Ride State Engine

Technical Assignment -- iOS (Swift) + Node.js Backend

------------------------------------------------------------------------

# Overview

iDriver implements a driver-side ride lifecycle system with strict
server-enforced state transitions, atomic concurrency protection, and
reliable offline location handling.

The system demonstrates:

-   Server-authoritative state machine
-   Atomic accept protection (409 Conflict handling)
-   Native iOS SwiftUI application (MVVM)
-   Periodic location updates (every 5 seconds)
-   Persistent offline queue (Core Data)
-   Clear error handling (401, 409, 5xx)
-   Explicit tradeoff and production awareness

------------------------------------------------------------------------

# 1. Setup Instructions

## Backend (Node.js)

1.  Navigate to APIs folder: cd APIs

2.  Install dependencies: npm install

3.  (Optional) Seed sample rides: npm run seed

4.  Start the server: npm start

### Server Defaults

-   Port: 3000
-   Health Endpoint: GET /health
-   Persistence: lowdb JSON (BackEnd/db.json)
-   Runtime store: In-memory Map + file persistence
-   If you are running the iOS app on a physical device, ensure both:
        Your Mac and iPhone are connected to the same Wi-Fi network.
        The backend server is bound to `0.0.0.0`.
        Set the API base URL to: http://`<HOST_IP>`:3000
        For detailed steps, refer to: `Documents/WIFI_SETUP.md`

------------------------------------------------------------------------

## iOS Application

1.  Open: MobileApp/iOS/iDrive/iDrive.xcodeproj

2.  Configure Signing & Capabilities.

3.  Set backend base URL if needed:
    APIClient.shared.setBaseURL("http://`<HOST_IP>`:3000")

4.  Build & run.

5.  Grant location permissions.

------------------------------------------------------------------------

# 2. Architecture Explanation

## High-Level Structure

iOS App - SwiftUI Views - ViewModels (MVVM) - RideStateMachine -
APIClient - LocationSendService - LocationQueueManager (CoreData)

        ↓ HTTPS

Node.js Backend - Express Routes - StateMachine Validator - rideStore
(Atomic Map) - lowdb JSON Persistence

------------------------------------------------------------------------

## Mobile Architecture (MVVM)

-   Views → UI rendering
-   ViewModels → Business logic & orchestration
-   RideStateMachine → Client-side validation
-   APIClient → Networking layer
-   LocationSendService → 5-second periodic sender
-   LocationQueueManager → Persistent FIFO offline queue
-   Core Data → Durable local storage

Client performs early validation for UX. Server remains authoritative.

------------------------------------------------------------------------

## Backend Architecture

Components:

-   server.js → Express routes
-   stateMachine.js → Transition validation
-   rideStore.js → Atomic runtime store
-   persistence.js → JSON persistence
-   auth.js → Mock token auth

### Concurrency Protection

Atomic update pattern:

updateAtomic(id, updater)

If two drivers accept the same ride: - First succeeds - Second receives
HTTP 409 Conflict

This prevents double assignment.

------------------------------------------------------------------------

# 3. Ride Lifecycle

Authoritative transitions:

REQUESTED → ACCEPTED → STARTED → COMPLETED

Cancellation: - Allowed only before STARTED - ACCEPTED → REQUESTED
(driverId cleared)

Invalid transitions return 409 Conflict.

Server is source of truth.

------------------------------------------------------------------------

# 4. Location Updates & Offline Handling

## Online Flow

When ride = STARTED: - Location generated every 5 seconds - Immediate
POST attempt - On success → UI updated

------------------------------------------------------------------------

## Offline Queue Design

Location is persisted when: - Online toggle is OFF - Network timeout
occurs - 5xx server error occurs

Each record stores: - rideId - lat / lng - ts - attempts - lastError -
sent flag

Queue survives app restarts.

------------------------------------------------------------------------

## Retry Policy

Retryable: - Network errors - Timeouts - 5xx responses

Behavior: - attempts incremented - lastError stored - Exponential
backoff applied

Backoff formula: Delay = min(2\^attempts, 30 seconds)

Unlimited retry used for assignment scope.

------------------------------------------------------------------------

## Failure Handling

401 → Token cleared + logout\
409 → User-facing conflict message\
5xx → Treated as transient (retry)

------------------------------------------------------------------------

# 5. Assumptions & Tradeoffs

## Assumptions

-   Driver-side implementation only
-   No real-time push required
-   Background tracking not mandatory
-   JSON persistence sufficient for scope

------------------------------------------------------------------------

## Key Tradeoffs

### In-Memory Backend

Benefit: - Deterministic atomic updates - Simplicity

Tradeoff: - Single-process only - Not horizontally scalable

------------------------------------------------------------------------

### lowdb Persistence

Benefit: - Easy to run & inspect

Tradeoff: - No ACID guarantees - Not production-grade

------------------------------------------------------------------------

### Unlimited Retry

Benefit: - Prevents data loss

Tradeoff: - Could retry indefinitely under long outages

------------------------------------------------------------------------

# 6. Production Improvement Notes

Backend: - Replace lowdb with PostgreSQL - Use transactional state
transitions - Add unique DB constraints - Add structured logging &
metrics

Idempotency: - Add per-location UUID - Server-side deduplication

Retry Policy: - Exponential backoff with jitter - Max attempt
threshold - Dead-letter queue

Security: - Replace fake token with JWT - Enforce HTTPS - Token refresh
flow

iOS Enhancements: - Background location support (if required) - Network
reachability auto-trigger

------------------------------------------------------------------------

# Conclusion

This solution focuses on:

-   Strict lifecycle enforcement
-   Atomic concurrency handling
-   Offline-first reliability
-   Controlled retry behavior
-   Clean architectural separation

The implementation balances correctness, clarity, and production
awareness within the scope of the assignment.
