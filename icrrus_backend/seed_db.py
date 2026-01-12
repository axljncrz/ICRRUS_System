import models, database
from database import SessionLocal, engine

# This line is CRITICAL: It tells SQLAlchemy to update the 
# physical PostgreSQL tables based on your new models.py
models.Base.metadata.drop_all(bind=engine) # Wipes old tables
models.Base.metadata.create_all(bind=engine) # Creates new tables with student_count

def seed():
    db = SessionLocal()
    
    # 1. ADD USERS
    users = [
        models.User(full_name="Peter Parker", email="student@itso.edu", role="STUDENT", school_id="2021-10001"),
        models.User(full_name="Wanda Maximoff", email="librarian@itso.edu", role="LIBRARIAN", school_id="LIB-9001"),
    ]

    # 2. ADD ROOMS
    rooms = [
        models.Room(name="Library Discussion Room A", capacity=6, status="AVAILABLE"),
        models.Room(name="IT Computer Lab 102", capacity=40, status="AVAILABLE"),
    ]

    try:
        db.add_all(users)
        db.add_all(rooms)
        db.commit()
        
        # 3. ADD A TEST BOOKING (Testing the new columns)
        test_booking = models.Booking(
            user_id=1,
            room_id=1,
            purpose="Initial Seed Test",
            student_count=5, # This is the field causing your error
            status="APPROVED",
            qr_code_token="SEED-TEST-001"
        )
        db.add(test_booking)
        db.commit()
        print("SUCCESS: Database wiped and seeded with new columns!")
    except Exception as e:
        db.rollback()
        print(f"SEEDING ERROR: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed()