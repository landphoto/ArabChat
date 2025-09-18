import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

const taken = ['admin','root','user','muhannad','guest','test','arabchat','support'];

async function main() {
  for (const u of taken) {
    const username = u.toLowerCase();
    await prisma.user.upsert({
      where: { username },
      update: {},
      create: { username }
    });
  }
  console.log('Seed done.');
}

main().finally(() => prisma.$disconnect());
