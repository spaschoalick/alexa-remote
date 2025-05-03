🔔 ALEXA-REMOTE – API for Kubernetes
Uma API e uma aplicação web construída com Flask que permite enviar mensagens via API e um frontend.

📌 Funcionalidades
Interface web com botão "Enviar" para envio de mensagens.
API RESTful acessível via /api para envio de mensagens.

🚀 Instalação
Passos
Clone o repositório:
e crie uma imagem docker e envie ao seu registry
adapte todos os manifestos para seu ambiente

🔑 Gerar Token para Alexa
Passos
Instale as dependencias abaixo em seu equipamento para gerar o token
sudo curl -L -o /usr/local/bin/alexa-cookie-cli
sudo https://github.com/adn77/alexa-cookie-cli/releases/download/v5.0.1/alexa-cookie-cli-linux-x64
sudo chmod +x /usr/local/bin/alexa-cookie-cli
alexa-cookie-cli -d -p amazon.com -b amazon.com -a en-EN

Após executar o último comando, será exibida uma url a ser acessada, faça seu login e após ter sucesso será exibido no terminal o REFRESH_TOKEN, COPIE e coloque no manifesto de secret.yaml localizado nos manifestos

Adapte todos os manifestos para seu ambiente. As configurações a serem alteradas estão escritas em caixa alta.

🎨 Interface Web
A interface web possui:

Botão "Enviar" para envio de mensagens para teste.
e um bloco informativo no canto inferior direito com instruções da geração de token e instruções de uso da API.

🧪 Uso da API
Para enviar uma mensagem via API, utilize o seguinte comando:

curl -X POST http://SEUENDEREÇO/api \
     -H "Content-Type: application/json" \
     -d '{"message": "Sua mensagem aqui"}'
Substitua "Sua mensagem aqui" pelo conteúdo desejado.
