-- ============================================================
-- المكسيكي — Initial database schema for Cloudflare D1
-- Run with: wrangler d1 migrations apply almexiky-db
-- ============================================================

CREATE TABLE IF NOT EXISTS users (
  id            TEXT PRIMARY KEY,           -- uuid
  name          TEXT NOT NULL,
  email         TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,              -- PBKDF2 hash
  password_salt TEXT NOT NULL,              -- random salt (hex)
  phone         TEXT,
  role          TEXT NOT NULL DEFAULT 'customer',  -- 'customer' | 'admin'
  reset_token        TEXT,                  -- hashed reset token (nullable)
  reset_token_expires INTEGER,              -- unix ms (nullable)
  created_at    INTEGER NOT NULL,           -- unix ms
  updated_at    INTEGER NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email);

CREATE TABLE IF NOT EXISTS sessions (
  id            TEXT PRIMARY KEY,           -- uuid, stored in the cookie
  user_id       TEXT NOT NULL,
  created_at    INTEGER NOT NULL,
  expires_at    INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);

CREATE TABLE IF NOT EXISTS menu_items (
  id            TEXT PRIMARY KEY,           -- uuid
  name          TEXT NOT NULL,
  description   TEXT,
  price         REAL NOT NULL,
  image         TEXT,
  category      TEXT NOT NULL,              -- tacos | burritos | quesadillas | nachos | drinks ...
  available     INTEGER NOT NULL DEFAULT 1, -- 1 = true, 0 = false
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_menu_category ON menu_items(category);

CREATE TABLE IF NOT EXISTS orders (
  id                TEXT PRIMARY KEY,        -- uuid, shown to customer as order id
  user_id           TEXT,                    -- nullable: guest checkout allowed
  customer_name     TEXT NOT NULL,
  customer_phone    TEXT NOT NULL,
  delivery_address  TEXT NOT NULL,
  delivery_zone     TEXT,
  delivery_fee      REAL NOT NULL DEFAULT 0,
  subtotal          REAL NOT NULL,
  discount          REAL NOT NULL DEFAULT 0,
  total_price       REAL NOT NULL,
  payment_method    TEXT NOT NULL DEFAULT 'cash',   -- 'vodafone_cash' | 'cash'
  status            TEXT NOT NULL DEFAULT 'pending', -- see status list below
  notes             TEXT,
  created_at        INTEGER NOT NULL,
  updated_at        INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);
-- valid statuses: pending, confirmed, preparing, ready, out_for_delivery, delivered, cancelled

CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);

CREATE TABLE IF NOT EXISTS order_items (
  id            TEXT PRIMARY KEY,           -- uuid
  order_id      TEXT NOT NULL,
  menu_item_id  TEXT,                       -- nullable: item may have been deleted since
  item_name     TEXT NOT NULL,              -- snapshot of name at order time
  quantity      INTEGER NOT NULL,
  price         REAL NOT NULL,              -- unit price at order time (incl. addons)
  options       TEXT,                       -- JSON string: {spice, addons: [...]}
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  FOREIGN KEY (menu_item_id) REFERENCES menu_items(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);

-- ============================================================
-- Seed the existing menu (matches what was hardcoded in index.html)
-- Safe to re-run: uses INSERT OR IGNORE with fixed ids.
-- ============================================================
INSERT OR IGNORE INTO menu_items (id, name, description, price, image, category, available, created_at, updated_at) VALUES
('t1','تاكو لحم بالتتبيلة المكسيكية','لحم بقري متبل، بصل، كزبرة، وصوص حار',85,'images/taco-beef.jpg','tacos',1,strftime('%s','now')*1000,strftime('%s','now')*1000),
('t2','تاكو فراخ مشوي بالفلفل','فراخ مشوية على الفحم مع فلفل ملون',75,'images/taco-chicken.jpg','tacos',1,strftime('%s','now')*1000,strftime('%s','now')*1000),
('t3','تاكو جمبري بالصويا واللايم','جمبري متبل بالليمون والصويا',95,'images/taco-shrimp.jpg','tacos',1,strftime('%s','now')*1000,strftime('%s','now')*1000),
('t4','تاكو خضار وجبنة','خضار مشوية مع جبنة مكسيكية ذايبة',65,'images/taco-veg.jpg','tacos',1,strftime('%s','now')*1000,strftime('%s','now')*1000),
('b1','بوريتو لحم بالفاصوليا السوداء','لحم، أرز، فاصوليا سوداء، وصوص',120,'images/burrito-beef.jpg','burritos',1,strftime('%s','now')*1000,strftime('%s','now')*1000),
('b2','بوريتو فراخ بالجبنة والصوص الحار','فراخ متبلة مع جبنة وصوص حار مميز',110,'images/burrito-chicken.jpg','burritos',1,strftime('%s','now')*1000,strftime('%s','now')*1000),
('b3','بوريتو نباتي بالأفوكادو','خضار وأفوكادو وأرز مكسيكي',95,'images/burrito-veg.jpg','burritos',1,strftime('%s','now')*1000,strftime('%s','now')*1000),
('q1','كيساديا جبنة كلاسيك','جبنة مكسيكية ذايبة بين طبقتين عيش رقيق',70,'images/quesadilla-cheese.jpg','quesadillas',1,strftime('%s','now')*1000,strftime('%s','now')*1000),
('q2','كيساديا لحم مفروم وفلفل','لحم مفروم متبل مع فلفل وجبنة',90,'images/quesadilla-meat.jpg','quesadillas',1,strftime('%s','now')*1000,strftime('%s','now')*1000),
('q3','كيساديا فراخ وذرة','فراخ مشوية مع ذرة وجبنة',85,'images/quesadilla-chicken.jpg','quesadillas',1,strftime('%s','now')*1000,strftime('%s','now')*1000),
('n1','ناتشوز جبنة وجواكامولي','تشيبس ذرة مقرمشة مع جبنة وصوص جواكامولي',80,'images/nachos.jpg','nachos',1,strftime('%s','now')*1000,strftime('%s','now')*1000),
('n2','سلطة مكسيكية','فاصوليا، ذرة، طماطم، وصوص ليمون',60,'images/salad.jpg','nachos',1,strftime('%s','now')*1000,strftime('%s','now')*1000),
('n3','صوص جواكامولي مع تشيبس','أفوكادو طازة مهروس مع بهارات مكسيكية',55,'images/guac.jpg','nachos',1,strftime('%s','now')*1000,strftime('%s','now')*1000),
('d1','ليموناضة بالنعناع','ليمون طازة ونعناع مثلج',30,'images/lemonade.jpg','drinks',1,strftime('%s','now')*1000,strftime('%s','now')*1000),
('d2','عصير مانجو طازة','مانجو طبيعي 100%',35,'images/mango.jpg','drinks',1,strftime('%s','now')*1000,strftime('%s','now')*1000),
('d3','مياه غازية','مشروبات غازية متنوعة',20,'images/soda.jpg','drinks',1,strftime('%s','now')*1000,strftime('%s','now')*1000);
