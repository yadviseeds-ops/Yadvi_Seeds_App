with open('backend/app/api/auth.py', 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Update _create_token_response
old_token_resp = '''def _create_token_response(user: User) -> TokenResponse:
    user_actual_role = user.role.name if user.role else ""
    redirect_map = {
        "administrator": "/admin",
        "field_executive": "/field-executive",
        "shop_owner": "/shop-owner"
    }

    metadata = {}
    if user_actual_role == "shop_owner" and user.shop_profile:
        metadata["shop_name"] = user.shop_profile.shop_name
        metadata["shop_id"] = user.shop_profile.id
    elif user_actual_role == "field_executive" and user.field_profile:
        metadata["employee_code"] = user.field_profile.employee_code
        metadata["assigned_territory"] = user.field_profile.assigned_territory

    access_token = create_access_token(
        data={
            "sub": str(user.id),
            "role": user_actual_role,
            "name": user.full_name
        }
    )

    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        role=user_actual_role,
        user_id=user.id,
        full_name=user.full_name,
        redirect_path=redirect_map.get(user_actual_role, "/admin"),
        metadata=metadata
    )'''

new_token_resp = '''def _create_token_response(user: User) -> TokenResponse:
    user_actual_role = user.role.name if user.role else ""
    redirect_map = {
        "administrator": "/admin",
        "field_executive": "/field-executive",
        "shop_owner": "/shop-owner"
    }

    metadata = {}
    if user_actual_role == "shop_owner" and user.shop_profile:
        metadata["shop_name"] = user.shop_profile.shop_name
        metadata["shop_id"] = user.shop_profile.id
    elif user_actual_role == "field_executive" and user.field_profile:
        metadata["employee_code"] = user.field_profile.employee_code
        metadata["assigned_territory"] = user.field_profile.assigned_territory

    effective_name = user.full_name or user.username or (
        "Shop Owner" if user_actual_role == "shop_owner" else
        "Field Executive" if user_actual_role == "field_executive" else
        "Administrator"
    )

    access_token = create_access_token(
        data={
            "sub": str(user.id),
            "role": user_actual_role,
            "name": effective_name
        }
    )

    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        role=user_actual_role,
        user_id=user.id,
        full_name=effective_name,
        redirect_path=redirect_map.get(user_actual_role, "/admin"),
        metadata=metadata
    )'''

assert old_token_resp in code, 'old_token_resp not found'
code = code.replace(old_token_resp, new_token_resp)

# 2. Update find_authorized_user
old_find_user = '''def find_authorized_user(db: Session, clean_username: str, norm_mobile: str) -> Optional[User]:
    """
    Locates an active user by username and phone number.
    Supports primary phone matching for all roles via users.phone,
    as well as authorized secondary phone numbers for the administrator account
    strictly mapped in the admin_phones database table.
    """
    candidates = [norm_mobile, f"+91{norm_mobile}", f"0{norm_mobile}", f"91{norm_mobile}"]
    username_candidates = [clean_username]
    if clean_username.lower() in ("shri", "shree"):
        username_candidates = ["Shree", "shree", "shri", "Shri"]

    # 1. Primary match on users.phone (exact normalized match)
    user = db.query(User).filter(
        User.username.in_(username_candidates),
        User.phone.in_(candidates)
    ).first()
    if user and normalize_phone_number(user.phone) == norm_mobile:
        return user'''

new_find_user = '''def find_authorized_user(db: Session, clean_username: str, norm_mobile: str) -> Optional[User]:
    """
    Locates an active user by username and phone number.
    Supports primary phone matching for all roles via users.phone,
    as well as authorized secondary phone numbers for the administrator account
    strictly mapped in the admin_phones database table.
    """
    from sqlalchemy import func, or_
    candidates = [norm_mobile, f"+91{norm_mobile}", f"0{norm_mobile}", f"91{norm_mobile}"]
    username_candidates = [clean_username, clean_username.lower(), clean_username.capitalize()]
    if clean_username.lower() in ("shri", "shree"):
        username_candidates.extend(["Shree", "shree", "shri", "Shri"])
    username_candidates = list(set(username_candidates))

    # 1. Primary match on users.phone (case-insensitive username match)
    user = db.query(User).filter(
        or_(
            User.username.in_(username_candidates),
            func.lower(func.trim(User.username)) == clean_username.lower().strip()
        ),
        User.phone.in_(candidates)
    ).first()
    if user and normalize_phone_number(user.phone) == norm_mobile:
        return user

    # 1b. If username had minor variation, match by exact unique registered phone for SO / FE
    potential_user = db.query(User).filter(User.phone.in_(candidates)).first()
    if potential_user and normalize_phone_number(potential_user.phone) == norm_mobile and potential_user.is_active:
        user_role = potential_user.role.name if potential_user.role else ""
        if user_role in ("shop_owner", "field_executive"):
            u_name = (potential_user.username or "").lower().strip()
            f_name = (potential_user.full_name or "").lower().strip()
            c_name = clean_username.lower().strip()
            s_name = (potential_user.shop_profile.shop_name if potential_user.shop_profile else "").lower().strip()
            if not c_name or c_name == u_name or c_name == f_name or c_name == s_name or (c_name in ("shri", "shree") and u_name in ("shri", "shree")):
                return potential_user'''

assert old_find_user in code, 'old_find_user not found'
code = code.replace(old_find_user, new_find_user)

with open('backend/app/api/auth.py', 'w', encoding='utf-8', newline='') as f:
    f.write(code)
print('Successfully patched backend/app/api/auth.py')

