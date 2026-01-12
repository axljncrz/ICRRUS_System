from database import engine, Base
import models

def recreate_database():
    print("Connecting to PostgreSQL...")
    # This drops all existing tables
    Base.metadata.drop_all(bind=engine)
    print("Old tables dropped.")
    
    # This creates new tables with 'description', 'equipment', and 'is_faculty_only'
    Base.metadata.create_all(bind=engine)
    print("Database synchronized with new columns successfully!")

if __name__ == "__main__":
    recreate_database()