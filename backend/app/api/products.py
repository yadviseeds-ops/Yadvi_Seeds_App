from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from app.core.database import get_db
from app.core.security import get_current_user, require_role
from app.models.all_models import Product, User

router = APIRouter(prefix="/products", tags=["Products & Inventory"])


class ProductCreate(BaseModel):
    name: str
    variety_type: str
    sku: str
    category: str
    image_url: str
    available_stock_bags: int = 0
    germination_rate: str = "85% Min"
    purity: str = "98% Min"
    maturity_days: Optional[str] = None
    crop_season: Optional[str] = None
    availability: str = "In Stock"
    description: Optional[str] = None
    resistance_traits: Optional[str] = None
    package_sizes: str = "100g, 500g, 1kg"

class ProductOut(BaseModel):
    id: int
    name: str
    variety_type: str
    sku: str
    category: str
    image_url: str
    available_stock_bags: int
    germination_rate: str
    purity: str
    maturity_days: Optional[str]
    crop_season: Optional[str]
    availability: str
    description: Optional[str]
    resistance_traits: Optional[str]
    package_sizes: str

    class Config:
        from_attributes = True


class StockUpdateRequest(BaseModel):
    available_stock_bags: int
    availability: Optional[str] = None


@router.post("", response_model=ProductOut)
def create_product(
    payload: ProductCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """Create a new product — Admin only."""
    if db.query(Product).filter(Product.sku == payload.sku).first():
        raise HTTPException(status_code=400, detail="SKU already exists")
    
    new_product = Product(
        name=payload.name,
        variety_type=payload.variety_type,
        sku=payload.sku,
        category=payload.category,
        image_url=payload.image_url,
        available_stock_bags=payload.available_stock_bags,
        germination_rate=payload.germination_rate,
        purity=payload.purity,
        maturity_days=payload.maturity_days,
        crop_season=payload.crop_season,
        availability=payload.availability,
        description=payload.description,
        resistance_traits=payload.resistance_traits,
        package_sizes=payload.package_sizes
    )
    db.add(new_product)
    db.commit()
    db.refresh(new_product)
    return new_product


@router.get("", response_model=List[ProductOut])
def list_products(
    category: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List all products. Accessible to all authenticated roles."""
    query = db.query(Product)
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
    product.available_stock_bags = payload.available_stock_bags
    if payload.availability:
        product.availability = payload.availability
    db.commit()
    db.refresh(product)
    return {"success": True, "product_id": product_id, "new_stock": product.available_stock_bags}
