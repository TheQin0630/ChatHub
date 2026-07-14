#!/usr/bin/env python3
"""最终版 Relay 服务端的黑盒协议联调测试；不会修改或重编译服务端。"""
import argparse
import socket
import struct
import sys
import time
import uuid

SUBSCRIBE, PUBLISH, SUBACK, PUBACK = 1, 3, 4, 5
PUBLISH_EX, PUBREC1, DELIVER, DELIVER_ACK = 12, 13, 14, 15
CONN_LIST_REQ, CONN_LIST_RESP = 16, 17
TOPIC_SUBS_REQ, TOPIC_SUBS_RESP = 18, 19
TOPIC_CREATE_REQ, TOPIC_CREATE_RESP = 24, 25
SELF_CONN_REQ, SELF_CONN_RESP = 30, 31
UNSUB_FD_REQ, UNSUB_FD_RESP = 32, 33
ALIAS_SET_REQ, ALIAS_SET_RESP, UNSUB_FD_NOTIFY = 34, 35, 36


def pack(kind, topic="", payload=b""):
    topic = topic.encode("utf-8") if isinstance(topic, str) else topic
    return struct.pack("!BBH", kind, len(topic), len(payload)) + topic + payload


def recv_exact(sock, size):
    data = b""
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise ConnectionError("服务端关闭了连接")
        data += chunk
    return data


def recv_frame(sock):
    kind, topic_len, payload_len = struct.unpack("!BBH", recv_exact(sock, 4))
    topic = recv_exact(sock, topic_len).decode("utf-8", errors="strict")
    return kind, topic, recv_exact(sock, payload_len)


def receive_until(sock, expected, timeout=3):
    deadline = time.monotonic() + timeout
    buffered = []
    previous = sock.gettimeout()
    try:
        while time.monotonic() < deadline:
            sock.settimeout(max(0.05, deadline - time.monotonic()))
            frame = recv_frame(sock)
            buffered.append(frame)
            if frame[0] == expected:
                return frame, buffered
    finally:
        sock.settimeout(previous)
    raise AssertionError(f"等待消息 type={expected} 超时，已收到 {[f[0] for f in buffered]}")


def expect(condition, message):
    if not condition:
        raise AssertionError(message)


def alias_payload(alias):
    raw = alias.encode("utf-8")
    expect(len(raw) <= 32, "测试别名超过 32 UTF-8 字节")
    return bytes([len(raw)]) + raw


def parse_alias(payload, offset=0):
    expect(offset < len(payload), "响应中缺少 alias_len")
    size = payload[offset]
    expect(size <= 32 and offset + 1 + size == len(payload), "别名字段长度非法")
    return payload[offset + 1:].decode("utf-8")


def set_alias(sock, alias):
    sock.sendall(pack(ALIAS_SET_REQ, payload=alias_payload(alias)))
    _, _, payload = receive_until(sock, ALIAS_SET_RESP)[0]
    expect(parse_alias(payload) == alias, "服务端未回显设置后的别名")


def self_connection(sock):
    sock.sendall(pack(SELF_CONN_REQ))
    _, _, payload = receive_until(sock, SELF_CONN_RESP)[0]
    expect(len(payload) >= 11, "本人连接响应过短")
    fd = struct.unpack("!I", payload[:4])[0]
    ip = ".".join(map(str, payload[4:8]))
    port = struct.unpack("!H", payload[8:10])[0]
    return {"fd": fd, "ip": ip, "port": port, "alias": parse_alias(payload, 10)}


def create_topic(sock, topic):
    sock.sendall(pack(TOPIC_CREATE_REQ, topic))
    _, _, payload = receive_until(sock, TOPIC_CREATE_RESP)[0]
    expect(payload and payload[0] in (0, 1), "创建频道失败")


def subscribe(sock, topic):
    sock.sendall(pack(SUBSCRIBE, topic))
    frame, _ = receive_until(sock, SUBACK)
    expect(frame[1] == topic, "订阅确认的频道不一致")


def parse_forwarded_publish(payload):
    expect(len(payload) >= 3, "普通下行消息过短")
    length = struct.unpack("!H", payload[:2])[0]
    expect(2 + length < len(payload), "普通下行 data_len 非法")
    data = payload[2:2 + length]
    return data, parse_alias(payload, 2 + length)


def parse_deliver(payload):
    expect(len(payload) >= 6, "DELIVER 负载过短")
    flags, packet_id, length = struct.unpack("!BHH", payload[:5])
    expect(5 + length < len(payload), "DELIVER data_len 非法")
    data = payload[5:5 + length]
    return flags, packet_id, data, parse_alias(payload, 5 + length)


