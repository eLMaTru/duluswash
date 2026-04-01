import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
  max: 1, // Lambda: keep pool small
});

export async function query<T = any>(sql: string, params?: any[]): Promise<T[]> {
  const result = await pool.query(sql, params);
  return result.rows;
}

export async function migrate(): Promise<void> {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      firebase_uid VARCHAR(128) UNIQUE NOT NULL,
      email        VARCHAR(255) NOT NULL,
      name         VARCHAR(255) NOT NULL DEFAULT '',
      role         VARCHAR(20)  NOT NULL DEFAULT 'customer'
                   CHECK (role IN ('customer', 'operator', 'admin')),
      phone        VARCHAR(30),
      created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS bookings (
      id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      customer_id  UUID NOT NULL REFERENCES users(id),
      operator_id  UUID REFERENCES users(id),
      service_id   VARCHAR(50) NOT NULL,
      service_name VARCHAR(100) NOT NULL,
      vehicle_type VARCHAR(30) NOT NULL,
      address      TEXT NOT NULL,
      lat          NUMERIC(10, 7) NOT NULL,
      lng          NUMERIC(10, 7) NOT NULL,
      status       VARCHAR(20) NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending','accepted','in_progress','completed','cancelled')),
      total_price  NUMERIC(10, 2) NOT NULL,
      created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_bookings_status     ON bookings(status);
    CREATE INDEX IF NOT EXISTS idx_bookings_customer   ON bookings(customer_id);
    CREATE INDEX IF NOT EXISTS idx_bookings_operator   ON bookings(operator_id);
    CREATE INDEX IF NOT EXISTS idx_users_firebase_uid  ON users(firebase_uid);
  `);
}
