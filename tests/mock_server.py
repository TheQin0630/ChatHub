#!/usr/bin/env python3
"""ChatHub 全协议本地 mock 服务端（仅 Python 标准库）。"""
import argparse, selectors, socket, struct, time

SUB, UNSUB, PUB, SUBACK, PUBACK, LOGQ, SUBQ, LOGREQ, LOGRESP, TOPREQ, TOPRESP = range(1, 12)
PUBEX, PUBREC, DELIVER, DELIVER_ACK = 12, 13, 14, 15
CONNREQ, CONNRESP, SUBSREQ, SUBSRESP, RULEREQ, RULERESP = 16, 17, 18, 19, 20, 21
SUBREJ, PUBREJ, CREATE, CREATERESP, DELETE, DELETERESP, RELREQ, RELRESP = 22, 23, 24, 25, 26, 27, 28, 29
SELFREQ, SELFRESP, UNSUBFD, UNSUBFDRESP, ALIASREQ, ALIASRESP, UNSUBFDNOTICE = 30, 31, 32, 33, 34, 35, 36

def pack(kind, topic="", payload=b""):
    topic = topic.encode() if isinstance(topic, str) else topic
    return struct.pack("!BBH", kind, len(topic), len(payload)) + topic + payload

def entry(client):
    ip = socket.inet_aton(client.addr[0]); alias = client.alias.encode()
    return struct.pack("!I", client.fd) + ip + struct.pack("!H", client.addr[1]) + bytes([len(alias)]) + alias

def frame_from(buffer):
    if len(buffer) < 4: return None, buffer
    kind, tl, pl = struct.unpack("!BBH", buffer[:4]); size = 4 + tl + pl
    if len(buffer) < size: return None, buffer
    return (kind, buffer[4:4+tl].decode(errors="replace"), buffer[4+tl:size]), buffer[size:]

def page(kind, req, total, offset, rows):
    data = struct.pack("!HHHHB", req, total, offset, len(rows), int(offset + len(rows) < total))
    for row in rows: data += bytes([min(255, len(row))]) + row[:255]
    return pack(kind, payload=data)

class Client:
    def __init__(self, sock, addr, fd): self.sock, self.addr, self.fd, self.buf, self.alias, self.subs = sock, addr, fd, b"", "", set()
    def send(self, kind, topic="", payload=b""): self.sock.sendall(pack(kind, topic, payload))

