import { Router, Response } from 'express';
import { requireAuth, requireRole, AuthRequest } from '../middleware/auth';
import { query } from '../db';

const router = Router();

// GET /api/v1/users — admin: list all users
router.get('/', requireAuth, requireRole('admin'), async (req: AuthRequest, res: Response) => {
  const rows = await query(
    'SELECT id, email, name, role, phone, created_at FROM users ORDER BY created_at DESC'
  );
  return res.json({ users: rows });
});

// PATCH /api/v1/users/:id/role — admin: change role
router.patch('/:id/role', requireAuth, requireRole('admin'), async (req: AuthRequest, res: Response) => {
  const { id } = req.params;
  const { role } = req.body;

  const validRoles = ['customer', 'operator', 'admin'];
  if (!validRoles.includes(role)) {
    return res.status(400).json({ error: 'Rol inválido' });
  }

  const rows = await query(
    'UPDATE users SET role = $1, updated_at = NOW() WHERE id = $2 RETURNING id, email, name, role',
    [role, id]
  );

  if (rows.length === 0) return res.status(404).json({ error: 'Usuario no encontrado' });
  return res.json({ user: rows[0] });
});

export default router;
