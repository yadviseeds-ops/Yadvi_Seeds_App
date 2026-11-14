with open('backend/app/api/employees.py', 'r', encoding='utf-8') as f:
    content = f.read()

target = """def delete_employee(
    employee_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    \"\"\"
    Permanently delete a field executive if no historical business records exist — Admin only.
    Rejects deletion if the executive is referenced by visits, attendances, EOD reports, or orders.
    \"\"\"
    exec_ = db.query(FieldExecutive).filter(FieldExecutive.id == employee_id).first()
    if not exec_:
        raise HTTPException(status_code=404, detail="Field executive not found")

    from app.models.all_models import Visit, Attendance, EODReport, Order, FELocation, FCMDeviceToken, ShopOwner

    has_visits = db.query(Visit).filter(Visit.executive_id == exec_.id).first() is not None
    if has_visits:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete Field Executive with recorded visits. Historical visit records must be preserved."
        )

    has_attendance = db.query(Attendance).filter(Attendance.executive_id == exec_.id).first() is not None
    if has_attendance:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete Field Executive with recorded attendance. Attendance history must be preserved."
        )

    has_eod = db.query(EODReport).filter(EODReport.executive_id == exec_.id).first() is not None
    if has_eod:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete Field Executive with submitted EOD reports. Daily reports must be preserved."
        )

    has_orders = db.query(Order).filter(Order.assigned_executive_id == exec_.id).first() is not None
    if has_orders:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete Field Executive associated with orders. Order assignment history must be preserved."
        )"""

replacement = """def delete_employee(
    employee_id: int,
    force: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    \"\"\"
    Permanently delete a field executive — Admin only.
    If force=False (default), rejects deletion if the executive is referenced by visits, attendances, EOD reports, or orders.
    If force=True, unassigns shops/orders and cascades associated historical records safely.
    \"\"\"
    exec_ = db.query(FieldExecutive).filter(FieldExecutive.id == employee_id).first()
    if not exec_:
        raise HTTPException(status_code=404, detail="Field executive not found")

    from app.models.all_models import Visit, Attendance, EODReport, Order, FELocation, FCMDeviceToken, ShopOwner

    if not force:
        has_visits = db.query(Visit).filter(Visit.executive_id == exec_.id).first() is not None
        if has_visits:
            raise HTTPException(
                status_code=400,
                detail="Cannot delete Field Executive with recorded visits. Historical visit records must be preserved."
            )

        has_attendance = db.query(Attendance).filter(Attendance.executive_id == exec_.id).first() is not None
        if has_attendance:
            raise HTTPException(
                status_code=400,
                detail="Cannot delete Field Executive with recorded attendance. Attendance history must be preserved."
            )

        has_eod = db.query(EODReport).filter(EODReport.executive_id == exec_.id).first() is not None
        if has_eod:
            raise HTTPException(
                status_code=400,
                detail="Cannot delete Field Executive with submitted EOD reports. Daily reports must be preserved."
            )

        has_orders = db.query(Order).filter(Order.assigned_executive_id == exec_.id).first() is not None
        if has_orders:
            raise HTTPException(
                status_code=400,
                detail="Cannot delete Field Executive associated with orders. Order assignment history must be preserved."
            )
    else:
        db.query(Order).filter(Order.assigned_executive_id == exec_.id).update(
            {"assigned_executive_id": None}, synchronize_session=False
        )
        db.query(Visit).filter(Visit.executive_id == exec_.id).delete(synchronize_session=False)
        db.query(EODReport).filter(EODReport.executive_id == exec_.id).delete(synchronize_session=False)
        db.query(Attendance).filter(Attendance.executive_id == exec_.id).delete(synchronize_session=False)"""

norm_content = content.replace('\r\n', '\n')
norm_target = target.replace('\r\n', '\n')
norm_replacement = replacement.replace('\r\n', '\n')

assert norm_target in norm_content, "Target not found in content"
new_content = norm_content.replace(norm_target, norm_replacement)
with open('backend/app/api/employees.py', 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(new_content)
print("Successfully patched delete_employee in employees.py")

