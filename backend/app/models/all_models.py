from datetime import datetime
from sqlalchemy import (
    Column, Integer, String, Text, Boolean, Float, DateTime, ForeignKey, Enum
)
from sqlalchemy.orm import relationship
from app.core.database import Base

class Role(Base):
    __tablename__ = "roles"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, nullable=False, index=True)  # administrator, field_executive, shop_owner
    description = Column(String(255), nullable=True)

    users = relationship("User", back_populates="role")

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(100), unique=True, nullable=True, index=True)
    phone = Column(String(20), unique=True, nullable=False, index=True)
    username = Column(String(50), unique=True, nullable=True, index=True)
    full_name = Column(String(100), nullable=False)
    hashed_password = Column(String(255), nullable=True)
    role_id = Column(Integer, ForeignKey("roles.id"), nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    role = relationship("Role", back_populates="users")
    shop_profile = relationship("ShopOwner", back_populates="user", uselist=False)
    field_profile = relationship("FieldExecutive", back_populates="user", uselist=False)
    fcm_tokens = relationship("FCMDeviceToken", back_populates="user")

class ShopOwner(Base):
    __tablename__ = "shop_owners"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    shop_name = Column(String(150), nullable=False)
    dealer_code = Column(String(50), unique=True, nullable=False)
    market_location = Column(String(150), nullable=False)
    territory = Column(String(100), nullable=True)
    city = Column(String(100), nullable=True)
    address = Column(Text, nullable=False)
    lat = Column(Float, nullable=True)
    lng = Column(Float, nullable=True)
    shop_photo_url = Column(String(255), nullable=True)
    owner_photo_url = Column(String(255), nullable=True)
    opening_stock_bags = Column(Integer, default=0)
    current_stock_bags = Column(Integer, default=0)
    primary_demand_crop = Column(String(100), nullable=True)
    status = Column(String(20), default="Active")  # Active, Inactive
    assigned_executive_id = Column(Integer, ForeignKey("field_executives.id"), nullable=True)

    user = relationship("User", back_populates="shop_profile")
    assigned_executive = relationship("FieldExecutive", back_populates="assigned_shops")
    orders = relationship("Order", back_populates="shop")
    visits = relationship("Visit", back_populates="shop")

class FieldExecutive(Base):
    __tablename__ = "field_executives"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    employee_code = Column(String(50), unique=True, nullable=False)
    designation = Column(String(100), default="Field Sales Officer")
    assigned_territory = Column(String(100), nullable=False)
    current_lat = Column(Float, nullable=True)
    current_lng = Column(Float, nullable=True)
    battery_level = Column(Integer, default=100)
    attendance_status = Column(String(50), default="Present")  # Present, In Field, Late, On Leave
    distance_covered_km = Column(Float, default=0.0)
    last_location_update = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="field_profile")
    assigned_shops = relationship("ShopOwner", back_populates="assigned_executive")
    visits = relationship("Visit", back_populates="executive")
    orders_collected = relationship("Order", back_populates="assigned_executive")
    attendances = relationship("Attendance", back_populates="executive")

class Product(Base):
    __tablename__ = "products"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(150), nullable=False)
    variety_type = Column(String(100), nullable=False)
    sku = Column(String(50), unique=True, nullable=False, index=True)
    category = Column(String(50), nullable=False)  # Chilli, Okra, Dolichos, Pulses, Field Crops, Vegetables
    image_url = Column(String(255), nullable=False)
    available_stock_bags = Column(Integer, default=0)
    germination_rate = Column(String(50), default="85% Min")
    purity = Column(String(50), default="98% Min")
    maturity_days = Column(String(50), nullable=True)
    crop_season = Column(String(100), nullable=True)
    availability = Column(String(50), default="In Stock")
    description = Column(Text, nullable=True)
    resistance_traits = Column(String(255), nullable=True)
    package_sizes = Column(String(255), default="100g, 500g, 1kg")  # Comma-separated sizes

    inventory_items = relationship("Inventory", back_populates="product")
    order_items = relationship("OrderItem", back_populates="product")

class Inventory(Base):
    __tablename__ = "inventory"

    id = Column(Integer, primary_key=True, index=True)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)
    warehouse_location = Column(String(100), default="Central Gannavaram Plant")
    batch_number = Column(String(50), nullable=False)
    total_bags = Column(Integer, default=0)
    reserved_bags = Column(Integer, default=0)
    last_stock_audit = Column(DateTime, default=datetime.utcnow)

    product = relationship("Product", back_populates="inventory_items")

