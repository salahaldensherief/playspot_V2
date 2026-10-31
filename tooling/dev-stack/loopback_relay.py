"""Fixed loopback-only relays for a dedicated Docker internal bridge.
No payload/credential logging, external destinations, shell commands or writes to Docker.
"""
import http.client
import ipaddress
import json
import selectors
import socket
import socketserver
import threading
import time

SOCKET = '/run/playspot-docker.sock'
NETWORK = 'playspot-dev-clean-internal-20261031'
PROJECT = 'playspot-dev-clean-20261031'
SERVICES = {56822: ('db', 5432), 56821: ('kong', 8000), 56823: ('studio', 3000), 56824: ('inbucket', 8025)}
targets = {}

class DockerConnection(http.client.HTTPConnection):
    def __init__(self):
        super().__init__('localhost', timeout=3)
    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(3)
        self.sock.connect(SOCKET)

def metadata(path):
    connection = DockerConnection()
    try:
        connection.request('GET', path)
        response = connection.getresponse()
        return json.loads(response.read()) if response.status == 200 else None
    finally:
        connection.close()

info = metadata('/info')
if not info or info['DockerRootDir'] != '/var/lib/playspot-docker':
    raise RuntimeError('Dedicated daemon storage not verified')
network = metadata('/networks/' + NETWORK)
if not network or not network['Internal'] or network.get('Options', {}).get('com.docker.network.bridge.host_binding_ipv4') != '127.0.0.1':
    raise RuntimeError('Internal loopback network not verified')
subnet = ipaddress.ip_network(network['IPAM']['Config'][0]['Subnet'])

def refresh_targets():
    global targets
    while True:
        current = {}
        for port, (service, internal_port) in SERVICES.items():
            name = 'supabase_' + service + '_' + PROJECT
            try:
                container = metadata('/containers/' + name + '/json')
                if not container or container.get('Name') != '/' + name or not container['State']['Running']:
                    continue
                networks = container['NetworkSettings']['Networks']
                if set(networks) != {NETWORK}:
                    continue
                address = networks[NETWORK]['IPAddress']
                if ipaddress.ip_address(address) not in subnet:
                    continue
                current[port] = (address, internal_port)
            except (OSError, ValueError, KeyError, http.client.HTTPException):
                continue
        targets = current
        time.sleep(0.25)

class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        target = targets.get(self.server.server_address[1])
        if target is None:
            return
        try:
            with socket.create_connection(target, timeout=5) as remote, selectors.DefaultSelector() as selector:
                selector.register(self.request, selectors.EVENT_READ, remote)
                selector.register(remote, selectors.EVENT_READ, self.request)
                while True:
                    ready = selector.select(timeout=90)
                    if not ready:
                        return
                    for key, _ in ready:
                        data = key.fileobj.recv(65536)
                        if not data:
                            return
                        key.data.sendall(data)
        except OSError:
            return

class Relay(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True
    def handle_error(self, request, client_address):
        pass

threading.Thread(target=refresh_targets, daemon=True).start()
servers = [Relay(('127.0.0.1', port), Handler) for port in SERVICES]
for server in servers:
    threading.Thread(target=server.serve_forever, daemon=True).start()
print('Dedicated internal-service relays listening on 127.0.0.1 ports 56821-56824', flush=True)
try:
    threading.Event().wait()
finally:
    for server in servers:
        server.shutdown()
        server.server_close()
