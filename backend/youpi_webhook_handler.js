import express from 'express';
import crypto from 'node:crypto';
import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;
const WEBHOOK_SECRET = process.env.YOUPI_WEBHOOK_SECRET || 'safechit_super_secret_key_2026';

// Initialize Supabase Admin Client
const supabaseUrl = process.env.SUPABASE_URL || 'https://sjemdgjcjjozaljhzvzm.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNqZW1kZ2pjampvemFsamh6dnptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcyMjgwMDgsImV4cCI6MjEwMjgwNDAwOH0.EdvMnsMwI0HoX8p55hJE5LfYsYTM5rs4M8ZvoDrDB5A';
const supabase = createClient(supabaseUrl, supabaseKey);

// Preserve raw request body for exact cryptographic HMAC verification
app.use(express.json({
  verify: (req, res, buf) => {
    req.rawBody = buf;
  }
}));

app.get('/health', (req, res) => {
  res.json({
    status: 'ONLINE',
    service: 'SafeChit YouPI Payment Bridge',
    time: new Date().toISOString()
  });
});

/**
 * Authoritative Server-to-Server Webhook Endpoint
 * Header: X-Gateway-Signature: sha256=<64_hex_hash>
 */
app.post('/api/youpi-webhook', async (req, res) => {
  const signature = req.headers['x-gateway-signature'] || '';
  const rawBody = req.rawBody || Buffer.from(JSON.stringify(req.body));

  // 1. Recalculate HMAC-SHA256 using the pre-shared secret key
  const expectedSig = 'sha256=' + crypto.createHmac('sha256', WEBHOOK_SECRET).update(rawBody).digest('hex');

  // 2. Constant-time equality check to prevent timing attacks
  const isMatch = signature.length === expectedSig.length &&
                  crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expectedSig));

  if (!isMatch) {
    console.warn(`[SafeChit Webhook] ❌ Blocked unauthorized or tampered webhook. Signature mismatch.`);
    return res.status(401).json({ error: 'Invalid cryptographic signature' });
  }

  const payload = req.body;
  console.log(`[SafeChit Webhook] ✅ Verified authentic webhook event: ${payload.event} for Order: ${payload.orderId}`);

  if (payload.event === 'SUCCESS') {
    const { orderId, utr, amount, paymentId } = payload;

    try {
      // 3. Update Supabase Ledger: Mark payment as PAID
      const { error } = await supabase
        .from('chit_payments')
        .update({
          status: 'PAID',
          utr: utr || '4291' + Date.now().toString().slice(-8),
          completed_at: new Date().toISOString(),
          payment_session_id: paymentId,
        })
        .eq('id', orderId);

      if (error) {
        console.error('[SafeChit Webhook] Supabase ledger update error:', error.message);
      } else {
        console.log(`[SafeChit Webhook] 💰 Marked order ${orderId} as PAID in Supabase with UTR ${utr}!`);
      }
    } catch (err) {
      console.error('[SafeChit Webhook] Database update error:', err);
    }
  }

  res.status(200).json({ received: true });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 SafeChit YouPI Payment Webhook Server listening on port ${PORT}`);
});
