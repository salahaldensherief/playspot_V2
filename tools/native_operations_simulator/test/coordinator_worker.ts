import { Coordinator } from '../src/coordinator.ts';
import { CoordinatorStore } from '../src/coordinator_store.ts';
import type { Permit, Signed, WriterLease } from '../src/contract.ts';

let coordinator: Coordinator | null = null;
let now = 0;

process.on('message', async (message: unknown) => {
  const request = message as { id: number; type: string; payload: Record<string, unknown> };
  try {
    let result: unknown;
    switch (request.type) {
      case 'open': {
        const input = request.payload;
        now = input.now as number;
        coordinator = await Coordinator.open(input.path as string, input.venueId as string, input.issuerPublicKey as string, input.coordinatorPrivateKey as string, () => now);
        break;
      }
      case 'time': now = request.payload.now as number; break;
      case 'activate': result = await coordinator!.activateWriter(request.payload.lease as Signed<WriterLease>); break;
      case 'queue': result = await coordinator!.queueCommand(request.payload.command as Parameters<Coordinator['queueCommand']>[0], request.payload.permit as Signed<Permit>); break;
      case 'revoke': result = await coordinator!.revokeDevice(request.payload.stationId as string, request.payload.permit as Signed<Permit>); break;
      case 'snapshot': result = coordinator!.snapshot(); break;
      case 'crash_in_transaction': {
        const store = CoordinatorStore.open(request.payload.path as string, request.payload.venueId as string);
        store.transact(state => {
          state.audit.push({ at: now, event: 'never_committed', stationId: '*' });
          process.exit(77);
        });
        break;
      }
      default: throw new Error('UNKNOWN_REQUEST');
    }
    process.send?.({ id: request.id, ok: true, result });
  } catch (error) {
    process.send?.({ id: request.id, ok: false, error: error instanceof Error ? error.message : 'UNKNOWN_ERROR' });
  }
});
