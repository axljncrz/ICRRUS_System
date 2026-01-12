import qrcode # You may need to run: pip install qrcode[pil]

def generate_room_qr(room_id, room_name):
    # The scanner expects the raw Room ID as a string
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(str(room_id)) 
    qr.make(fit=True)

    img = qr.make_image(fill_color="black", back_color="white")
    
    # Saves the image as 'room_1_library.png', etc.
    file_name = f"room_{room_id}_{room_name.replace(' ', '_').lower()}.png"
    img.save(file_name)
    print(f"Generated QR for {room_name} (ID: {room_id}) -> {file_name}")

# --- SETUP YOUR ROOMS HERE ---
# Match these IDs to your PostgreSQL 'rooms' table
rooms_to_generate = [
    {"id": 1, "name": "Main Library Quiet Zone"},
    {"id": 2, "name": "IT Lab 102"},
    {"id": 3, "name": "Audio Visual Room"},
]

for room in rooms_to_generate:
    generate_room_qr(room["id"], room["name"])