class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)
    order_number = Column(String(50), unique=True, nullable=False, index=True)
    shop_id = Column(Integer, ForeignKey("shop_owners.id"), nullable=False)
    assigned_executive_id = Column(Integer, ForeignKey("field_executives.id"), nullable=True)
    total_quantity_bags = Column(Integer, nullable=False)
    total_items_count = Column(Integer, nullable=False)
    status = Column(String(50), default="New")  # New, Confirmed, Processing, Packed, Dispatched, In Transit, Delivered, Cancelled
    source = Column(String(50), default="Shop Owner App")  # Shop Owner App, Field Executive, Admin Portal
    delivery_notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    shop = relationship("ShopOwner", back_populates="orders")
    assigned_executive = relationship("FieldExecutive", back_populates="orders_collected")
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")
    shipment = relationship("Shipment", back_populates="order", uselist=False)

class OrderItem(Base):
    __tablename__ = "order_items"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)
    package_size = Column(String(50), nullable=False)
    quantity_bags = Column(Integer, nullable=False)

    order = relationship("Order", back_populates="items")
    product = relationship("Product", back_populates="order_items")

class Visit(Base):
    __tablename__ = "visits"

    id = Column(Integer, primary_key=True, index=True)
    executive_id = Column(Integer, ForeignKey("field_executives.id"), nullable=False)
    shop_id = Column(Integer, ForeignKey("shop_owners.id"), nullable=False)
    purpose = Column(String(100), default="Dealer Audit & Stock Booking")
    status = Column(String(50), default="Pending")  # Pending, In Progress, Completed
    check_in_time = Column(DateTime, nullable=True) # Keeping for backwards compat temporarily
    check_out_time = Column(DateTime, nullable=True)
    check_in_lat = Column(Float, nullable=True)
    check_in_lng = Column(Float, nullable=True)
    notes = Column(Text, nullable=True)
    bags_ordered = Column(Integer, default=0)
    scheduled_date = Column(DateTime, default=datetime.utcnow)
    
    # New Geotagged Visit Photo Requirements
    visit_photo_url = Column(String(255), nullable=True)
    photo_lat = Column(Float, nullable=True)
    photo_lng = Column(Float, nullable=True)
    visited_at = Column(DateTime, nullable=True)

    executive = relationship("FieldExecutive", back_populates="visits")
    shop = relationship("ShopOwner", back_populates="visits")

class Attendance(Base):
    __tablename__ = "attendance"

    id = Column(Integer, primary_key=True, index=True)
    executive_id = Column(Integer, ForeignKey("field_executives.id"), nullable=False)
    date = Column(DateTime, default=datetime.utcnow)
    check_in_time = Column(DateTime, nullable=True)
    check_out_time = Column(DateTime, nullable=True)
    status = Column(String(50), default="Present")  # Present, Late, Absent, Half Day, On Leave
    distance_covered_km = Column(Float, default=0.0)
    check_in_location = Column(String(150), nullable=True)

    executive = relationship("FieldExecutive", back_populates="attendances")

class Shipment(Base):
    __tablename__ = "shipments"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), unique=True, nullable=False)
    lr_number = Column(String(50), unique=True, nullable=False, index=True)
    transporter_name = Column(String(100), nullable=False)
    vehicle_number = Column(String(50), nullable=True)
    driver_name = Column(String(100), nullable=True)
    driver_phone = Column(String(20), nullable=True)
    dispatch_date = Column(DateTime, default=datetime.utcnow)
    estimated_delivery = Column(String(100), default="Within 48 Hours")
    status = Column(String(50), default="Dispatched")  # Dispatched, In Transit, Out for Delivery, Delivered
    current_location = Column(String(150), default="Gannavaram Central Hub")

    order = relationship("Order", back_populates="shipment")

class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    recipient_phone = Column(String(20), nullable=False)
    channel = Column(String(50), default="WhatsApp")  # WhatsApp, Push, SMS
    order_number = Column(String(50), nullable=True)
    shop_name = Column(String(150), nullable=True)
    total_bags = Column(Integer, nullable=True)
    status = Column(String(50), default="Sent")
    message_content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

class FCMDeviceToken(Base):
    __tablename__ = "fcm_device_tokens"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    device_token = Column(String(255), unique=True, nullable=False)
    platform = Column(String(50), nullable=True) # android, ios, web
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="fcm_tokens")

class FELocation(Base):
    __tablename__ = "fe_locations"

    id = Column(Integer, primary_key=True, index=True)
    executive_id = Column(Integer, ForeignKey("field_executives.id"), nullable=False)
    lat = Column(Float, nullable=False)
    lng = Column(Float, nullable=False)
    accuracy = Column(Float, nullable=True)
    speed = Column(Float, nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow)

    executive = relationship("FieldExecutive")
