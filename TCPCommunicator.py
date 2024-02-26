import datetime
import threading
from flask import Flask, request, jsonify
import json
import socket
from queue import Queue
from Crypto.PublicKey import RSA
from Crypto.Cipher import PKCS1_OAEP
import base64
import os
import select
import random
import string
from itertools import cycle

app = Flask(__name__)

TCP_HOST = '0.0.0.0'
TCP_PORT = 5006
EXPECTED_KEYS = {'sender', 'message', 'topic'}
message_queue = Queue()

KEY_FILE_PATH = 'xor_key_info.txt'
KEY_REFRESH_INTERVAL = datetime.timedelta(hours=6)

xor_key_lock = threading.Lock()
XOR_KEY = ''
last_key_refresh_time = datetime.datetime.now()

def load_xor_key():
    global XOR_KEY, last_key_refresh_time
    try:
        with open(KEY_FILE_PATH, 'r') as key_file:
            key_data = key_file.readline().strip().split(',')
            if len(key_data) == 2:
                XOR_KEY, timestamp_str = key_data
                last_key_refresh_time = datetime.datetime.fromisoformat(timestamp_str)
                if datetime.datetime.now() - last_key_refresh_time >= KEY_REFRESH_INTERVAL:
                    refresh_xor_key()
            else:
                refresh_xor_key()
    except FileNotFoundError:
        refresh_xor_key()
    except Exception as e:
        print(f"Error loading XOR key: {e}")
        refresh_xor_key()

def refresh_xor_key():
    global XOR_KEY, last_key_refresh_time
    XOR_KEY = ''.join(random.choices(string.ascii_letters + string.digits, k=16))
    last_key_refresh_time = datetime.datetime.now()
    with open(KEY_FILE_PATH, 'w') as key_file:
        key_file.write(f'{XOR_KEY},{last_key_refresh_time.isoformat()}')
    print(f'Refreshed XOR Key: {XOR_KEY}')

def get_current_xor_key():
    global XOR_KEY
    with xor_key_lock:
        if not XOR_KEY.strip():
            load_xor_key()
        now = datetime.datetime.now()
        if now - last_key_refresh_time >= KEY_REFRESH_INTERVAL:
            refresh_xor_key()
        return XOR_KEY

def xor_encrypt_decrypt(data, key):
    encrypted = ''.join(chr(ord(c) ^ ord(k)) for c, k in zip(data, cycle(key)))
    print(f"XOR Encrypted/Decrypted Data: {encrypted}")
    return encrypted

def encrypt_with_public_key(data, public_key_path='public_key.pem'):
    with open(public_key_path, 'r') as file:
        public_key = RSA.import_key(file.read())
    cipher = PKCS1_OAEP.new(public_key)
    encrypted_data = cipher.encrypt(data.encode())
    return base64.b64encode(encrypted_data).decode('utf-8')

def handle_refresh_command(client_socket):
    try:
        xor_key = get_current_xor_key()
        encrypted_key = encrypt_with_public_key(xor_key)
        # Asynchronous send, if applicable. Here it's assumed to be non-blocking as well.
        client_socket.sendall(encrypted_key.encode())
        print(f"Sent encrypted XOR key to client: {client_socket.getpeername()}")
        print(f"Encrypted XOR Key: {encrypted_key}")
    except Exception as e:
        print(f"Error handling REFRESH command: {e}")

def handle_client(client_socket):
    client_socket.setblocking(0)  # Ensures non-blocking mode
    print(f"Client connected: {client_socket.getpeername()}")

    try:
        while True:
            ready_to_read, _, _ = select.select([client_socket], [], [], 1)
            if ready_to_read:
                data = client_socket.recv(1024).decode()
                if data:
                    print(f"Received data: {data}")
                    if data.upper() == "REFRESH":
                        handle_refresh_command(client_socket)
                        continue  # Ensure to continue listening for more data or commands

            if not message_queue.empty():
                encrypted_data = message_queue.get()
                client_socket.sendall(encrypted_data.encode())
                print(f"Sent encrypted message to client: {client_socket.getpeername(), encrypted_data}")
    except Exception as e:
        print(f"Error handling client: {e}")
    finally:
        print("Closing client socket")
        client_socket.close()


@app.route('/send_data', methods=['POST'])
def send_data():
    json_data = request.json
    if not all(key in json_data for key in EXPECTED_KEYS):
        return jsonify({"error": "Invalid input data."}), 400
    # Encrypt the JSON data with XOR key before placing it into the queue
    encrypted_data = xor_encrypt_decrypt(json.dumps(json_data), get_current_xor_key())
    message_queue.put(encrypted_data)
    return jsonify({"message": "Data sent successfully"}), 200

def tcp_server():
    load_xor_key()
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server_socket:
        server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server_socket.bind((TCP_HOST, TCP_PORT))
        server_socket.listen()
        print("TCP Server listening with XOR Key:", get_current_xor_key())
        while True:
            client_socket, _ = server_socket.accept()
            threading.Thread(target=handle_client, args=(client_socket,)).start()


if __name__ == '__main__':
    threading.Thread(target=tcp_server, daemon=True).start()
    app.run(host='0.0.0.0', port=5000)