class Mock:
    def __init__(self, host, port):
        self.sel, self.clients, self.topics, self.retain, self.rules, self.logs = selectors.DefaultSelector(), {}, set(), {}, {}, []
        self.nextfd = 10; self.server = socket.socket(); self.server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server.bind((host, port)); self.server.listen(); self.server.setblocking(False); self.sel.register(self.server, selectors.EVENT_READ)
    def log(self, text): self.logs.append(time.strftime("%H:%M:%S ") + text); self.logs = self.logs[-200:]
    def client_by_fd(self, fd): return next((c for c in self.clients.values() if c.fd == fd), None)
    def permitted(self, c, topic, bit): return not (self.rules.get((c.fd, topic), 0) & bit)
    def deliver(self, c, topic, data, alias, flags=0, packet=0):
        if not self.permitted(c, topic, 4): return
        raw = alias.encode(); payload = struct.pack("!BHH", flags, packet, len(data)) + data + bytes([len(raw)]) + raw
        c.send(DELIVER, topic, payload)
    def normal(self, c, topic, data, alias):
        raw = alias.encode(); c.send(PUB, topic, struct.pack("!H", len(data)) + data + bytes([len(raw)]) + raw)
    def handle(self, c, kind, topic, payload):
        if kind == ALIASREQ:
            if not payload or payload[0] > 32 or len(payload) != payload[0] + 1: return
            c.alias = payload[1:].decode(errors="replace"); c.send(ALIASRESP, payload=payload); self.log(f"alias fd={c.fd} {c.alias}")
        elif kind == SELFREQ: c.send(SELFRESP, payload=entry(c))
        elif kind == CREATE:
            exists = topic in self.topics; self.topics.add(topic); c.send(CREATERESP, topic, bytes([1 if exists else 0]))
        elif kind == DELETE:
            exists = topic in self.topics; self.topics.discard(topic); self.retain.pop(topic, None)
            for x in self.clients.values(): x.subs.discard(topic)
            c.send(DELETERESP, topic, bytes([0 if exists else 1]))
        elif kind == SUB:
            if topic not in self.topics: c.send(SUBREJ, topic, b"\x02topic not found")
            elif not self.permitted(c, topic, 2): c.send(SUBREJ, topic, b"\x01subscription denied")
            else:
                c.subs.add(topic); c.send(SUBACK, topic)
                if topic in self.retain:
                    data, alias, flags, pid = self.retain[topic]; self.deliver(c, topic, data, alias, flags, pid)
        elif kind == UNSUB: c.subs.discard(topic)
        elif kind == PUB:
            if not self.permitted(c, topic, 8): c.send(PUBREJ, topic, b"\x01publish denied")
            else:
                for x in self.clients.values():
                    if topic in x.subs: self.normal(x, topic, payload, c.alias)
                c.send(PUBACK, topic); self.log(f"publish {topic}")
        elif kind == PUBEX and len(payload) >= 5:
            flags, pid, size = struct.unpack("!BHH", payload[:5]); data = payload[5:5+size]
            if len(data) != size or not self.permitted(c, topic, 8): c.send(PUBREJ, topic, b"\x01publish denied")
            else:
                if flags & 1: self.retain[topic] = (data, c.alias, flags, pid)
                for x in self.clients.values():
                    if topic in x.subs: self.deliver(x, topic, data, c.alias, flags, pid)
                if ((flags >> 1) & 3) == 1: c.send(PUBREC, topic, struct.pack("!HB", pid, 0))
        elif kind == CONNREQ:
            rows = b"".join(entry(x) for x in self.clients.values()); c.send(CONNRESP, payload=struct.pack("!H", len(self.clients)) + rows)
        elif kind == SUBSREQ:
            if topic not in self.topics: c.send(SUBSRESP, topic, b"\x01\0\0")
            else:
                rows = [x for x in self.clients.values() if topic in x.subs]; c.send(SUBSRESP, topic, b"\0" + struct.pack("!H", len(rows)) + b"".join(entry(x) for x in rows))
        elif kind == RULEREQ and len(payload) >= 6:
            op, mask, fd = payload[0], payload[1], struct.unpack("!I", payload[2:6])[0]; target = self.client_by_fd(fd); status = 0 if target else 5
            if target:
                key = (fd, topic); self.rules[key] = (self.rules.get(key, 0) | mask) if op == 1 else (self.rules.get(key, 0) & ~mask)
            c.send(RULERESP, topic, bytes([status, op, mask]) + struct.pack("!I", fd) + bytes([len(target.alias.encode()) if target else 0]) + (target.alias.encode() if target else b""))
        elif kind == RELREQ and len(payload) >= 4:
            fd = struct.unpack("!I", payload[:4])[0]; target = self.client_by_fd(fd); mask = self.rules.get((fd, topic), 0)
            if target and topic in target.subs: mask |= 1
            c.send(RELRESP, topic, bytes([0 if target else 1]) + struct.pack("!I", fd) + bytes([mask, len(target.alias.encode()) if target else 0]) + (target.alias.encode() if target else b""))
        elif kind == UNSUBFD and len(payload) >= 4:
            fd = struct.unpack("!I", payload[:4])[0]; target = self.client_by_fd(fd)
            if target: target.subs.discard(topic); target.send(UNSUBFDNOTICE, topic)
            alias = target.alias.encode() if target else b""; c.send(UNSUBFDRESP, topic, struct.pack("!I", fd) + bytes([len(alias)]) + alias)
        elif kind == LOGQ: c.send(LOGQ, payload="\n".join(self.logs).encode())
        elif kind == SUBQ: c.send(SUBQ, payload="\n".join(sorted(self.topics)).encode())
        elif kind == LOGREQ and len(payload) >= 7:
            req, offset, limit, order = struct.unpack("!HHHB", payload[:7]); rows = list(reversed(self.logs)) if order else self.logs
            rows = [r.encode() for r in rows]; c.sock.sendall(page(LOGRESP, req, len(rows), offset, rows[offset:offset+limit]))
        elif kind == TOPREQ and len(payload) >= 7:
            req, offset, limit, _ = struct.unpack("!HHHB", payload[:7]); rows = sorted(self.topics); selected = rows[offset:offset+limit]
            data = struct.pack("!HHHHB", req, len(rows), offset, len(selected), int(offset + len(selected) < len(rows)))
            for name in selected:
                raw = name.encode(); data += bytes([len(raw)]) + raw + struct.pack("!H", sum(name in x.subs for x in self.clients.values()))
            c.send(TOPRESP, payload=data)
    def run(self):
        print(f"mock server listening on {self.server.getsockname()[0]}:{self.server.getsockname()[1]}", flush=True)
        while True:
            for key, _ in self.sel.select():
                if key.fileobj is self.server:
                    sock, addr = self.server.accept(); sock.setblocking(False); c = Client(sock, addr, self.nextfd); self.nextfd += 1; self.clients[sock] = c; self.sel.register(sock, selectors.EVENT_READ); self.log(f"connect {c.fd}"); continue
                c = self.clients[key.fileobj]
                try: data = c.sock.recv(4096)
                except OSError: data = b""
                if not data:
                    self.sel.unregister(c.sock); self.clients.pop(c.sock, None); c.sock.close(); continue
                c.buf += data
                while True:
                    frame, c.buf = frame_from(c.buf)
                    if frame is None: break
                    self.handle(c, *frame)

if __name__ == "__main__":
    ap = argparse.ArgumentParser(); ap.add_argument("--host", default="127.0.0.1"); ap.add_argument("--port", type=int, default=1883); args = ap.parse_args(); Mock(args.host, args.port).run()
