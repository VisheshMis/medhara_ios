# Phase 4: Multi-Platform Sync Server & Delta Protocol Specification

> **Parent Roadmap**: [ANDROID_APP_INTEGRATION_AND_SYNC.md](../../ANDROID_APP_INTEGRATION_AND_SYNC.md)  
> **Target Subsystem**: Central Sync Broker (Lightweight Node.js / Go microservice)  

---

## 🎯 Phase Objective
Define the bidirectional, cursor-based REST and WebSocket delta synchronization protocol between the Central Sync Service and all clients (Mac, Windows, Android). Implement a lightweight, self-hosted sync server providing fast endpoints for pushing client changes and pulling remote updates.

---

## 🌐 API Endpoints & Contracts

### 1. Push Client Mutations
- **Method**: `POST /api/v1/sync/push`
- **Request Headers**: `Authorization: Bearer <token>`, `X-Device-Id: <uuid>`
- **Request Body**:
```json
{
  "deviceId": "android-pixel-1234",
  "clientTimestamp": 1728551200000,
  "changes": [
    {
      "changeId": 101,
      "entityType": "flashcard",
      "entityId": "card-uuid-abc",
      "operation": "UPDATE",
      "payload": {
        "fsrsState": 2,
        "stability": 4.12,
        "difficulty": 5.2,
        "due": 1728810400000,
        "lastReview": 1728551200000,
        "reps": 3
      },
      "timestamp": 1728551200000
    }
  ]
}
```
- **Response**: `200 OK`
```json
{
  "success": true,
  "acceptedThroughChangeId": 101,
  "serverCursor": 4502
}
```

---

### 2. Pull Remote Mutations (Delta Fetch)
- **Method**: `GET /api/v1/sync/pull?sinceCursor=4490&limit=250`
- **Request Headers**: `Authorization: Bearer <token>`, `X-Device-Id: <uuid>`
- **Response**: `200 OK`
```json
{
  "serverCursor": 4502,
  "hasMore": false,
  "changes": [
    {
      "cursor": 4491,
      "entityType": "block",
      "entityId": "block-uuid-xyz",
      "operation": "INSERT",
      "payload": {
        "rootDocId": "doc-uuid-1",
        "parentId": null,
        "type": "heading1",
        "content": "Neuroanatomy Summary",
        "sortOrder": 0,
        "updatedAt": 1728550100000
      },
      "deviceId": "macbook-pro-5678",
      "timestamp": 1728550100000
    }
  ]
}
```

---

### 3. Real-Time WebSocket Notification
Clients maintain an active WebSocket connection at `ws://<server>/api/v1/sync/live`.
When any device pushes changes, the server broadcasts a lightweight notification:
```json
{
  "event": "NEW_COMMITS_AVAILABLE",
  "serverCursor": 4502,
  "originDeviceId": "macbook-pro-5678"
}
```
Android / Windows / Mac clients immediately trigger a pull if `originDeviceId != localDeviceId`.

---

## ⚖️ Conflict Resolution Rules (Server & Client)
1. **Flashcard Reviews**: Reviews are append-only into `review_log`. When merging flashcard records, the state with the newer `lastReview` timestamp wins.
2. **Block Edits (Notes)**: Last-Write-Wins (LWW) based on `updatedAt`. If identical down to the millisecond, higher lexical `deviceId` breaks ties.
3. **Documents/Notebooks**: Soft-deletion (`isArchived = 1`) takes precedence over rename.

---

## 🧪 Verification Gate
- Automated tests spin up the sync server, register 2 simulated clients (Desktop and Android), push mutations from Client A, and assert that Client B pulls them accurately with advancing cursors.
