import argparse
import json
import secrets
import socket
import struct


def read_exact(connection, count):
    result = b''
    while len(result) < count:
        chunk = connection.recv(count - len(result))
        if not chunk:
            raise RuntimeError('SOCKS connection closed')
        result += chunk
    return result


def encode_address(host, port):
    try:
        address = b'\x01' + socket.inet_pton(socket.AF_INET, host)
    except OSError:
        try:
            address = b'\x04' + socket.inet_pton(socket.AF_INET6, host)
        except OSError:
            name = host.encode('idna')
            if not 0 < len(name) <= 255:
                raise ValueError('invalid destination host')
            address = b'\x03' + bytes([len(name)]) + name
    return address + struct.pack('!H', port)


def read_address(connection):
    kind = read_exact(connection, 1)[0]
    if kind == 1:
        host = socket.inet_ntop(socket.AF_INET, read_exact(connection, 4))
    elif kind == 4:
        host = socket.inet_ntop(socket.AF_INET6, read_exact(connection, 16))
    elif kind == 3:
        host = read_exact(connection, read_exact(connection, 1)[0]).decode('ascii')
    else:
        raise RuntimeError('invalid SOCKS address type')
    return host, struct.unpack('!H', read_exact(connection, 2))[0]


def decode_packet(data):
    if len(data) < 4 or data[:3] != b'\x00\x00\x00':
        raise RuntimeError('invalid SOCKS UDP response')
    kind = data[3]
    if kind == 1:
        offset = 8
        host = socket.inet_ntop(socket.AF_INET, data[4:offset])
    elif kind == 4:
        offset = 20
        host = socket.inet_ntop(socket.AF_INET6, data[4:offset])
    elif kind == 3:
        offset = 5 + data[4]
        host = data[5:offset].decode('ascii')
    else:
        raise RuntimeError('invalid SOCKS UDP address type')
    port = struct.unpack('!H', data[offset:offset + 2])[0]
    return host, port, data[offset + 2:]


def dns_question(name):
    transaction = secrets.randbits(16)
    labels = [label.encode('idna') for label in name.rstrip('.').split('.')]
    if any(not 0 < len(label) <= 63 for label in labels):
        raise ValueError('invalid DNS query name')
    question = b''.join(bytes([len(label)]) + label for label in labels) + b'\x00'
    return transaction, struct.pack('!6H', transaction, 0x0100, 1, 0, 0, 0) + question + struct.pack('!HH', 1, 1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--proxy-host', default='127.0.0.1')
    parser.add_argument('--proxy-port', type=int, default=49386)
    parser.add_argument('--host', default='api.openai.com')
    parser.add_argument('--port', type=int, default=49390)
    parser.add_argument('--nonce', default=None)
    parser.add_argument('--username')
    parser.add_argument('--timeout', type=float, default=5)
    parser.add_argument('--dns', action='store_true')
    parser.add_argument('--query', default='example.com')
    args = parser.parse_args()
    if args.proxy_host not in ('127.0.0.1', '::1'):
        raise ValueError('proxy must be a loopback address')
    nonce = args.nonce or secrets.token_hex(12)
    transaction, payload = dns_question(args.query) if args.dns else (None, nonce.encode())
    with socket.create_connection((args.proxy_host, args.proxy_port), args.timeout) as control:
        control.settimeout(args.timeout)
        control.sendall(b'\x05\x01' + (b'\x02' if args.username else b'\x00'))
        hello = read_exact(control, 2)
        if hello[0] != 5 or hello[1] not in (0, 2):
            raise RuntimeError('SOCKS authentication method rejected')
        if hello[1] == 2:
            if not args.username:
                raise RuntimeError('fixture username required')
            username = args.username.encode()
            password = b'acceptance-only'
            if not 0 < len(username) <= 255:
                raise ValueError('invalid fixture username')
            control.sendall(b'\x01' + bytes([len(username)]) + username + bytes([len(password)]) + password)
            if read_exact(control, 2) != b'\x01\x00':
                raise RuntimeError('fixture authentication rejected')
        control.sendall(b'\x05\x03\x00' + encode_address('0.0.0.0', 0))
        header = read_exact(control, 3)
        if header != b'\x05\x00\x00':
            raise RuntimeError(f'SOCKS UDP association failed with status {header[1]}')
        relay_host, relay_port = read_address(control)
        if relay_host in ('0.0.0.0', '::'):
            relay_host = args.proxy_host
        family = socket.AF_INET6 if ':' in relay_host else socket.AF_INET
        with socket.socket(family, socket.SOCK_DGRAM) as udp:
            udp.settimeout(args.timeout)
            udp.connect((relay_host, relay_port))
            udp.send(b'\x00\x00\x00' + encode_address(args.host, args.port) + payload)
            remote_host, remote_port, reply = decode_packet(udp.recv(65535))
    result = {'network': 'udp', 'requestedhost': args.host, 'port': args.port, 'replyhost': remote_host, 'replyport': remote_port}
    if args.dns:
        if len(reply) < 12:
            raise RuntimeError('short DNS response')
        identifier, flags, questions, answers, authorities, additional = struct.unpack('!6H', reply[:12])
        if identifier != transaction or not flags & 0x8000:
            raise RuntimeError('DNS transaction mismatch')
        result.update({'dns': True, 'query': args.query, 'rcode': flags & 15, 'answers': answers, 'bytes': len(reply), 'transaction': transaction})
    else:
        decoded = reply.decode()
        suffix = ':' + nonce
        if not decoded.endswith(suffix):
            raise RuntimeError('UDP nonce mismatch')
        result.update({'nonce': nonce, 'exitlabel': decoded[:-len(suffix)], 'reply': decoded})
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
