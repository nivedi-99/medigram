import express from 'express';
import { admin } from '../config.js';
import { ApiError, errors, mapDbError } from '../errors.js';
import { requireAuth } from '../middleware/auth.js';
import { requireRole } from '../middleware/role.js';

const router = express.Router();
router.use(requireAuth);

/**
 * Storage bucket for product photos — created by
 * supabase/add_product_images.sql (or scripts/apply-product-images.mjs).
 */
const BUCKET = 'product-images';

/** 5 MB ceiling — generous for a product photo, small enough for memory. */
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

/** Only real image formats are accepted. */
const ALLOWED_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
]);

/** Extracts the storage path from a public URL of the bucket (or null). */
const pathFromPublicUrl = (url) => {
  const marker = `/object/public/${BUCKET}/`;
  const at = url.indexOf(marker);
  if (at === -1) return null;
  const path = url.slice(at + marker.length);
  return path.startsWith('products/') && path.includes('.') ? path : null;
};

/**
 * P7+ · PRODUCT PHOTOS — POST /api/v1/uploads/product-image (admin).
 *
 * The body is the raw image bytes (express.raw — no multipart dependency);
 * the request Content-Type is the image's real MIME type and `x-filename`
 * names the original file. The API writes the object into the public
 * `product-images` bucket and answers with its permanent public URL:
 *
 *   { "data": { "url": "https://…/storage/v1/object/public/product-images/products/…" } }
 */
router.post(
  '/product-image',
  requireRole('admin'),
  express.raw({ type: 'image/*', limit: MAX_IMAGE_BYTES }),
  async (req, res, next) => {
    try {
      const contentType = String(req.get('content-type') ?? '')
        .split(';')[0]
        .trim()
        .toLowerCase();

      if (!ALLOWED_TYPES.has(contentType)) {
        return next(errors.badRequest(
          `Unsupported image type "${contentType || 'unknown'}" — use PNG, JPEG, WebP or GIF.`,
        ));
      }
      if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
        return next(errors.badRequest('Empty upload — send the raw image bytes.'));
      }

      // products/<timestamp>-<rand><extension> — no user text in the path.
      const ext = contentType === 'image/jpeg'
        ? '.jpg'
        : `.${contentType.split('/')[1]}`;
      const objectPath = `products/${Date.now()}-${
        Math.random().toString(36).slice(2, 8)}${ext}`;

      const { error } = await admin.storage
        .from(BUCKET)
        .upload(objectPath, req.body, { contentType, upsert: false });
      if (error) {
        return next(new ApiError(502, 'STORAGE_UPLOAD_FAILED', error.message));
      }

      const { data } = admin.storage.from(BUCKET).getPublicUrl(objectPath);
      res.status(201).json({ data: { url: data.publicUrl } });
    } catch (err) {
      next(err);
    }
  },
);

/**
 * DELETE /api/v1/uploads/product-image?url=<public url> (admin).
 * Best-effort cleanup when an admin removes/replaces a product photo — the
 * catalogue row is cleared separately via PATCH /products/:id. Unknown or
 * foreign URLs answer 200 without touching storage so removal always
 * "succeeds" from the caller's point of view.
 */
router.delete('/product-image', requireRole('admin'), async (req, res, next) => {
  try {
    const url = String(req.query.url ?? '');
    const path = pathFromPublicUrl(url);
    if (path) {
      await admin.storage.from(BUCKET).remove([path]);
    }
    res.json({ data: { deleted: path != null } });
  } catch (err) {
    next(err);
  }
});

export default router;
