🔔 ALERTS – API Flask com Integração Alexa
Uma aplicação web simples construída com Flask que permite enviar mensagens via API e gerar tokens de autenticação para integração com dispositivos Alexa.

📌 Funcionalidades
Interface web com botão "Enviar" para envio de mensagens.

API RESTful acessível via /api para envio de mensagens.

Geração de token de autenticação utilizando alexa-cookie-cli.

Bloco informativo no canto inferior direito com instruções de uso.

🚀 Instalação
Pré-requisitos
Python 3.7+

Flask

Docker (opcional, para execução em contêiner)

Passos
Clone o repositório:

bash
Copy
Edit
git clone https://github.com/seu-usuario/alerts-flask-alexa.git
cd alerts-flask-alexa
Instale as dependências:

bash
Copy
Edit
pip install -r requirements.txt
Execute a aplicação:

bash
Copy
Edit
python app.py
🧪 Uso da API
Para enviar uma mensagem via API, utilize o seguinte comando:

bash
Copy
Edit
curl -X POST http://localhost/api \
     -H "Content-Type: application/json" \
     -d '{"message": "Sua mensagem aqui"}'
Substitua "Sua mensagem aqui" pelo conteúdo desejado.

🔑 Gerar Token para Alexa
Para obter o token necessário para autenticação com a Alexa, execute os seguintes comandos:

bash
Copy
Edit
sudo curl -L -o /usr/local/bin/alexa-cookie-cli \
     https://github.com/adn77/alexa-cookie-cli/releases/download/v5.0.1/alexa-cookie-cli-linux-x64
sudo chmod +x /usr/local/bin/alexa-cookie-cli
alexa-cookie-cli -d -p amazon.com -b amazon.com -a en-EN
Passos:

O primeiro comando baixa o binário do alexa-cookie-cli para o diretório /usr/local/bin/.

O segundo comando concede permissões de execução ao binário.

O terceiro comando inicia o processo de autenticação.

Após executar o último comando, uma janela do navegador será aberta direcionando para a página de login da Amazon. Após o login bem-sucedido, o terminal exibirá um refresh_token, que pode ser utilizado para autenticar futuras requisições à API da Alexa.

🐳 Execução com Docker
Para executar a aplicação em um contêiner Docker:

Construa a imagem:

bash
Copy
Edit
docker build -t alerts-flask-alexa .
Execute o contêiner:
FreeCodeCamp
+5
Medium
+5
Cubos Academy
+5

bash
Copy
Edit
docker run -d -p 8080:8080 --name alerts-container alerts-flask-alexa
A aplicação estará acessível em http://localhost:8080.

🎨 Interface Web
A interface web possui:

Título "ALERTS" exibido no navegador.

Botão "Enviar" para envio de mensagens.

Bloco informativo no canto inferior direito com instruções de uso da API e geração de token, estilizado com a mesma cor azul do botão.

📄 Licença
Este projeto está licenciado sob a MIT License.
