from flask import Flask, send_from_directory, jsonify
import os
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # 启用跨域支持

# Add API endpoint to respond to /api/hello
@app.route("/api/hello")
def hello():
    return jsonify(message="Hello from Flask!")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
