// This script can only instantiate in-memory mocks. It opens no ports.
import {MockMttlAdapter,MockWindowsConnector,BridgeLabCommandService} from './mock_hardware.mjs';
const scope={tenantId:'isolated-lab',installationId:'mock-windows',actorId:'test-owner',hardwareTestAllowed:true};
const adapter=new MockMttlAdapter(['simulated-strip-1','simulated-strip-2'].map(deviceId=>({...scope,deviceId})));
const service=new BridgeLabCommandService({connector:new MockWindowsConnector(adapter),enabled:true});
console.log('SIMULATION ONLY: no physical hardware, network or booking/session integration.');
console.log(JSON.stringify(service.discover(scope),null,2));
console.log(JSON.stringify(service.execute(scope,{commandId:'example-1',deviceId:'simulated-strip-1',
  type:'set_outlet',channel:1,on:true,sequence:1,expectedRevision:0,deadlineMs:Date.now()+1000}),null,2));
console.log(JSON.stringify(service.status(scope,'simulated-strip-1'),null,2));
console.log(JSON.stringify(service.audit(scope),null,2));
