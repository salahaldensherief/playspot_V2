"""ONLY run against the isolated room fixture database, never hosted data."""
import subprocess,time,os
# Pass the local psql executable explicitly; no credentials or hosted URI.
import sys
psql=sys.argv[1]
base=[psql,'-h','localhost','-p','55439','-U','playspot_fixture','-d','playspot_room_review_20261004','-v','ON_ERROR_STOP=1','-v','VERBOSITY=verbose','-t','-A']
actor="SELECT set_config('test.actor','00000000-0000-0000-0000-000000000001',false);"
r='00000000-0000-0000-0000-000000000021';b1='00000000-0000-0000-0000-000000000031';b2='00000000-0000-0000-0000-000000000032'
def run(sql):
 return subprocess.run(base+['-c',sql],capture_output=True,text=True,timeout=12)
def ok(sql):
 result=run(sql);assert result.returncode==0,result.stderr
ok(f"INSERT INTO profiles VALUES ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000011','owner',true,false,true); INSERT INTO rooms VALUES ('{r}','00000000-0000-0000-0000-000000000011','available',true,now()); INSERT INTO bookings VALUES ('{b1}','{r}','upcoming'),('{b2}','{r}','upcoming');")
try:
 cases=[('maintenance_vs_start',f"{actor} SELECT set_room_operational_status('{r}','maintenance');",f"UPDATE bookings SET status='in_progress' WHERE id='{b1}';",'ROOM_NOT_AVAILABLE_FOR_SESSION'),('start_vs_maintenance',f"UPDATE bookings SET status='in_progress' WHERE id='{b1}';",f"{actor} SELECT set_room_operational_status('{r}','maintenance');",'ROOM_HAS_ACTIVE_SESSION'),('simultaneous_starts',f"UPDATE bookings SET status='in_progress' WHERE id='{b1}';",f"UPDATE bookings SET status='in_progress' WHERE id='{b2}';",'ROOM_HAS_ACTIVE_SESSION')]
 for name,first,second,error in cases:
  ok(f"UPDATE bookings SET status='upcoming'; {actor} SELECT set_room_operational_status('{r}','available');")
  a=subprocess.Popen(base+['-c',f"BEGIN; {first} SELECT 'LOCKED'; SELECT pg_sleep(1.5); COMMIT;"],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env={**os.environ,'PGAPPNAME':'playspot-room-race'})
  deadline=time.monotonic()+5
  while True:
   observed=run("SELECT EXISTS(SELECT FROM pg_stat_activity WHERE application_name='playspot-room-race' AND wait_event='PgSleep');")
   if observed.stdout.strip()=='t':break
   assert time.monotonic()<deadline, 'first transaction did not reach sleep with row lock'
   time.sleep(0.03)
  start=time.monotonic();result=run(second);elapsed=time.monotonic()-start
  assert result.returncode!=0 and error in result.stderr and '55000' in result.stderr,(name,result.stderr)
  assert elapsed>=0.7,(name,'did not wait for shared room lock',elapsed)
  a.communicate(timeout=10);assert a.returncode==0
  print(f'{name}: denied after lock wait {elapsed:.2f}s')
 print('3 concurrent transaction scenarios passed')
finally:
 ok(f"DELETE FROM bookings WHERE id IN ('{b1}','{b2}'); DELETE FROM rooms WHERE id='{r}'; DELETE FROM profiles WHERE id='00000000-0000-0000-0000-000000000001';")
