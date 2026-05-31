#!/usr/bin/env python3
"""Minimal SOCKS5 proxy (CONNECT only, no auth). Depends only on Python stdlib."""
import asyncio
import socket
import struct
import sys

SOCKS_VERSION = 5


async def relay(reader, writer, label):
    try:
        while True:
            data = await reader.read(8192)
            if not data:
                break
            writer.write(data)
            await writer.drain()
    except (ConnectionError, asyncio.IncompleteReadError, OSError):
        pass
    finally:
        try:
            writer.close()
        except OSError:
            pass


async def handle_socks5(reader, writer):
    try:
        ver, nmethods = struct.unpack("!BB", await reader.readexactly(2))
        await reader.readexactly(nmethods)
    except (asyncio.IncompleteReadError, OSError):
        writer.close()
        return

    writer.write(struct.pack("!BB", SOCKS_VERSION, 0))
    await writer.drain()

    try:
        ver, cmd, rsv, atyp = struct.unpack("!BBBB", await reader.readexactly(4))
    except (asyncio.IncompleteReadError, OSError):
        writer.close()
        return

    if cmd != 1:  # CONNECT only
        writer.write(struct.pack("!BBBB", SOCKS_VERSION, 7, 0, 1) + socket.inet_aton("0.0.0.0") + struct.pack("!H", 0))
        await writer.drain()
        writer.close()
        return

    if atyp == 1:
        addr = socket.inet_ntoa(await reader.readexactly(4))
    elif atyp == 3:
        length = (await reader.readexactly(1))[0]
        addr = (await reader.readexactly(length)).decode()
    elif atyp == 4:
        addr = socket.inet_ntop(socket.AF_INET6, await reader.readexactly(16))
    else:
        writer.close()
        return

    port = struct.unpack("!H", await reader.readexactly(2))[0]

    try:
        remote_reader, remote_writer = await asyncio.open_connection(addr, port)
    except (ConnectionError, OSError, socket.gaierror):
        writer.write(struct.pack("!BBBB", SOCKS_VERSION, 1, 0, 1) + socket.inet_aton("0.0.0.0") + struct.pack("!H", 0))
        await writer.drain()
        writer.close()
        return

    bind_ip = socket.inet_aton(remote_writer.get_extra_info("sockname")[0])
    bind_port = remote_writer.get_extra_info("sockname")[1]
    writer.write(struct.pack("!BBBB", SOCKS_VERSION, 0, 0, 1) + bind_ip + struct.pack("!H", bind_port))
    await writer.drain()

    await asyncio.gather(relay(reader, remote_writer, "up"), relay(remote_reader, writer, "down"))


async def main(host="127.0.0.1", port=10809):
    server = await asyncio.start_server(handle_socks5, host, port)
    print(f"SOCKS5 proxy: {host}:{port}")
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    host = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 10809
    asyncio.run(main(host, port))
