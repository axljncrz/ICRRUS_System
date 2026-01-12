from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

# --- AUTH & USERS ---
class UserBase(BaseModel):
    email: str
    school_id: Optional[str] = None

class UserLogin(UserBase):
    password: str  # <--- FIXED: Now allows password login!

class UserResponse(UserBase):
    id: int
    full_name: str
    role: str
    class Config:
        orm_mode = True

# --- ROOMS & BOOKINGS ---
class RoomResponse(BaseModel):
    id: int
    name: str
    capacity: int
    status: str
    description: Optional[str] = None
    class Config:
        orm_mode = True

# --- BOOKING SCHEMAS ---
class BookingCreate(BaseModel):
    user_id: int
    room_id: int
    start_time: datetime
    end_time: datetime
    purpose: str

# <--- ADDED: Necessary for Admin Dashboard "Approve" button
class BookingUpdate(BaseModel):
    status: str

class BookingResponse(BaseModel):
    id: int
    room_name: str
    start_time: datetime
    end_time: datetime
    status: str
    qr_code_token: Optional[str] = None 
    
    class Config:
        orm_mode = True

# --- QUEUES (AI) ---
class QueueJoin(BaseModel):
    user_id: int
    service_id: int

class QueueResponse(BaseModel):
    ticket_number: str
    status: str
    estimated_wait_time: int
    class Config:
        orm_mode = True

# --- MAINTENANCE ---
class MaintenanceReportCreate(BaseModel):
    reported_by: int
    description: str
    room_id: Optional[int] = None
    equipment_id: Optional[int] = None