def module_identity(a, _b, _topic):
    set_alias(a, "alice-测试")
    info = self_connection(a)
    expect(info["fd"] > 0 and info["alias"] == "alice-测试", "本人连接信息或别名不正确")
    print(f"[PASS] identity: fd={info['fd']} {info['ip']}:{info['port']} alias={info['alias']}")


def module_publish(a, b, topic):
    set_alias(a, "alice")
    set_alias(b, "bob")
    create_topic(a, topic)
    subscribe(a, topic)
    subscribe(b, topic)
    body = b"plain-message"
    a.sendall(pack(PUBLISH, topic, body))
    frame, _ = receive_until(b, PUBLISH)
    data, alias = parse_forwarded_publish(frame[2])
    expect(frame[1] == topic and data == body and alias == "alice", "普通发布转发或别名错误")
    receive_until(a, PUBACK)
    print("[PASS] publish: 订阅端收到正文和发送方别名")


def module_qos_retain(a, b, topic):
    set_alias(a, "qos-sender")
    create_topic(a, topic)
    subscribe(b, topic)
    body = b"reliable-retained"
    flags = 0x01 | 0x02  # retain + qos1
    a.sendall(pack(PUBLISH_EX, topic, struct.pack("!BHH", flags, 77, len(body)) + body))
    delivery, _ = receive_until(b, DELIVER)
    got_flags, packet_id, data, alias = parse_deliver(delivery[2])
    expect(data == body and alias == "qos-sender" and packet_id == 77 and got_flags & 0x03 == 0x03,
           "QoS1/retain 投递字段不正确")
    b.sendall(pack(DELIVER_ACK, topic, struct.pack("!HB", packet_id, 0)))
    receive_until(a, PUBREC1)
    with socket.create_connection((ARGS.host, ARGS.port), timeout=3) as late:
        set_alias(late, "late")
        subscribe(late, topic)
        retained, _ = receive_until(late, DELIVER)
        _, _, data, alias = parse_deliver(retained[2])
        expect(data == body and alias == "qos-sender", "retain 未保留发送时别名快照")
        late.sendall(pack(DELIVER_ACK, topic, struct.pack("!HB", 77, 0)))
    print("[PASS] qos_retain: QoS1、ACK 与 retain 别名快照正确")


def module_management(a, b, topic):
    set_alias(a, "operator")
    set_alias(b, "target")
    create_topic(a, topic)
    subscribe(b, topic)
    target = self_connection(b)
    a.sendall(pack(CONN_LIST_REQ))
    _, _, payload = receive_until(a, CONN_LIST_RESP)[0]
    count = struct.unpack("!H", payload[:2])[0]
    expect(count >= 2 and b"target" in payload, "在线连接列表未返回目标别名")
    a.sendall(pack(TOPIC_SUBS_REQ, topic))
    _, _, payload = receive_until(a, TOPIC_SUBS_RESP)[0]
    expect(payload[:3] == b"\0\0\1" and b"target" in payload, "频道订阅者列表未返回别名")
    a.sendall(pack(UNSUB_FD_REQ, topic, struct.pack("!I", target["fd"])))
    notify, _ = receive_until(b, UNSUB_FD_NOTIFY)
    expect(notify[1] == topic, "目标连接未收到强制退订通知")
    response, _ = receive_until(a, UNSUB_FD_RESP)
    expect(struct.unpack("!I", response[2][:4])[0] == target["fd"] and parse_alias(response[2], 4) == "target",
           "强制退订响应错误")
    print("[PASS] management: 列表别名、强制退订与通知正确")


MODULES = {"identity": module_identity, "publish": module_publish,
           "qos_retain": module_qos_retain, "management": module_management}


def main():
    parser = argparse.ArgumentParser(description="最终版 Relay 服务端黑盒联调测试（不修改服务端）")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=1883)
    parser.add_argument("--module", choices=["all", *MODULES], default="all")
    global ARGS
    ARGS = parser.parse_args()
    selected = MODULES.items() if ARGS.module == "all" else [(ARGS.module, MODULES[ARGS.module])]
    for name, test in selected:
        topic = "test/" + name + "/" + uuid.uuid4().hex[:12]
        with socket.create_connection((ARGS.host, ARGS.port), timeout=3) as a, \
             socket.create_connection((ARGS.host, ARGS.port), timeout=3) as b:
            a.settimeout(3)
            b.settimeout(3)
            test(a, b, topic)
    print("全部所选模块通过")


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, ConnectionError, OSError, socket.timeout) as error:
        print(f"[FAIL] {error}", file=sys.stderr)
        sys.exit(1)
