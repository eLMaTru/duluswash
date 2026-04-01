import { Router, Request, Response } from 'express';
import { verifyToken } from '../firebase';
import { query } from '../db';

const router = Router();

// POST /api/v1/auth/me — upsert user on login, returns profile + role
router.post('/me', async (req: Request, res: Response) => {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Token requerido' });
  }

  try {
    const token = authHeader.split('Bearer ')[1];
    const decoded = await verifyToken(token);

    const { uid, email, name } = decoded;
    const displayName = name || (email?.split('@')[0] ?? '');

    // Upsert — crea el usuario si no existe, role default = customer
    const rows = await query(
      `INSERT INTO users (firebase_uid, email, name)
       VALUES ($1, $2, $3)
       ON CONFLICT (firebase_uid) DO UPDATE
         SET email = EXCLUDED.email,
             name  = CASE WHEN users.name = '' THEN EXCLUDED.name ELSE users.name END,
             updated_at = NOW()
       RETURNING id, email, name, role`,
      [uid, email ?? '', displayName]
    );

    const user = rows[0];
    return res.json({ user });
  } catch (err) {
    console.error(err);
    return res.status(401).json({ error: 'Token inválido' });
  }
});

export default router;
