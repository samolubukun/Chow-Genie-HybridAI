import os
import json
import sqlite3
from datetime import datetime, timedelta

def create_recipes_db():
    recipes_dir = os.path.join("assets", "recipes")
    db_path = os.path.join("assets", "recipes.db")

    # Delete existing database file if it exists to start fresh
    if os.path.exists(db_path):
        os.remove(db_path)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Create the complete set of database tables matching LocalDbService._createTables
    cursor.execute('''
        CREATE TABLE recipes (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            ingredients TEXT NOT NULL,
            directions TEXT NOT NULL,
            tags TEXT,
            source TEXT,
            url TEXT,
            imagePath TEXT,
            calories REAL,
            cookingTimeMinutes INTEGER,
            spiceLevel INTEGER,
            difficulty TEXT,
            dietaryTags TEXT,
            isFavorite INTEGER DEFAULT 0,
            isUserGenerated INTEGER DEFAULT 0,
            createdAt TEXT NOT NULL
        )
    ''')
    cursor.execute('''
        CREATE TABLE pantry_items (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            quantity REAL NOT NULL,
            unit TEXT NOT NULL,
            expiryDate TEXT,
            price REAL,
            category TEXT,
            notes TEXT,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
        )
    ''')
    cursor.execute('''
        CREATE TABLE shopping_items (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            quantity REAL NOT NULL,
            unit TEXT NOT NULL,
            isChecked INTEGER DEFAULT 0,
            source TEXT,
            sourceRecipeId TEXT,
            category TEXT,
            estimatedPrice REAL,
            createdAt TEXT NOT NULL
        )
    ''')
    cursor.execute('''
        CREATE TABLE meal_plan_entries (
            id TEXT PRIMARY KEY,
            recipeId TEXT NOT NULL,
            recipeTitle TEXT NOT NULL,
            mealType TEXT NOT NULL,
            date TEXT NOT NULL,
            servings INTEGER DEFAULT 1,
            estimatedCalories REAL,
            isPrepped INTEGER DEFAULT 0
        )
    ''')
    cursor.execute('''
        CREATE TABLE weekly_plans (
            id TEXT PRIMARY KEY,
            weekStart TEXT NOT NULL,
            notes TEXT,
            createdAt TEXT NOT NULL
        )
    ''')
    cursor.execute('''
        CREATE TABLE mesh_peers (
            id TEXT PRIMARY KEY,
            displayName TEXT NOT NULL,
            deviceId TEXT,
            connectionMethod TEXT,
            isOnline INTEGER DEFAULT 0,
            lastSeen TEXT NOT NULL,
            publicKey TEXT
        )
    ''')
    cursor.execute('''
        CREATE TABLE mesh_messages (
            id TEXT PRIMARY KEY,
            senderId TEXT NOT NULL,
            senderName TEXT NOT NULL,
            receiverId TEXT,
            groupId TEXT,
            messageType TEXT,
            content TEXT NOT NULL,
            attachmentPath TEXT,
            recipeJson TEXT,
            timestamp TEXT NOT NULL,
            isRead INTEGER DEFAULT 0,
            isDelivered INTEGER DEFAULT 0,
            isRelayed INTEGER DEFAULT 0,
            replyToId TEXT
        )
    ''')
    cursor.execute('''
        CREATE TABLE mesh_groups (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            creatorId TEXT NOT NULL,
            memberIds TEXT,
            createdAt TEXT NOT NULL,
            inviteCode TEXT
        )
    ''')
    cursor.execute('''
        CREATE TABLE nutrition_log (
            id TEXT PRIMARY KEY,
            recipeId TEXT,
            recipeTitle TEXT,
            date TEXT NOT NULL,
            calories REAL,
            protein REAL,
            carbs REAL,
            fat REAL,
            fiber REAL,
            mealType TEXT,
            imagePath TEXT,
            notes TEXT
        )
    ''')

    # Create all database indexes
    cursor.execute('CREATE INDEX idx_recipes_title ON recipes(title)')
    cursor.execute('CREATE INDEX idx_recipes_tags ON recipes(tags)')
    cursor.execute('CREATE INDEX idx_pantry_name ON pantry_items(name)')
    cursor.execute('CREATE INDEX idx_meal_plan_date ON meal_plan_entries(date)')
    cursor.execute('CREATE INDEX idx_nutrition_log_date ON nutrition_log(date)')

    print("Scanning recipe directories...")
    
    count = 0
    subdirs = [d for d in os.listdir(recipes_dir) if os.path.isdir(os.path.join(recipes_dir, d))]
    created_at = (datetime.now() - timedelta(days=365)).isoformat()

    for subdir in subdirs:
        subdir_path = os.path.join(recipes_dir, subdir)
        for filename in os.listdir(subdir_path):
            if filename.endswith(".json"):
                file_path = os.path.join(subdir_path, filename)
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        data = json.load(f)
                    
                    recipe_id = filename[:-5]
                    title = data.get("title", "Untitled")
                    
                    ingredients_json = json.dumps(data.get("ingredients", []))
                    directions_json = json.dumps(data.get("directions", []))
                    tags_json = json.dumps(data.get("tags", []))
                    
                    source = data.get("source", "")
                    url = data.get("url", "")
                    
                    cursor.execute('''
                        INSERT INTO recipes (
                            id, title, ingredients, directions, tags, source, url, 
                            isFavorite, isUserGenerated, createdAt
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0, ?)
                    ''', (recipe_id, title, ingredients_json, directions_json, tags_json, source, url, created_at))
                    
                    count += 1
                except Exception as e:
                    print(f"Error parsing {file_path}: {e}")

    conn.commit()
    conn.close()
    
    db_size_mb = os.path.getsize(db_path) / (1024 * 1024)
    print(f"Successfully compiled {count} recipes with full schema tables into {db_path} ({db_size_mb:.2f} MB)")

if __name__ == "__main__":
    create_recipes_db()
