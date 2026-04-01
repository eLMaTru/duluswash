import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { migrate } from './db';
import authRoutes from './routes/auth';
import usersRoutes from './routes/users';

const app = express();

app.use(cors());
app.use(express.json());

app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/users', usersRoutes);

app.get('/health', (_, res) => res.json({ status: 'ok' }));

const PORT = process.env.PORT || 3000;

migrate()
  .then(() => {
    app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
  })
  .catch((err) => {
    console.error('Migration failed:', err);
    process.exit(1);
  });

export default app;
