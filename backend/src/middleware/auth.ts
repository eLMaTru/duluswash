import { Request, Response, NextFunction } from 'express';
import { verifyToken } from '../firebase';
import { query } from '../db';

export interface AuthRequest extends Request {
  user?: {
    id: string;
    firebaseUid: string;
    email: string;
    name: string;
    role: string;
  };
}

export async function requireAuth(req: AuthRequest, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Token requerido' });
  }

  try {
    const token = authHeader.split('Bearer ')[1];
    const decoded = await verifyToken(token);

    const rows = await query(
      'SELECT id, firebase_uid, email, name, role FROM users WHERE firebase_uid = $1',
      [decoded.uid]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    req.user = {
      id: rows[0].id,
      firebaseUid: rows[0].firebase_uid,
      email: rows[0].email,
      name: rows[0].name,
      role: rows[0].role,
    };

    next();
  } catch (err) {
    return res.status(401).json({ error: 'Token inválido' });
  }
}

export function requireRole(...roles: string[]) {
  return (req: AuthRequest, res: Response, next: NextFunction) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Sin permisos' });
    }
    next();
  };
}
