# Phase 16 Bug Discovery

Based on the code audit, here are the exact root causes and the files that need modification.

### 1. Root Cause of FE not receiving assigned orders

**The Issue:** The Admin can assign an order to an FE, but the assigned order does not appear in the FE's LR Tracking screen.

**The Root Cause:** 
The FE's LR Tracking screen specifically queries the `GET /api/v1/shipments/my` endpoint, which fetches from the `shipments` table. 
However, in the Yadvi backend, a `Shipment` record is **only** created when the Admin advances the order to `"Dispatched"` and provides an `lr_number` (via `update_order_status` in `orders.py`). 
If the Admin merely assigns an Executive (which updates `assigned_executive_id` and changes the status to `"Confirmed"`), no LR exists yet, so no Shipment exists in the database. Therefore, the LR tracking screen, which is designed to track LRs/Shipments, naturally sees nothing until the Admin reaches the "Generate LR & Dispatch Consignment" step.

*(Note: The assigned order does correctly appear in the FE's "Today's Plan -> Assigned Orders" list, as that queries the `orders` table directly, but it won't appear in "LR Tracking" until dispatched).*

### 2. Root Cause of Admin being able to mark "Delivered"

**The Issue:** The Admin can circumvent the FE Check-Out and manually mark an order/shipment as "Delivered".

**The Root Cause:**
- **Frontend (`src/components/admin/AdminOrders.tsx`)**: The UI defines a status sequence (`Dispatched` -> `In Transit` -> `Delivered`) and blindly renders "Mark In Transit" and "Mark Delivered" action buttons for the Admin if the order is past the Dispatched stage.
- **Backend (`backend/app/api/orders.py` and `backend/app/api/shipments.py`)**: The `update_order_status` and `update_shipment_status` endpoints accept any status payload without enforcing Role-Based Status Authority. If the Admin submits `{"status": "Delivered"}`, the backend simply accepts it and commits it to the database, completely bypassing the FE Check-Out logic in `tracking.py`.

### 3. Exact files and functions that need modification

To enforce the strict business rules (Admin authority ends at Dispatch; FE Check-In/Check-Out handles In Transit/Delivered), the following files must be modified:

**Frontend Changes:**
*   **`src/components/admin/AdminOrders.tsx`**: 
    *   Remove the sequence progression for `In Transit` and `Delivered`.
    *   Remove the buttons that allow the Admin to "Mark In Transit" and "Mark Delivered". The Admin workflow should conclude at the "Generate LR & Dispatch Consignment" button.

**Backend Changes:**
*   **`backend/app/api/orders.py`** (Function: `update_order_status`):
    *   Add validation to reject the update if `payload.status` is `"In Transit"` or `"Delivered"`. (e.g., `raise HTTPException(status_code=403, detail="Admin cannot set Delivery states. Field Executive check-in/out is required.")`)
*   **`backend/app/api/shipments.py`** (Function: `update_shipment_status`):
    *   Add identical validation to reject `"In Transit"` and `"Delivered"` statuses.

*The FE's visibility issue (Issue 1) is actually functioning according to the data model (LR Tracking requires an LR). If the business rule requires the FE to see the order in LR Tracking before dispatch, we would need to redesign the Flutter UI to query Orders instead of Shipments. Otherwise, the current behavior is logically correct based on the dispatch flow.*
