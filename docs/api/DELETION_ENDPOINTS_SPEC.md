# YADVI Backend — Field Executive & Shop Owner Deletion API Specification

**Service URL:** `https://yadvi-day1-test-f5upp75xna-el.a.run.app`  
**API Version:** `v1`  
**Authorization Scheme:** `Bearer <JWT>` (OAuth2 Password Bearer)  
**Required Role:** `administrator` (enforced via `require_role(["administrator"])`)  

---

## 1. Delete Shop Owner

### Endpoint
`DELETE /api/v1/shops/{shop_id}`

### Description
Permanently deletes a Shop Owner profile and their associated `User` record and FCM push notification tokens.

### Business Safety Constraints
Deletion is **refused** (HTTP 400) if the Shop Owner has:
1. Associated **Orders** (`Order.shop_id == shop.id`) — historical orders must be retained for audit and accounting.
2. Recorded **Field Visits** (`Visit.shop_id == shop.id`) — historical executive visits must be retained.

### Request Headers
| Header | Value | Description |
|---|---|---|
| `Authorization` | `Bearer <admin_jwt_token>` | Admin JWT acquired via `POST /api/v1/auth/login` |
| `Accept` | `application/json` | JSON response format |

### Path Parameters
| Parameter | Type | Required | Description |
|---|---|---|---|
| `shop_id` | `integer` | Yes | Database primary key ID of the `shop_owners` record |

### Response Codes & Bodies

#### 200 OK — Successful Permanent Deletion
```json
{
  "success": true,
  "detail": "Shop owner permanently deleted"
}
```

#### 400 Bad Request — Historical Record Conflict (Orders)
```json
{
  "detail": "Cannot delete Shop Owner with associated orders. Historical order records must be preserved."
}
```

#### 400 Bad Request — Historical Record Conflict (Visits)
```json
{
  "detail": "Cannot delete Shop Owner with recorded field visits. Historical visit records must be preserved."
}
```

#### 401 Unauthorized — Missing or Invalid Token
```json
{
  "detail": "Not authenticated"
}
```

#### 403 Forbidden — Non-Admin User Token
```json
{
  "detail": "Operation not permitted"
}
```

#### 404 Not Found — Invalid Shop ID
```json
{
  "detail": "Shop owner not found"
}
```

---

## 2. Delete Field Executive

### Endpoint
`DELETE /api/v1/employees/{employee_id}`

### Description
Permanently deletes a Field Executive profile and their associated `User` account, device push tokens, and ephemeral location tracking telemetry (`fe_locations`). Unlinks any assigned shops (`shop_owners.assigned_executive_id = NULL`).

### Business Safety Constraints
Deletion is **refused** (HTTP 400) if the Field Executive has:
1. Recorded **Field Visits** (`Visit.executive_id == exec.id`).
2. Recorded **Daily Attendance** (`Attendance.executive_id == exec.id`).
3. Submitted **End-of-Day (EOD) Reports** (`EODReport.executive_id == exec.id`).
4. Assigned **Orders** (`Order.assigned_executive_id == exec.id`).

### Request Headers
| Header | Value | Description |
|---|---|---|
| `Authorization` | `Bearer <admin_jwt_token>` | Admin JWT acquired via `POST /api/v1/auth/login` |
| `Accept` | `application/json` | JSON response format |

### Path Parameters
| Parameter | Type | Required | Description |
|---|---|---|---|
| `employee_id` | `integer` | Yes | Database primary key ID of the `field_executives` record |

### Response Codes & Bodies

#### 200 OK — Successful Permanent Deletion
```json
{
  "success": true,
  "detail": "Field executive permanently deleted"
}
```

#### 400 Bad Request — Historical Record Conflict (Visits)
```json
{
  "detail": "Cannot delete Field Executive with recorded visits. Historical visit records must be preserved."
}
```

#### 400 Bad Request — Historical Record Conflict (Attendance)
```json
{
  "detail": "Cannot delete Field Executive with recorded attendance. Attendance history must be preserved."
}
```

#### 400 Bad Request — Historical Record Conflict (EOD Reports)
```json
{
  "detail": "Cannot delete Field Executive with submitted EOD reports. Daily reports must be preserved."
}
```

#### 400 Bad Request — Historical Record Conflict (Orders)
```json
{
  "detail": "Cannot delete Field Executive associated with orders. Order assignment history must be preserved."
}
```

#### 401 Unauthorized — Missing or Invalid Token
```json
{
  "detail": "Not authenticated"
}
```

#### 403 Forbidden — Non-Admin User Token
```json
{
  "detail": "Operation not permitted"
}
```

#### 404 Not Found — Invalid Employee ID
```json
{
  "detail": "Field executive not found"
}
```
