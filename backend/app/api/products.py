from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.orm import Session
from typing import List, Optional
import os
import uuid
from pydantic import BaseModel
from app.core.database import get_db
from app.core.security import get_current_user, require_role
from app.core.media_storage import get_media_storage, validate_image_content, generate_safe_filename
from app.models.all_models import Product, User

router = APIRouter(prefix="/products", tags=["Products & Inventory"])


class ProductCreate(BaseModel):
    name: str
    variety_type: str
    sku: Optional[str] = None
    category: str
    image_url: Optional[str] = ""
    available_stock_kg: Optional[float] = 0.0
    available_stock_bags: Optional[int] = 0
    germination_rate: str = "85% Min"
    purity: str = "98% Min"
    maturity_days: Optional[str] = None
    crop_season: Optional[str] = None
    availability: str = "In Stock"
    description: Optional[str] = None
    resistance_traits: Optional[str] = None
    package_sizes: str = "100g, 500g, 1kg"

class ProductUpdate(BaseModel):
    name: Optional[str] = None
    variety_type: Optional[str] = None
    sku: Optional[str] = None
    category: Optional[str] = None
    image_url: Optional[str] = None
    available_stock_kg: Optional[float] = None
    available_stock_bags: Optional[int] = None
    germination_rate: Optional[str] = None
    purity: Optional[str] = None
    maturity_days: Optional[str] = None
    crop_season: Optional[str] = None
    availability: Optional[str] = None
    description: Optional[str] = None
    resistance_traits: Optional[str] = None
    package_sizes: Optional[str] = None
    is_active: Optional[bool] = None

class ProductOut(BaseModel):
    id: int
    name: str
    variety_type: str
    sku: str
    category: str
    image_url: str
    available_stock_kg: Optional[float] = None
    available_stock_bags: Optional[int] = 0
    germination_rate: str
    purity: str
    maturity_days: Optional[str]
    crop_season: Optional[str]
    availability: str
    description: Optional[str]
    resistance_traits: Optional[str]
    package_sizes: str
    is_active: bool

    class Config:
        from_attributes = True


class StockUpdateRequest(BaseModel):
    available_stock_kg: Optional[float] = None
    available_stock_bags: Optional[int] = None
    availability: Optional[str] = None


