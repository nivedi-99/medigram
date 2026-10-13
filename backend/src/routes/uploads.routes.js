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

/** Storage bucket for buyer payment screenshots — created by
 * supabase/add_payment_proofs.sql. */
const PROOF_BUCKET = 'payment-proofs';

/** 5 MB ceiling — generous for a product photo, small enough for memory. */
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

/** 8 MB ceiling for payment screenshots (phone photos run large). */
const MAX_PROOF_BYTES = 8 * 1024 * 1024;

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
  return path.startsWith('products/') && path.length > 'products/'.length
    ? path
    : null;
};

/** Public URL for a storage path of the bucket. */
const publicUrlFor = (path) =>
  admin.storage.from(BUCKET).getPublicUrl(path).data.publicUrl;

/** Public URL for a stored payment screenshot. */
const proofPublicUrlFor = (path) =>
  admin.storage.from(PROOF_BUCKET).getPublicUrl(path).data.publicUrl;

/**
 * Ensures the payment-proofs bucket exists (self-healing on cold start so a
 * fresh Supabase project works without running the SQL first). Cached per
 * process; retried on the next upload if provisioning fails.
 */
let proofBucketReady = null;
const ensureProofBucket = async () => {
  if (!proofBucketReady) {
    proofBucketReady = (async () => {
      const { data: bucket } = await admin.storage.getBucket(PROOF_BUCKET);
      if (!bucket) {
        const { error } = await admin.storage
          .createBucket(PROOF_BUCKET, { public: true });
        if (error && !/already exists/i.test(error.message)) throw error;
      } else if (!bucket.public) {
        await admin.storage.updateBucket(PROOF_BUCKET, { public: true });
      }
    })().catch((err) => {
      proofBucketReady = null; // allow a retry on the next upload
      throw err;
    });
  }
  return proofBucketReady;
};

/** Storage path for a buyer's payment screenshot (unique per upload). */
const proofPathFor = (userId, mime) => {
  const extByType = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'image/gif': 'gif',
  };
  const ext = extByType[mime] ?? 'png';
  const stamp = new Date().toISOString().replace(/[^0-9]/g, '').slice(0, 14);
  const rand = Math.random().toString(36).slice(2, 8);
  return `proofs/${userId}/${stamp}-${rand}.${ext}`;
};

/**
 * P7+ · PRODUCT PHOTOS — POST /api/v1/uploads/product-image (admin).
 *
 * The body is the raw image bytes (express.raw — no multipart dependency);
 * the request Content-Type is the image's real MIME type, `x-filename`
 * names the original file and `x-product-id` pins the photo to its product:
 * every photo is stored at the canonical path `products/<productId>`
 * (upsert — replacing a photo overwrites the same object), so the catalogue
 * always resolves the photo even while the products.image_url column is not
 * applied yet. Answers with the permanent public URL:
 *
 *   { "data": { "url": "https://…/object/public/product-images/products/<id>" } }
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
      const productId = String(req.get('x-product-id') ?? '').trim();

      if (!ALLOWED_TYPES.has(contentType)) {
        return next(errors.badRequest(
          `Unsupported image type "${contentType || 'unknown'}" — use PNG, JPEG, WebP or GIF.`,
        ));
      }
      if (!/^[0-9a-f-]{36}$/i.test(productId)) {
        return next(errors.badRequest('Send the product id in x-product-id.'));
      }
      if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
        return next(errors.badRequest('Empty upload — send the raw image bytes.'));
      }

      // Canonical path: one stable photo per product (upsert overwrites the
      // previous photo in place). Short cache so replaced photos propagate
      // to buyers within a minute.
      const objectPath = `products/${productId}`;

      const { error } = await admin.storage
        .from(BUCKET)
        .upload(objectPath, req.body, {
          contentType,
          upsert: true,
          cacheControl: '60',
        });
      if (error) {
        return next(new ApiError(502, 'STORAGE_UPLOAD_FAILED', error.message));
      }

      res.status(201).json({ data: { url: publicUrlFor(objectPath) } });
    } catch (err) {
      next(err);
    }
  },
);

/**
 * PAYMENT PROOFS — POST /api/v1/uploads/payment-proof (any signed-in user).
 *
 * Same raw-body protocol as product-image: the body is the screenshot bytes
 * (Content-Type = the image's real MIME type), `x-filename` names the
 * original file. Every upload is stored under the buyer's own folder
 * `proofs/<userId>/<timestamp>-<rand>.<ext>` so proofs are kept per buyer
 * and never overwrite each other. Answers with the permanent public URL:
 *
 *   { "data": { "url": "https://…/object/public/payment-proofs/proofs/…" } }
 */
router.post(
  '/payment-proof',
  express.raw({ type: 'image/*', limit: MAX_PROOF_BYTES }),
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

      const objectPath = proofPathFor(req.user.id, contentType);

      // Optional payment metadata sent by the client (headers keep the
      // raw-body protocol unchanged).
      const amountHeader = String(req.get('x-amount') ?? '').trim();
      const reference =
        String(req.get('x-reference') ?? '').trim().slice(0, 120);
      const orderId = String(req.get('x-order-id') ?? '').trim();
      const amountInr =
        amountHeader === '' ? NaN : Number.parseFloat(amountHeader);

      await ensureProofBucket();

      const { error } = await admin.storage
        .from(PROOF_BUCKET)
        .upload(objectPath, req.body, {
          contentType,
          upsert: false,
        });
      if (error) {
        return next(new ApiError(502, 'STORAGE_UPLOAD_FAILED', error.message));
      }

      const url = proofPublicUrlFor(objectPath);

      // Persist the payment record (best-effort — the screenshot itself is
      // already stored, so a table hiccup must not fail the upload).
      let record = null;
      try {
        const { data, error: dbError } = await admin
          .from('payment_proofs')
          .insert({
            user_id: req.user.id,
            url,
            amount_inr: Number.isFinite(amountInr) && amountInr > 0 ? amountInr : null,
            reference,
            order_id: /^[0-9a-f-]{36}$/i.test(orderId) ? orderId : null,
          })
          .select('id, status, created_at')
          .single();
        if (!dbError) {
          record = data;
        } else {
          console.error('[uploads] payment_proofs insert failed:', dbError.message);
        }
      } catch (dbErr) {
        console.error('[uploads] payment_proofs insert threw:', dbErr.message);
      }

      res.status(201).json({ data: { url, record } });
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
