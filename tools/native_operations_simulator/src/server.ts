import { createServer, type IncomingMessage, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import type { DeviceAck, DeviceCommand, EnrollmentProof, Heartbeat, Permit, Signed } from './contract.ts';
import { Coordinator } from './coordinator.ts';

async function body(request: IncomingMessage): Promise<unknown> {
  let content = '';
  for await (const chunk of request) {
    content += chunk.toString();
    if (content.length > 16_384) throw new Error('REQUEST_TOO_LARGE');
  }
  return JSON.parse(content);
}

export async function startLoopbackServer(coordinator: Coordinator): Promise<{ server: Server; url: string }> {
  const server = createServer(async (request, response) => {
    response.setHeader('Content-Type', 'application/json');
    try {
      if (request.method === 'GET' && request.url === '/snapshot') {
        response.end(JSON.stringify(coordinator.snapshot()));
        return;
      }
      if (request.method !== 'POST') {
        response.writeHead(404).end(JSON.stringify({ error: 'NOT_FOUND' }));
        return;
      }
      const input = await body(request) as Record<string, unknown>;
      let result: unknown;
      switch (request.url) {
        case '/enrollment-token': result = { token: await coordinator.createEnrollment(input.permit as Signed<Permit>) }; break;
        case '/enroll': result = await coordinator.enroll(input.proof as Signed<EnrollmentProof>, input.permit as Signed<Permit>); break;
        case '/commands': result = await coordinator.queueCommand(input.command as Parameters<Coordinator['queueCommand']>[0], input.permit as Signed<Permit>); break;
        case '/ack': result = await coordinator.receiveAck(input.ack as Signed<DeviceAck>); break;
        case '/heartbeat': result = await coordinator.receiveHeartbeat(input.heartbeat as Signed<Heartbeat>); break;
        default: response.writeHead(404).end(JSON.stringify({ error: 'NOT_FOUND' })); return;
      }
      response.end(JSON.stringify(result ?? { ok: true }));
    } catch (error) {
      response.writeHead(400).end(JSON.stringify({ error: error instanceof Error ? error.message : 'INVALID_REQUEST' }));
    }
  });
  await new Promise<void>((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  return { server, url: `http://127.0.0.1:${(server.address() as AddressInfo).port}` };
}
