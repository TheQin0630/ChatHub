#!/usr/bin/env python3
import argparse
import selectors
import socket
import struct
import time

MSG_SUBSCRIBE = 1
MSG_UNSUBSCRIBE = 2
MSG_PUBLISH = 3
MSG_SUBACK = 4
MSG_PUBACK = 5
MSG_LOG_QUERY = 6
MSG_SUB_QUERY = 7
MSG_LOG_LIST_REQ = 8
MSG_LOG_LIST_RESP = 9
MSG_TOPIC_LIST_REQ = 10
MSG_TOPIC_LIST_RESP = 11
MSG_PUBLISH_EX = 12
MSG_PUBREC1 = 13
MSG_DELIVER = 14
MSG_DELIVER_ACK = 15

FLAG_RETAIN = 0x01
FLAG_QOS_SHIFT = 1
FLAG_DUP = 0x08

TOPIC_MAX_LEN = 64
PAYLOAD_MAX_LEN = 2048
HEADER_LEN = 4
PUBEX_HEADER = 5
PAGE_REQ_LEN = 7
PAGE_RESP_HEADER = 9


def pack(msg_type, topic, payload=b""):
    topic_bytes = topic.encode("utf-8")
    if len(topic_bytes) > TOPIC_MAX_LEN or len(payload) > PAYLOAD_MAX_LEN:
        raise ValueError("frame too large")
    return struct.pack("!BBH", msg_type, len(topic_bytes), len(payload)) + topic_bytes + payload


def pack_ex(msg_type, topic, payload, qos=0, retain=False, packet_id=0, dup=False):
    flags = 0
    if retain:
        flags |= FLAG_RETAIN
    flags |= (qos << FLAG_QOS_SHIFT) & 0x06
    if dup:
        flags |= FLAG_DUP
    inner = struct.pack("!BHH", flags, packet_id, len(payload)) + payload
    return pack(msg_type, topic, inner)


def pack_ack(msg_type, topic, packet_id):
    return pack(msg_type, topic, struct.pack("!HB", packet_id, 0))


def unpack_frame(buffer):
    if len(buffer) < HEADER_LEN:
        return None, buffer
    msg_type, topic_len, payload_len = struct.unpack("!BBH", buffer[:HEADER_LEN])
    total = HEADER_LEN + topic_len + payload_len
    if len(buffer) < total:
        return None, buffer
    topic = buffer[HEADER_LEN:HEADER_LEN + topic_len].decode("utf-8", errors="replace")
    payload = buffer[HEADER_LEN + topic_len:total]
    frame = {"type": msg_type, "topic": topic, "payload": payload, "qos": 0, "retain": False, "packet_id": 0}
    if msg_type in (MSG_PUBLISH_EX, MSG_DELIVER) and len(payload) >= PUBEX_HEADER:
        flags, packet_id, inner_len = struct.unpack("!BHH", payload[:PUBEX_HEADER])
        frame["qos"] = (flags & 0x06) >> FLAG_QOS_SHIFT
        frame["retain"] = bool(flags & FLAG_RETAIN)
        frame["packet_id"] = packet_id
        frame["payload"] = payload[PUBEX_HEADER:PUBEX_HEADER + inner_len]
    elif msg_type in (MSG_PUBREC1, MSG_DELIVER_ACK) and len(payload) >= 2:
        frame["packet_id"] = struct.unpack("!H", payload[:2])[0]
    return frame, buffer[total:]


def pack_page_response(msg_type, request_id, total, offset, rows, has_more, row_encoder):
    body = struct.pack("!HHHHB", request_id, total, offset, len(rows), 1 if has_more else 0)
    for row in rows:
        body += row_encoder(row)
    return pack(msg_type, "", body)


