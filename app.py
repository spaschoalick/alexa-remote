import subprocess
from flask import Flask, request, render_template_string, send_from_directory, jsonify

app = Flask(__name__)

HTML_PAGE = '''
<!DOCTYPE html>
<html lang="pt-br">
<head>
    <meta charset="UTF-8">
    <title>ALERTS</title>
    <style>
        :root {
            --button-blue: #2196F3;
        }
        body {
            font-family: Arial, sans-serif;
            background-image: url('/background');
            background-size: cover;
            background-position: center;
            height: 100vh;
            margin: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            color: white;
        }
        .container {
            background-color: rgba(0, 0, 0, 0.6);
            padding: 30px;
            border-radius: 10px;
            text-align: center;
        }
        input[type="text"] {
            padding: 10px;
            width: 300px;
            border: none;
            border-radius: 5px;
            font-size: 16px;
        }
        button {
            padding: 10px 20px;
            margin-top: 10px;
            border: none;
            border-radius: 5px;
            background-color: var(--button-blue);
            color: white;
            font-size: 16px;
            cursor: pointer;
        }
        .api-instructions {
            position: fixed;
            bottom: 10px;
            right: 10px;
            background-color: rgba(0, 0, 0, 0.7);
            padding: 10px;
            border-radius: 8px;
            font-size: 12px;
            color: var(--button-blue);
            text-align: left;
            max-width: 300px;
            z-index: 1000;
        }
    </style>
</head>
<body>
    <div class="container">
        <h2>ALERTS</h2>
        <form method="post">
            <input type="text" name="message" placeholder="Digite a mensagem para a Alexa">
            <br>
            <button type="submit">Enviar mensagem</button>
        </form>
    </div>
    <div class="api-instructions">
        <strong>COLETAR TOKEN:</strong><br>
        instalar localmente<BR>
        <strong>INSTALAR:</strong> sudo curl -L -o /usr/local/bin/alexa-cookie-cli https://github.com/adn77/alexa-cookie-cli/releases/download/v5.0.1/alexa-cookie-cli-linux-x64<br>
        <strong>PERMISSÃO:</strong> sudo chmod +x /usr/local/bin/alexa-cookie-cli<br>
        <strong>EXECUTAR:</strong> alexa-cookie-cli -d -p amazon.com -b amazon.com -a en-EN <br><br>
        <strong>USO DA API:</strong><br>
        <strong>API:</strong> POST /api<br>
        <strong>JSON:</strong> {"cmd": "sua mensagem"}<br>
        <strong>USO:</strong><br>
        curl -X POST http://SUA-URL-AQUI:PORTA/api -H "Content-Type: application/json" -d '{"cmd":"Olá"}'
    </div>
</body>
</html>
'''

@app.route("/background")
def background():
    return send_from_directory("/app", "alexa.jpeg")

@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        cmd = request.form.get("message")
        if not cmd:
            return render_template_string(HTML_PAGE, error="Mensagem não fornecida")

        script_path = "/app/alexa-remote-control.sh"

        try:
            subprocess.check_output(
                [script_path, "-e", f"speak:{cmd}"],
                stderr=subprocess.STDOUT
            )
            return render_template_string(HTML_PAGE)
        except subprocess.CalledProcessError as e:
            return render_template_string(HTML_PAGE, error=e.output.decode("utf-8"))

    return render_template_string(HTML_PAGE)

@app.route("/api", methods=["POST"])
def api():
    data = request.get_json()
    if not data or "cmd" not in data:
        return jsonify({"error": "JSON inválido ou campo 'cmd' ausente"}), 400

    cmd = data["cmd"]
    script_path = "/app/alexa-remote-control.sh"

    try:
        subprocess.check_output(
            [script_path, "-e", f"speak:{cmd}"],
            stderr=subprocess.STDOUT
        )
        return jsonify({"status": "Mensagem enviada com sucesso"})
    except subprocess.CalledProcessError as e:
        return jsonify({"error": e.output.decode("utf-8")}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