@router.post("", response_model=ProductOut)
def create_product(
    payload: ProductCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """Create a new product — Admin only."""
    import re
    clean_name = (payload.name or "").strip()
    clean_variety_type = (payload.variety_type or "").strip()
    clean_category = (payload.category or "").strip()
    clean_image_url = (payload.image_url or "").strip() or "https://placehold.co/400x400/2e7d32/ffffff?text=Seeds"
    clean_package_sizes = (payload.package_sizes or "").strip() or "100g, 500g, 1kg"

    # Mandatory field validation
    if not clean_name:
        raise HTTPException(status_code=400, detail="Product Name is mandatory. Please fill it.")
    if not clean_variety_type:
        raise HTTPException(status_code=400, detail="Variety Type is mandatory. Please fill it.")
    if not clean_category:
        raise HTTPException(status_code=400, detail="Category is mandatory. Please fill it.")

    # Handle SKU (auto-generate if omitted/empty)
    if payload.sku and payload.sku.strip():
        clean_sku = payload.sku.strip()
        if db.query(Product).filter(Product.sku == clean_sku).first():
            raise HTTPException(status_code=400, detail=f"SKU code '{clean_sku}' already exists")
    else:
        cat_code = re.sub(r"[^A-Za-z]", "", clean_category)[:3].upper() or "VAR"
        clean_sku = f"YHS-{cat_code}-{uuid.uuid4().hex[:6].upper()}"
        while db.query(Product).filter(Product.sku == clean_sku).first():
            clean_sku = f"YHS-{cat_code}-{uuid.uuid4().hex[:6].upper()}"

    try:
        stock_kg = payload.available_stock_kg if payload.available_stock_kg is not None and payload.available_stock_kg > 0 else float(payload.available_stock_bags or 0)
        new_product = Product(
            name=clean_name,
            variety_type=clean_variety_type,
            sku=clean_sku,
            category=clean_category,
            image_url=clean_image_url,
            available_stock_kg=max(0.0, stock_kg),
            available_stock_bags=int(stock_kg),
            germination_rate=(payload.germination_rate or "85% Min").strip(),
            purity=(payload.purity or "98% Min").strip(),
            maturity_days=payload.maturity_days.strip() if payload.maturity_days and payload.maturity_days.strip() else None,
            crop_season=payload.crop_season.strip() if payload.crop_season and payload.crop_season.strip() else None,
            availability=(payload.availability or "In Stock").strip(),
            description=payload.description.strip() if payload.description and payload.description.strip() else None,
            resistance_traits=payload.resistance_traits.strip() if payload.resistance_traits and payload.resistance_traits.strip() else None,
            package_sizes=clean_package_sizes
        )
        db.add(new_product)
        db.commit()
        db.refresh(new_product)
        return new_product
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database error creating product: {str(exc)}")


@router.get("", response_model=List[ProductOut])
def list_products(
    category: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List all products. Accessible to all authenticated roles."""
    query = db.query(Product).filter(Product.is_active == True)
    if category:
        query = query.filter(Product.category.ilike(f"%{category}%"))
    return query.order_by(Product.category, Product.name).all()


@router.get("/{product_id}", response_model=ProductOut)
def get_product(
    product_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product


@router.put("/{product_id}/stock")
def update_stock(
    product_id: int,
    payload: StockUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """Update product stock — Admin only."""
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    stock_val = payload.available_stock_kg if payload.available_stock_kg is not None else float(payload.available_stock_bags or 0)
    product.available_stock_kg = max(0.0, stock_val)
    product.available_stock_bags = int(stock_val)
    if payload.availability:
        product.availability = payload.availability
    db.commit()
    db.refresh(product)
    return {"success": True, "product_id": product_id, "new_stock_kg": product.available_stock_kg}


@router.put("/{product_id}", response_model=ProductOut)
def update_product(
    product_id: int,
    payload: ProductUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """Update product details — Admin only."""
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    if payload.name is not None and payload.name.strip():
        product.name = payload.name.strip()
    if payload.variety_type is not None and payload.variety_type.strip():
        product.variety_type = payload.variety_type.strip()
    if payload.sku is not None and payload.sku.strip():
        clean_sku = payload.sku.strip()
        existing = db.query(Product).filter(Product.sku == clean_sku, Product.id != product_id).first()
        if existing:
            raise HTTPException(status_code=400, detail=f"SKU code '{clean_sku}' already exists")
        product.sku = clean_sku
    if payload.category is not None and payload.category.strip():
        product.category = payload.category.strip()
    if payload.image_url is not None and payload.image_url.strip():
        product.image_url = payload.image_url.strip()
    if payload.available_stock_kg is not None:
        product.available_stock_kg = max(0.0, payload.available_stock_kg)
        product.available_stock_bags = int(payload.available_stock_kg)
    elif payload.available_stock_bags is not None:
        product.available_stock_kg = max(0.0, float(payload.available_stock_bags))
        product.available_stock_bags = payload.available_stock_bags
    if payload.germination_rate is not None:
        product.germination_rate = payload.germination_rate.strip()
    if payload.purity is not None:
        product.purity = payload.purity.strip()
    if payload.maturity_days is not None:
        product.maturity_days = payload.maturity_days.strip() or None
    if payload.crop_season is not None:
        product.crop_season = payload.crop_season.strip() or None
    if payload.availability is not None:
        product.availability = payload.availability.strip()
    if payload.description is not None:
        product.description = payload.description.strip() or None
    if payload.resistance_traits is not None:
        product.resistance_traits = payload.resistance_traits.strip() or None
    if payload.package_sizes is not None:
        product.package_sizes = payload.package_sizes.strip() or "100g, 500g, 1kg"
    if payload.is_active is not None:
        product.is_active = payload.is_active

    try:
        db.commit()
        db.refresh(product)
        return product
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database error updating product: {str(exc)}")


@router.delete("/{product_id}")
def delete_product(
    product_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """
    Permanently delete a product if no historical customer orders exist — Admin only.
    Rejects deletion if the product is referenced by order items.
    """
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    from app.models.all_models import OrderItem, Inventory

    has_order_items = db.query(OrderItem).filter(OrderItem.product_id == product.id).first() is not None
    if has_order_items:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete Product with existing customer orders. Order history must be preserved."
        )

    try:
        # Delete warehouse inventory staging batches for this product
        db.query(Inventory).filter(Inventory.product_id == product.id).delete(synchronize_session="fetch")

        # Delete product
        db.delete(product)

        db.commit()
        return {"success": True, "detail": "Product permanently deleted"}
    except HTTPException:
        db.rollback()
        raise
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database error deleting product: {str(exc)}")


@router.post("/upload-image")
async def upload_product_image(
    file: UploadFile = File(...),
    current_user: User = Depends(require_role(["administrator"]))
):
    """Upload product image — Admin only."""
    contents = await file.read()
    detected_ext, detected_mime = validate_image_content(
        contents,
        max_size_bytes=5 * 1024 * 1024,
        allowed_extensions=["jpg", "jpeg", "png", "webp"]
    )

    filename = generate_safe_filename(extension=detected_ext)
    storage = get_media_storage()
    image_url = storage.save(contents, filename, content_type=detected_mime, folder="products")
    return {"image_url": image_url}