class Client:
    def __init__(self, sock):
        self.sock = sock
        self.buffer = b""
        self.subscriptions = set()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=1883)
    args = parser.parse_args()

    selector = selectors.DefaultSelector()
    clients = {}
    retained = {}
    logs = []
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((args.host, args.port))
    server.listen()
    server.setblocking(False)
    selector.register(server, selectors.EVENT_READ)
    print(f"mock server listening on {args.host}:{args.port}", flush=True)

    def log(line):
        stamp = time.strftime("%H:%M:%S")
        logs.append(f"{stamp} {line}")
        del logs[:-200]

    def topic_rows():
        topics = sorted({topic for client in clients.values() for topic in client.subscriptions} | set(retained.keys()))
        return [(topic, sum(1 for client in clients.values() if topic in client.subscriptions)) for topic in topics]

    try:
        while True:
            for key, _ in selector.select():
                if key.fileobj is server:
                    sock, addr = server.accept()
                    sock.setblocking(False)
                    clients[sock] = Client(sock)
                    selector.register(sock, selectors.EVENT_READ)
                    log(f"connect {addr[0]}:{addr[1]}")
                    continue

                client = clients[key.fileobj]
                data = client.sock.recv(4096)
                if not data:
                    selector.unregister(client.sock)
                    clients.pop(client.sock, None)
                    client.sock.close()
                    continue
                client.buffer += data
                while True:
                    frame, client.buffer = unpack_frame(client.buffer)
                    if frame is None:
                        break
                    msg_type = frame["type"]
                    topic = frame["topic"]
                    payload = frame["payload"]
                    if msg_type == MSG_SUBSCRIBE:
                        client.subscriptions.add(topic)
                        log(f"sub {topic}")
                        client.sock.sendall(pack(MSG_SUBACK, topic))
                        if topic in retained:
                            packet_id, retained_payload = retained[topic]
                            client.sock.sendall(pack_ex(MSG_DELIVER, topic, retained_payload, qos=1, retain=True, packet_id=packet_id))
                    elif msg_type == MSG_UNSUBSCRIBE:
                        client.subscriptions.discard(topic)
                        log(f"unsub {topic}")
                    elif msg_type == MSG_PUBLISH:
                        client.sock.sendall(pack(MSG_PUBACK, topic))
                        packet = pack(MSG_PUBLISH, topic, payload)
                        for other in list(clients.values()):
                            if other is not client and topic in other.subscriptions:
                                other.sock.sendall(packet)
                        log(f"pub {topic}")
                    elif msg_type == MSG_PUBLISH_EX:
                        if frame["retain"]:
                            retained[topic] = (frame["packet_id"], payload)
                        packet = pack_ex(MSG_DELIVER, topic, payload, qos=frame["qos"], retain=frame["retain"], packet_id=frame["packet_id"])
                        for other in list(clients.values()):
                            if other is not client and topic in other.subscriptions:
                                other.sock.sendall(packet)
                        if frame["qos"] == 1:
                            client.sock.sendall(pack_ack(MSG_PUBREC1, topic, frame["packet_id"]))
                        log(f"pubex {topic} qos={frame['qos']} retain={frame['retain']}")
                    elif msg_type == MSG_DELIVER_ACK:
                        log(f"deliver_ack {frame['packet_id']}")
                    elif msg_type == MSG_LOG_QUERY:
                        client.sock.sendall(pack(MSG_LOG_QUERY, "", "\n".join(logs).encode()))
                    elif msg_type == MSG_SUB_QUERY:
                        text = "\n".join(f"{topic} -> {count}" for topic, count in topic_rows())
                        client.sock.sendall(pack(MSG_SUB_QUERY, "", text.encode()))
                    elif msg_type == MSG_LOG_LIST_REQ and len(payload) >= PAGE_REQ_LEN:
                        request_id, offset, limit, order = struct.unpack("!HHHB", payload[:PAGE_REQ_LEN])
                        rows = list(reversed(logs)) if order else logs
                        page = rows[offset:offset + limit]
                        response = pack_page_response(
                            MSG_LOG_LIST_RESP, request_id, len(rows), offset, page, offset + limit < len(rows),
                            lambda row: bytes([min(len(row.encode()), 255)]) + row.encode()[:255],
                        )
                        client.sock.sendall(response)
                    elif msg_type == MSG_TOPIC_LIST_REQ and len(payload) >= PAGE_REQ_LEN:
                        request_id, offset, limit, _include_empty = struct.unpack("!HHHB", payload[:PAGE_REQ_LEN])
                        rows = topic_rows()
                        page = rows[offset:offset + limit]
                        response = pack_page_response(
                            MSG_TOPIC_LIST_RESP, request_id, len(rows), offset, page, offset + limit < len(rows),
                            lambda row: bytes([len(row[0].encode())]) + row[0].encode() + struct.pack("!H", row[1]),
                        )
                        client.sock.sendall(response)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
