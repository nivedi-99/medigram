import { Router } from 'express';
import { z } from 'zod';
import { admin } from '../config.js';
import { requireAuth } from '../middleware/auth.js';
import { requireRole } from '../middleware/role.js';
import { validate } from '../middleware/validate.js';
import { errors } from '../errors.js';

const router = Router();
router.use(requireAuth);

const DEFAULTS = {
  whatsappNumber: '+91 90000 00000',
  fx: {
    USD: 1,
    EUR: 0.92,
    GBP: 0.79,
    INR: 83.5,
    BTC: 0.0000152,
    ETH: 0.00019,
    USDT: 1,
  },
  methods: [
    {
      key: 'wire_transfer',
      label: 'International Wire Transfer (SWIFT)',
      tagline: 'Bank-to-bank remittance to our Indian account',
      sortOrder: 10,
      active: true,
      details: {
        Beneficiary: 'MediGram Exports Pvt. Ltd.',
        Bank: 'PLACEHOLDER BANK, MUMBAI',
        'Account No': 'XXXXXXXXXXXXXX',
        IFSC: 'XXXX0000000',
        'SWIFT / BIC': 'XXXXINBBXXX',
        Country: 'India',
      },
      instructions:
        'Remit the invoice total in USD or EUR. Your bank converts to INR at '
          + 'the prevailing rate on credit. Email the SWIFT copy with your '
          + 'order number as the payment reference.',
    },
    {
      key: 'western_union',
      label: 'Western Union',
      tagline: 'Cash pickup / bank deposit to India',
      sortOrder: 20,
      active: true,
      details: {
        'Receiver Name': 'PLACEHOLDER RECEIVER',
        City: 'Mumbai',
        Country: 'India',
        Phone: '+91 90000 00000',
      },
      instructions:
        'Send the INR-equivalent amount via Western Union to the receiver '
          + 'above. Share the 10-digit MTCN, sender name and amount as your '
          + 'payment reference.',
    },
    {
      key: 'remitly',
      label: 'Remitly',
      tagline: 'Fast online remittance to Indian banks',
      sortOrder: 30,
      active: true,
      details: {
        Recipient: 'MediGram Exports Pvt. Ltd.',
        City: 'Mumbai',
        Country: 'India',
        'Account Type': 'Bank deposit (INR)',
      },
      instructions:
        'Add our beneficiary details in Remitly and send the INR-equivalent '
          + 'amount. Use your MediGram order number as the remittance '
          + 'reference and share the transaction ID.',
    },
    {
      key: 'moneygram',
      label: 'MoneyGram',
      tagline: 'Global money transfer to India',
      sortOrder: 40,
      active: true,
      details: {
        'Receiver Name': 'PLACEHOLDER RECEIVER',
        City: 'Mumbai',
        Country: 'India',
      },
      instructions:
        'Send the INR-equivalent amount via MoneyGram. Provide the 8-digit '
          + 'reference number, sender name and amount as your payment '
          + 'reference.',
    },
    {
      key: 'wise',
      label: 'Wise (TransferWise)',
      tagline: 'Low-fee transfer straight to our INR account',
      sortOrder: 50,
      active: true,
      details: {
        'Account Name': 'MediGram Exports Pvt. Ltd.',
        'Account No': 'XXXXXXXXXXXXXX',
        IFSC: 'XXXX0000000',
        Bank: 'PLACEHOLDER BANK, MUMBAI',
      },
      instructions:
        'Pay in your local currency — Wise converts to INR at the mid-market '
          + 'rate. Use your order number as the transfer reference.',
    },
    {
      key: 'bitcoin',
      label: 'Bitcoin (BTC)',
      tagline: 'On-chain settlement in BTC',
      sortOrder: 60,
      active: true,
      details: {
        'Wallet Address': 'bc1qxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        Network: 'Bitcoin mainnet',
      },
      instructions:
        'Send the BTC equivalent of your invoice at the admin-set rate. Paste '
          + 'the transaction hash (TxID) as your payment reference. '
          + 'Confirmations required: 2.',
    },
    {
      key: 'ethereum',
      label: 'Ethereum (ETH)',
      tagline: 'On-chain settlement in ETH',
      sortOrder: 70,
      active: true,
      details: {
        'Wallet Address': '0xXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
        Network: 'Ethereum mainnet (ERC-20 for tokens)',
      },
      instructions:
        'Send the ETH equivalent of your invoice at the admin-set rate. Paste '
          + 'the transaction hash as your payment reference.',
    },
    {
      key: 'usdt_trc20',
      label: 'USDT (TRC-20)',
      tagline: 'USD-pegged stablecoin settlement',
      sortOrder: 80,
      active: true,
      details: {
        'Wallet Address': 'TXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
        Network: 'TRON (TRC-20)',
      },
      instructions:
        '1 USDT = 1 USD. Send the invoice total in USDT and paste the '
          + 'transaction hash as your payment reference.',
    },
  ],
};

const BUCKET = 'app-config';
const OBJECT = 'payments.json';

/**
 * Global settlement configuration — payment channels that can remit money
 * from anywhere in the world to our Indian accounts, plus the FX table used
 * for regional display pricing and INR settlement previews.
 *
 * Stored as a single JSON document in Supabase Storage (bucket `app-config`),
 * editable by admins without a redeploy. Lazily seeded from defaults.
 */

async function ensureBucket() {
  const { error } = await admin.storage.createBucket(BUCKET, { public: false });
  if (error && !`${error.message}`.toLowerCase().includes('exist')) throw error;
}

async function readConfig() {
  const { data, error } = await admin.storage.from(BUCKET).download(OBJECT);
  if (error || !data) {
    await ensureBucket();
    const seeded = DEFAULTS;
    const { error: upErr } = await admin.storage
      .from(BUCKET)
      .upload(OBJECT, JSON.stringify(seeded), { contentType: 'application/json', upsert: true });
    if (upErr && !`${upErr.message}`.toLowerCase().includes('exist')) throw upErr;
    return seeded;
  }
  const text = await data.text();
  return JSON.parse(text);
}

const configSchema = z.object({
  whatsappNumber: z.string().trim().min(6).max(24),
  fx: z.record(z.string().length(3).regex(/^[A-Z]{3}$/), z.number().positive()),
  methods: z
    .array(
      z.object({
        key: z.string().trim().min(2).max(40),
        label: z.string().trim().min(2).max(120),
        tagline: z.string().trim().max(200).optional().default(''),
        sortOrder: z.number().int().optional().default(0),
        active: z.boolean().optional().default(true),
        details: z.record(z.string(), z.string().max(300)).optional().default({}),
        instructions: z.string().trim().max(1200).optional().default(''),
      }),
    )
    .min(1),
});

/** GET /api/v1/payments — settlement config for clients (active + full FX). */
router.get('/', async (req, res, next) => {
  try {
    const cfg = await readConfig();
    const methods = cfg.methods
      .filter((m) => m.active !== false)
      .sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0));
    res.json({ data: { whatsappNumber: cfg.whatsappNumber, fx: cfg.fx, methods } });
  } catch (err) {
    next(err);
  }
});

/** PUT /api/v1/payments — replace the settlement config (admin). */
router.put('/', requireRole('admin'), validate({ body: configSchema }), async (req, res, next) => {
  try {
    await ensureBucket();
    const { error } = await admin.storage
      .from(BUCKET)
      .upload(OBJECT, JSON.stringify(req.body), { contentType: 'application/json', upsert: true });
    if (error) throw error;
    res.json({ data: req.body });
  } catch (err) {
    next(err);
  }
});

export default router;