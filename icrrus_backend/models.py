from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text, ForeignKey, Numeric
from sqlalchemy.orm import relationship
from database import Base
from datetime import datetime

# 1. CORE HIERARCHY
class Office(Base):
    __tablename__ = "offices"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True)
    description = Column(Text)
    is_active = Column(Boolean, default=True)

class Department(Base): # Matches 'departments'
    __tablename__ = "departments"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True)
    head_id = Column(Integer, nullable=True)

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(String, unique=True, nullable=True)
    email = Column(String, unique=True, index=True)
    full_name = Column(String)
    password_hash = Column(String, nullable=True)
    role = Column(String)
    office_id = Column(Integer, ForeignKey("offices.id"), nullable=True)
    department_id = Column(Integer, ForeignKey("departments.id"), nullable=True)
    is_active = Column(Boolean, default=True)

# 2. SERVICES & QUEUES
class Service(Base):
    __tablename__ = "services"
    id = Column(Integer, primary_key=True, index=True)
    office_id = Column(Integer, ForeignKey("offices.id"))
    name = Column(String)
    avg_processing_time = Column(Integer)

class DepartmentService(Base): # Matches 'department_services'
    __tablename__ = "department_services"
    id = Column(Integer, primary_key=True, index=True)
    department_id = Column(Integer, ForeignKey("departments.id"))
    service_name = Column(String)

class Counter(Base):
    __tablename__ = "counters"
    id = Column(Integer, primary_key=True, index=True)
    office_id = Column(Integer, ForeignKey("offices.id"))
    name = Column(String)
    status = Column(String, default="CLOSED")

class ServiceQueueEntry(Base): # Matches 'service_queue_entries'
    __tablename__ = "service_queue_entries"
    id = Column(Integer, primary_key=True, index=True)
    service_id = Column(Integer, ForeignKey("services.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    ticket_number = Column(String)
    status = Column(String, default="WAITING")

class QueueTicket(Base): # Matches 'queue_tickets'
    __tablename__ = "queue_tickets"
    id = Column(Integer, primary_key=True, index=True)
    ticket_code = Column(String)
    issued_at = Column(DateTime, default=datetime.utcnow)

# 3. SPACES & BOOKINGS
class Room(Base):
    __tablename__ = "rooms"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    capacity = Column(Integer)
    location = Column(String) # 'FACILITY' or 'LIBRARY'
    description = Column(String, nullable=True) # ADD THIS
    equipment = Column(String, nullable=True)   # ADD THIS
    is_faculty_only = Column(Boolean, default=False) # ADD THIS
    status = Column(String, default="AVAILABLE")

class Booking(Base):
    __tablename__ = "bookings"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    room_id = Column(Integer, ForeignKey("rooms.id"))
    start_time = Column(DateTime)
    end_time = Column(DateTime)
    status = Column(String, default="PENDING")
    
    # --- FIXED COLUMNS ---
    purpose = Column(Text, nullable=True)
    qr_code_token = Column(String, nullable=True)
    rejection_reason = Column(Text, nullable=True)
    
    # Collaborative pax count - ADD THIS LINE
    student_count = Column(Integer, default=1) 

    # Relationships
    user = relationship("User")
    room = relationship("Room")

class Reservation(Base): # Matches 'reservations'
    # Use this for specialized bookings or redundant checks
    __tablename__ = "reservations"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    item_type = Column(String) # 'ROOM' or 'EQUIPMENT'
    item_id = Column(Integer)
    status = Column(String)

# 4. ASSETS & LOGS
class Equipment(Base):
    __tablename__ = "equipment"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    serial_number = Column(String)
    status = Column(String, default="AVAILABLE")

class BorrowingLog(Base): # Matches 'borrowing_logs'
    __tablename__ = "borrowing_logs"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    equipment_id = Column(Integer, ForeignKey("equipment.id"))
    borrowed_at = Column(DateTime)
    returned_at = Column(DateTime)

class MaintenanceLog(Base): # Matches 'maintenance_logs'
    __tablename__ = "maintenance_logs"
    id = Column(Integer, primary_key=True, index=True)
    description = Column(Text)
    status = Column(String)

class MaintenanceReport(Base): # Matches 'maintenance_reports'
    __tablename__ = "maintenance_reports"
    id = Column(Integer, primary_key=True, index=True)
    report_data = Column(Text)
    generated_at = Column(DateTime)

class Payment(Base):
    __tablename__ = "payments"
    id = Column(Integer, primary_key=True, index=True)
    amount = Column(Numeric)
    status = Column(String)

class OtpLog(Base): # Matches 'otp_logs'
    __tablename__ = "otp_logs"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    otp_code = Column(String)
    expires_at = Column(DateTime)