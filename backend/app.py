from flask import Flask, send_from_directory, jsonify
import os

app = Flask(__name__, static_folder="frontend/build", static_url_path="/static")

# Serve React's index.html at the root route
@app.route("/")
def serve_react():
    return send_from_directory(app.static_folder, "index.html")

# Serve other React static files (e.g., JS, CSS)
@app.route("/static/<path:path>")
def serve_static_files(path):
    return send_from_directory(os.path.join(app.static_folder, "static"), path)

# Add API endpoint to respond to /api/hello
@app.route("/api/hello")
def hello():
    return jsonify(message="Hello from Flask!")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
