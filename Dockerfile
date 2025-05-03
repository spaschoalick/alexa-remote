FROM python:3.11-slim

RUN apt-get update && \
    apt-get install -y curl jq git && \
    pip install flask

WORKDIR /app
COPY alexa-remote-control.sh .
RUN chmod +x alexa-remote-control.sh 
COPY app.py .
COPY alexa.jpeg .

ENV PORT=5000
EXPOSE 5000

CMD ["python", "app.py"]
