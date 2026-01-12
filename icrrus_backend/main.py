from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from datetime import datetime
import uuid
import models
from database import engine, SessionLocal

# --- DATABASE INITIALIZATION ---
# Automatically creates/updates tables based on models.py definitions
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="ICRRUS Backend System")

# --- CORS MIDDLEWARE ---
# Essential for Flutter Web and Mobile cross-origin requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- 1. AUTHENTICATION ---
@app.post("/login")
def login(user_data: dict, db: Session = Depends(get_db)):
    email = user_data.get("email")
    # Searches for user based on email provided in Flutter LoginScreen
    db_user = db.query(models.User).filter(models.User.email == email).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found.")
    return {
        "id": db_user.id,
        "email": db_user.email,
        "full_name": db_user.full_name,
        "role": db_user.role,
        "school_id": db_user.school_id
    }

# --- 2. ROOM MANAGEMENT (LIBRARIAN & ADMIN) ---

@app.get("/rooms")
def get_rooms(db: Session = Depends(get_db)):
    rooms = db.query(models.Room).all()
    results = []
    for r in rooms:
        # Check if room is currently occupied by a CHECKED_IN user
        active = db.query(models.Booking).filter(
            models.Booking.room_id == r.id,
            models.Booking.status == "CHECKED_IN"
        ).first()
        
        status = "OCCUPIED" if active else "AVAILABLE"
        
        results.append({
            "id": r.id, 
            "name": r.name, 
            "capacity": r.capacity, 
            "status": status,
            "location": r.location, # Now pulls directly from DB location field
            "description": r.description,
            "equipment": r.equipment,
            "is_faculty_only": r.is_faculty_only
        })
    return results

@app.post("/admin/rooms/add")
def add_new_room(room_data: dict, db: Session = Depends(get_db)):
    try:
        new_room = models.Room(
            name=room_data['name'],
            capacity=room_data['capacity'],
            description=room_data['description'],
            equipment=room_data['equipment'],
            location=room_data['location'],
            is_faculty_only=room_data['is_faculty_only'],
            status="AVAILABLE" 
        )
        db.add(new_room)
        db.commit()
        db.refresh(new_room)
        return {"status": "success", "room_id": new_room.id}
    except Exception as e:
        db.rollback()
        print(f"Database Error: {e}") 
        raise HTTPException(status_code=500, detail=str(e))

# NEW: Update endpoint for the Admin Dashboard Edit function
@app.put("/admin/rooms/update/{room_id}")
def update_room(room_id: int, data: dict, db: Session = Depends(get_db)):
    room = db.query(models.Room).filter(models.Room.id == room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    
    try:
        room.name = data.get('name', room.name)
        room.capacity = data.get('capacity', room.capacity)
        room.description = data.get('description', room.description)
        room.equipment = data.get('equipment', room.equipment)
        room.is_faculty_only = data.get('is_faculty_only', room.is_faculty_only)
        
        db.commit()
        return {"status": "success"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

# --- 3. BOOKING & COLLABORATION ---

@app.post("/book")
async def create_booking(data: dict, db: Session = Depends(get_db)):
    try:
        # Standardize ISO timestamps from Flutter
        start_str = data.get("start_time").replace("Z", "+00:00")
        end_str = data.get("end_time").replace("Z", "+00:00")
        
        new_booking = models.Booking(
            user_id=data.get("user_id"),
            room_id=data.get("room_id"),
            purpose=data.get("purpose"),
            student_count=data.get("student_count", 1),
            start_time=datetime.fromisoformat(start_str),
            end_time=datetime.fromisoformat(end_str),
            # Uses the status sent by the app (AUTO-APPROVED or PENDING)
            status=data.get("status", "PENDING"),
            qr_code_token=f"RES-{uuid.uuid4().hex[:6].upper()}"
        )
        db.add(new_booking)
        db.commit()
        return {"status": "success"}
    except Exception as e:
        print(f"BOOKING CRASH: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/admin/bookings")
def get_all_bookings(db: Session = Depends(get_db)):
    try:
        bookings = db.query(models.Booking).all()
        results = []
        for b in bookings:
            results.append({
                "id": b.id,
                "user_id": b.user_id,
                "user_name": b.user.full_name if b.user else "Unknown User",
                "room_name": b.room.name if b.room else "Unknown",
                "room_capacity": b.room.capacity if b.room else 0,
                "location": b.room.location if b.room else "FACILITY",
                "student_count": b.student_count,
                "status": b.status,
                "purpose": b.purpose
            })
        return results
    except Exception as e:
        print(f"CRITICAL ERROR: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- 4. STATUS & CHECK-IN ---

@app.put("/bookings/{booking_id}")
def update_booking_status(booking_id: int, update: dict, db: Session = Depends(get_db)):
    booking = db.query(models.Booking).filter(models.Booking.id == booking_id).first()
    if booking:
        booking.status = update.get("status")
        db.commit()
        return {"status": "updated"}
    raise HTTPException(status_code=404, detail="Booking not found")

@app.post("/checkin")
def check_in(data: dict, db: Session = Depends(get_db)):
    user_id = data.get("user_id")
    room_id = data.get("room_id")
    
    # Validates that an approved reservation exists before allowing check-in
    booking = db.query(models.Booking).filter(
        models.Booking.user_id == user_id,
        models.Booking.room_id == room_id,
        models.Booking.status == "APPROVED"
    ).first()

    if not booking:
        raise HTTPException(status_code=400, detail="No approved reservation found.")

    booking.status = "CHECKED_IN"
    db.commit()
    return {"status": "success"}