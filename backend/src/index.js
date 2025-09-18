import express from 'express';
import cors from 'cors';
import { createServer } from 'http';
import { Server } from 'socket.io';
import { PrismaClient } from '@prisma/client';

const app = express();
app.use(cors());
app.use(express.json());

const prisma = new PrismaClient();

app.get('/api/health', (req, res) => res.json({ ok: true }));

app.get('/api/check-username', async (req, res) => {
  const u = (req.query.u || '').toString();
  if (!u || u.length < 3 || /\s/.test(u) || !/^[\p{L}0-9_.-]+$/u.test(u)) {
    return res.json({ available: false, message: 'اسم غير صالح' });
  }
  const found = await prisma.user.findUnique({ where: { username: u.toLowerCase() } });
  if (found) return res.json({ available: false, message: 'الاسم غير متاح' });
  return res.json({ available: true, message: 'الاسم متاح' });
});

// Minimal chat memory (last 50)
let lastMessages = [];

const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: { origin: '*' },
  path: '/socket.io'
});

const chat = io.of('/chat');
chat.on('connection', (socket) => {
  socket.emit('history', lastMessages);
  socket.on('join', async ({ username }) => {
    if (!username) return;
    socket.data.username = username;
    socket.join('lobby');
    chat.emit('online', { count: chat.sockets.size });
  });
  socket.on('message', async (payload) => {
    const text = (payload?.text || '').toString().trim();
    const user = socket.data.username || 'guest';
    if (!text) return;
    const username = user.toLowerCase();
    let dbUser = await prisma.user.findUnique({ where: { username } });
    if (!dbUser) dbUser = await prisma.user.create({ data: { username } });
    await prisma.message.create({ data: { text, userId: dbUser.id } });
    const msg = { user, text, ts: Date.now() };
    lastMessages.push(msg);
    lastMessages = lastMessages.slice(-50);
    chat.to('lobby').emit('message', msg);
  });
  socket.on('typing', (v) => socket.to('lobby').emit('typing', { user: socket.data.username, ...v }));
  socket.on('disconnect', () => chat.emit('online', { count: chat.sockets.size }));
});

const PORT = process.env.PORT || 4000;
httpServer.listen(PORT, () => {
  console.log('ArabChat backend on http://localhost:' + PORT);
});
