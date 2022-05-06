from flask import Flask, request, json

app = Flask(__name__)

@app.route("/")
def hello_world():
    return "<p>Hello, World!</p>"

@app.route("/event", methods=["POST"])
def handle_event():
    app.logger.debug("[/event] Event received")

    req = request.get_json()
    print(json.dumps(req, indent=4))

    return json.jsonify({ 'success': True })
