type RecoveryClient = {
  rpc: (name: string, params?: Record<string, unknown>) => PromiseLike<{data: unknown; error: unknown}>;
  auth: {admin: {updateUserById: (id: string, attributes: {ban_duration: string}) => Promise<{error: {status?: number} | null}>}};
};

// SQL owns due times, attempt limits, leases and transactionally enqueued jobs.
// Repeating an Auth ban after a lost acknowledgement is idempotent.
export async function reconcileAuthDisabling(client: RecoveryClient) {
  const claimed = await client.rpc('claim_auth_disable_tasks', {p_limit: 10});
  if (claimed.error || !Array.isArray(claimed.data)) throw new Error('AUTH_RECOVERY_CLAIM_FAILED');
  let completed = 0, deferred = 0;
  for (const task of claimed.data) {
    if (typeof task.user_id !== 'string' || typeof task.lease_id !== 'string') {
      throw new Error('INVALID_AUTH_RECOVERY_TASK');
    }
    let success = false, code = 'AUTH_UNAVAILABLE';
    try {
      const {error} = await client.auth.admin.updateUserById(task.user_id, {ban_duration: '876000h'});
      success = !error || error.status === 404; // Deleted Auth user already cannot sign in.
      if (error && error.status && error.status < 500) code = 'AUTH_REJECTED';
    } catch {
      // Do not persist raw provider errors, tokens or user data.
    }
    const ack = await client.rpc('finish_auth_disable_task', {
      p_user_id: task.user_id, p_lease_id: task.lease_id,
      p_success: success, p_error_code: success ? null : code,
    });
    if (ack.error || ack.data !== true) {
      // Leave lease outstanding; the bounded SQL scheduler reclaims it.
      deferred++;
      continue;
    }
    if (success) completed++; else deferred++;
  }
  const monitor = await client.rpc('get_auth_disable_recovery_status');
  if (monitor.error || !monitor.data) throw new Error('AUTH_RECOVERY_MONITOR_FAILED');
  return {processed: claimed.data.length, completed, deferred, recovery: monitor.data};
}
