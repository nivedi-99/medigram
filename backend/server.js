import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';

import { env, corsOrigins, admin } from './src/config.js';
import { ApiError, errorHandler } from './src/errors.js';

import authRoutes from './src/routes/auth.routes.js';
import profileRoutes from './src/routes/profile.routes.js';
import clientsRoutes from './src/routes/clients.routes.js';
import adminsRoutes from './src/routes/admins.routes.js';
import productsRoutes from './src/routes/products.routes.js';
import ordersRoutes from './src/routes/orders.routes.js';
import notificationsRoutes from './src/routes/notifications.routes.js';
import reportsRoutes from './src/routes/reports.routes.js';

const app = express();

app.set('trust proxy', 1); // Railway terminates TLS in front of the app
app.use(helmet());
app.use(
  cors({
    origin(origin, cb) {
      // Allow server-to-server tools (no Origin header) and allow-listed apps.
      if (!origin || corsOrigins.length === 0 || corsOrigins.includes(origin)) return cb(null, true);
      return cb(new ApiError(403, 'CORS_NOT_ALLOWED', `Origin ${origin} is not allowed by CORS`));
    },
    credentials: false,
  }),
);
app.use(express.json({ limit: '128kb' }));
app.use(morgan(env.NODE_ENV === 'production' ? 'combined' : 'tiny'));

const authLimiter = rateLimit({ windowMs: 15 * 60 * 1000, limit: 100, standardHeaders: true });
const apiLimiter = rateLimit({ windowMs: 15 * 60 * 1000, limit: 300, standardHeaders: true });

const v1 = express.Router();
v1.get('/health', async (_req, res) => {
  try {
    const { error } = await admin.from('profiles').select('id').limit(1);
    if (error) throw error;
    res.json({ status: 'ok', db: 'up', time: new Date().toISOString() });
  } catch {
    res.status(503).json({ status: 'degraded', db: 'down' });
  }
});

v1.use('/auth', authLimiter, authRoutes);
v1.use('/profile', apiLimiter, profileRoutes);
v1.use('/clients', apiLimiter, clientsRoutes);
v1.use('/admins', apiLimiter, adminsRoutes);
v1.use('/products', apiLimiter, productsRoutes);
v1.use('/orders', apiLimiter, ordersRoutes);
v1.use('/notifications', apiLimiter, notificationsRoutes);
v1.use('/reports', apiLimiter, reportsRoutes);

app.use('/api/v1', v1);

app.use((_req, res) => res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Unknown endpoint' } }));
app.use(errorHandler);

app.listen(env.PORT, () => {
  console.log(`[medigram-api] listening on :${env.PORT} (${env.NODE_ENV})`);
  console.log(`[medigram-api] CORS origins: ${corsOrigins.join(', ') || '(any — dev mode)'}`);
});

export default app;
